#!/usr/bin/env python3
"""假 LiDAR 節點：在 6m x 4m 的矩形房間裡，模擬機器人沿 +x 慢慢平移，發布 /scan。

本演練沒有 LDLiDAR LD14P 硬體，用它取代 ldlidar_sl_ros2_node，餵給 rf2o_laser_odometry。
真值位置每秒印一次到 stdout，方便跟 /odom 比對。
"""
import math
import os
import random
import sys

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import LaserScan

# 房間四面牆（世界座標，公尺）
X_MIN, X_MAX, Y_MIN, Y_MAX = -3.0, 3.0, -2.0, 2.0
START_X = -1.0      # 起點
SPEED = 0.05        # m/s，慢慢平移
HOLD_SEC = 5.0      # 先靜止幾秒，讓 rf2o 初始化
MOVE_SEC = 40.0     # 平移時間 → 總共移動 2.0 m
# 掃描視角（度），預設 360 對應 LD14P；可用環境變數 FAKE_FOV_DEG 改成 270 等做對照
FOV_DEG = float(os.environ.get('FAKE_FOV_DEG', '360'))
NUM_BEAMS = int(FOV_DEG)
RANGE_MAX = 12.0
NOISE_STD = 0.003


def ray_to_walls(px, py, angle):
    """從 (px, py) 沿 angle 射線打到矩形牆面的距離。"""
    c, s = math.cos(angle), math.sin(angle)
    hits = []
    if abs(c) > 1e-9:
        hits.append(((X_MAX if c > 0 else X_MIN) - px) / c)
    if abs(s) > 1e-9:
        hits.append(((Y_MAX if s > 0 else Y_MIN) - py) / s)
    positive = [d for d in hits if d > 0]
    return min(positive) if positive else RANGE_MAX


class FakeScan(Node):
    def __init__(self):
        super().__init__('fake_scan')
        self.pub = self.create_publisher(LaserScan, 'scan', 10)
        self.t0 = self.get_clock().now()
        self.last_print = -1
        self.timer = self.create_timer(0.1, self.tick)  # 10 Hz，接近 LD14P 的轉速

    def true_x(self, t):
        moving = min(max(t - HOLD_SEC, 0.0), MOVE_SEC)
        return START_X + SPEED * moving

    def tick(self):
        now = self.get_clock().now()
        t = (now - self.t0).nanoseconds * 1e-9
        px, py = self.true_x(t), 0.0

        msg = LaserScan()
        msg.header.stamp = now.to_msg()
        msg.header.frame_id = 'base_laser'  # 與書上 ld20.launch.py 的 frame_id 一致
        fov = math.radians(FOV_DEG)
        msg.angle_min = -fov / 2
        msg.angle_increment = fov / NUM_BEAMS
        msg.angle_max = msg.angle_min + msg.angle_increment * (NUM_BEAMS - 1)
        msg.scan_time = 0.1
        msg.time_increment = msg.scan_time / NUM_BEAMS
        msg.range_min = 0.02
        msg.range_max = RANGE_MAX
        msg.ranges = [
            ray_to_walls(px, py, msg.angle_min + i * msg.angle_increment)
            + random.gauss(0.0, NOISE_STD)
            for i in range(NUM_BEAMS)
        ]
        self.pub.publish(msg)

        sec = int(t)
        if sec != self.last_print:
            self.last_print = sec
            # 輸出相對起點的位移，對應 rf2o 的 odom 原點
            self.get_logger().info(f'truth t={t:5.1f}s dx={px - START_X:.3f} m')


def main():
    rclpy.init()
    node = FakeScan()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    except Exception as e:  # noqa: BLE001 — 演練用，印出錯誤即可
        print(f'錯誤：{e}', file=sys.stderr)
        sys.exit(1)
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
