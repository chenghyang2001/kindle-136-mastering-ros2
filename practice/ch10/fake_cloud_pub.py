#!/usr/bin/env python3
"""發布合成 PointCloud2（水平平面＋隨機雜點），模擬書上 RealSense 的
/camera/camera/depth/color/points，供 pcl_processing 節點處理。"""
import sys

import numpy as np
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import PointCloud2
from sensor_msgs_py import point_cloud2
from std_msgs.msg import Header

TOPIC = "/camera/camera/depth/color/points"
PLANE_Z = 0.6          # 平面落在書上 z 濾波範圍 0.1~1.0 m 之內
GRID_STEP = 0.01       # 1 cm 間距，體素 2 cm 會把約 4 點合成 1 點
NOISE_POINTS = 2000


def build_cloud(rng: np.random.Generator) -> np.ndarray:
    """產生 x,y ∈ [-1,1] 的平面點與 [-1.5,1.5]x[-1.5,1.5]x[0,2] 的雜點。"""
    axis = np.arange(-1.0, 1.0 + 1e-9, GRID_STEP)
    xx, yy = np.meshgrid(axis, axis)
    plane = np.stack([xx.ravel(), yy.ravel(), np.full(xx.size, PLANE_Z)], axis=1)
    # 平面加 2 mm 高斯雜訊，讓 RANSAC 有意義
    plane[:, 2] += rng.normal(0.0, 0.002, plane.shape[0])
    noise = rng.uniform([-1.5, -1.5, 0.0], [1.5, 1.5, 2.0], size=(NOISE_POINTS, 3))
    return np.vstack([plane, noise]).astype(np.float32)


class FakeCloudPublisher(Node):
    def __init__(self):
        super().__init__("fake_cloud_publisher")
        self.pub = self.create_publisher(PointCloud2, TOPIC, 10)
        self.points = build_cloud(np.random.default_rng(42))
        self.timer = self.create_timer(0.5, self.publish_cloud)
        self.get_logger().info(f"合成點雲 {len(self.points)} 點，發布到 {TOPIC}（2 Hz）")

    def publish_cloud(self):
        header = Header(frame_id="camera_depth_optical_frame")
        header.stamp = self.get_clock().now().to_msg()
        self.pub.publish(point_cloud2.create_cloud_xyz32(header, self.points.tolist()))


def main():
    rclpy.init()
    node = FakeCloudPublisher()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    except Exception as exc:  # 記錄非預期錯誤後結束
        print(f"錯誤：{exc}", file=sys.stderr)
        sys.exit(1)
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    main()
