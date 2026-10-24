#!/usr/bin/env python3
"""備案：不依賴 langchain 的最小假 agent（純 Python + rclpy）。

和書上 ros2_ai_agent_turtlesim.py 用「同一組工具、同樣的實作」：
  move_forward(distance) → 發一次 /turtle1/cmd_vel，linear.x = distance * 0.1
  rotate(angle)          → angular.z = radians(angle)，1 秒後發零速度
  get_pose()             → 回報 /turtle1/pose
差別只在「決定要呼叫哪個工具」：書上交給 GPT-4o-mini，這裡用固定關鍵字規則。
訂閱 /prompt（std_msgs/String），和書上 agent 一樣。
"""
import math
import re
import sys

import rclpy
from geometry_msgs.msg import Twist
from rclpy.node import Node
from std_msgs.msg import String
from turtlesim.msg import Pose

_NUM = re.compile(r"-?\d+(?:\.\d+)?")


def _first_number(text, default):
    found = _NUM.search(text)
    return float(found.group()) if found else default


def plan_tool_call(text):
    """固定規則：指令 → (工具名稱, 參數)；認不得回 None。"""
    lower = text.lower()
    if any(k in lower for k in ("forward", "前進", "往前", "向前")):
        return "move_forward", {"distance": _first_number(text, 2.0)}
    if any(k in lower for k in ("rotate", "turn", "轉")):
        return "rotate", {"angle": _first_number(text, 90.0)}
    if any(k in lower for k in ("pose", "position", "where", "位置", "在哪")):
        return "get_pose", {}
    return None


class MinimalTurtleAgent(Node):
    def __init__(self):
        super().__init__("ros2_ai_agent")
        self.turtle_pose = Pose()
        self.cmd_vel_pub = self.create_publisher(Twist, "/turtle1/cmd_vel", 10)
        self.create_subscription(Pose, "/turtle1/pose", self._on_pose, 10)
        self.create_subscription(String, "prompt", self._on_prompt, 10)
        self.tools = {"move_forward": self.move_forward, "rotate": self.rotate,
                      "get_pose": self.get_pose}
        self.get_logger().info("Minimal (no-langchain) agent started")

    # ---- 工具：照抄書上實作 ----
    def move_forward(self, distance):
        msg = Twist()
        msg.linear.x = float(distance) * 0.1
        self.cmd_vel_pub.publish(msg)
        return f"Moved forward {distance} units"

    def rotate(self, angle):
        msg = Twist()
        msg.angular.z = math.radians(float(angle))
        self.cmd_vel_pub.publish(msg)
        self._stop_timer = self.create_timer(1.0, self._stop_once)
        return f"Rotated {angle} degrees"

    def _stop_once(self):
        self.cmd_vel_pub.publish(Twist())
        self._stop_timer.cancel()

    def get_pose(self):
        p = self.turtle_pose
        return f"x: {p.x:.2f}, y: {p.y:.2f}, theta: {math.degrees(p.theta):.2f} degrees"

    # ---- 回呼 ----
    def _on_pose(self, msg):
        self.turtle_pose = msg

    def _on_prompt(self, msg):
        try:
            plan = plan_tool_call(msg.data)
            if plan is None:
                self.get_logger().info(f"Result: 不認得的指令：{msg.data}")
                return
            name, args = plan
            self.get_logger().info(f"Invoking: `{name}` with `{args}`")
            result = self.tools[name](**args)
            self.get_logger().info(f"Result: {result}")
        except (ValueError, TypeError) as e:
            self.get_logger().error(f"Error processing prompt: {e}")


def main(args=None):
    if "--selftest" in sys.argv:
        assert plan_tool_call("Move the turtle forward 2 units") == ("move_forward", {"distance": 2.0})
        assert plan_tool_call("往前走 5 單位")[1] == {"distance": 5.0}
        assert plan_tool_call("hello") is None
        print("MINIMAL_SELFTEST_OK")
        return
    rclpy.init(args=args)
    node = MinimalTurtleAgent()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    main()
