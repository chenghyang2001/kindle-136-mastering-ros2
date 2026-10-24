"""假飛控（本演練新增）：代替 PX4 + uXRCE-DDS Agent，讓 px4_ctrl 不會卡在等服務。

- 提供 /fmu/vehicle_command 服務（px4_msgs/srv/VehicleCommand），一律回 ACCEPTED
- 以 10 Hz 發布 /fmu/out/vehicle_local_position（NED，位置直接跳到最新 setpoint，不模擬動力學）
- 訂閱 /fmu/in/offboard_control_mode、/fmu/in/trajectory_setpoint 只做計數與記錄
"""
import sys

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, DurabilityPolicy, HistoryPolicy

try:
    from px4_msgs.msg import (OffboardControlMode, TrajectorySetpoint,
                              VehicleCommandAck, VehicleLocalPosition, VehicleCommand)
    from px4_msgs.srv import VehicleCommand as VehicleCommandSrv
except ImportError as exc:
    print(f"錯誤：匯入 px4_msgs 失敗（是否 source 了 install/setup.bash？）：{exc}", file=sys.stderr)
    sys.exit(1)


class FakeFcu(Node):
    def __init__(self):
        super().__init__("fake_fcu")
        # px4_ctrl 的訂閱端要求 BEST_EFFORT + TRANSIENT_LOCAL，發布端 durability 必須不低於它才配得上
        pose_qos = QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT,
                              durability=DurabilityPolicy.TRANSIENT_LOCAL,
                              history=HistoryPolicy.KEEP_LAST, depth=10)
        self.pose_pub = self.create_publisher(VehicleLocalPosition, "/fmu/out/vehicle_local_position", pose_qos)
        self.create_service(VehicleCommandSrv, "/fmu/vehicle_command", self.on_command)
        self.create_subscription(OffboardControlMode, "/fmu/in/offboard_control_mode", self.on_mode, 10)
        self.create_subscription(TrajectorySetpoint, "/fmu/in/trajectory_setpoint", self.on_setpoint, 10)
        self.position = [0.0, 0.0, 0.0]
        self.armed = False
        self.mode_count = 0
        self.setpoint_count = 0
        self.create_timer(0.1, self.publish_pose)
        self.get_logger().info("假飛控已啟動：等待 px4_ctrl")

    def on_command(self, request, response):
        cmd = request.request
        if cmd.command == VehicleCommand.VEHICLE_CMD_COMPONENT_ARM_DISARM:
            self.armed = cmd.param1 == float(VehicleCommand.ARMING_ACTION_ARM)
            what = "ARM" if self.armed else "DISARM"
        elif cmd.command == VehicleCommand.VEHICLE_CMD_DO_SET_MODE:
            what = f"DO_SET_MODE(param1={cmd.param1:.0f}, param2={cmd.param2:.0f} → 6=OFFBOARD)"
        else:
            what = f"command={cmd.command}"
        self.get_logger().info(f"收到 VehicleCommand：{what}")
        response.reply.command = cmd.command
        response.reply.result = VehicleCommandAck.VEHICLE_CMD_RESULT_ACCEPTED
        response.reply.timestamp = cmd.timestamp
        return response

    def on_mode(self, msg):
        self.mode_count += 1
        if self.mode_count <= 3 or self.mode_count % 5 == 0:
            self.get_logger().info(f"OffboardControlMode #{self.mode_count} position={msg.position}")

    def on_setpoint(self, msg):
        self.setpoint_count += 1
        self.position = [float(v) for v in msg.position]
        if self.setpoint_count <= 2 or self.setpoint_count % 10 == 0:
            self.get_logger().info(f"TrajectorySetpoint #{self.setpoint_count} position={self.position}")

    def publish_pose(self):
        msg = VehicleLocalPosition()
        msg.timestamp = self.get_clock().now().nanoseconds // 1000
        msg.x, msg.y, msg.z = self.position
        self.pose_pub.publish(msg)


def main():
    rclpy.init()
    node = FakeFcu()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.get_logger().info(f"結束：OffboardControlMode {node.mode_count} 筆、TrajectorySetpoint {node.setpoint_count} 筆")
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == "__main__":
    main()
