#!/usr/bin/env python3
"""訂閱原始與 pcl_processing 濾波後的點雲，印出點數，
並對濾波結果做 numpy RANSAC 平面分割（書上節點只做濾波＋降採樣，分割由此補上）。"""
import sys

import numpy as np
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import PointCloud2
from sensor_msgs_py import point_cloud2

RAW_TOPIC = "/camera/camera/depth/color/points"
FILTERED_TOPIC = "/filtered_pointcloud"
SAMPLES_NEEDED = 3


def to_xyz(msg: PointCloud2) -> np.ndarray:
    arr = point_cloud2.read_points(msg, field_names=("x", "y", "z"), skip_nans=True)
    return np.stack([arr["x"], arr["y"], arr["z"]], axis=1).astype(np.float64)


def ransac_plane(pts: np.ndarray, threshold=0.01, iterations=200, seed=0):
    """回傳 (inlier 遮罩, 平面係數 a,b,c,d)。點數不足時回傳全 False。"""
    if len(pts) < 3:
        return np.zeros(len(pts), dtype=bool), None
    rng = np.random.default_rng(seed)
    best_mask, best_model = np.zeros(len(pts), dtype=bool), None
    for _ in range(iterations):
        p1, p2, p3 = pts[rng.choice(len(pts), 3, replace=False)]
        normal = np.cross(p2 - p1, p3 - p1)
        norm = np.linalg.norm(normal)
        if norm < 1e-9:  # 三點共線，略過
            continue
        normal /= norm
        d = -normal.dot(p1)
        mask = np.abs(pts @ normal + d) < threshold
        if mask.sum() > best_mask.sum():
            best_mask, best_model = mask, (*normal, d)
    return best_mask, best_model


class CloudChecker(Node):
    def __init__(self):
        super().__init__("cloud_checker")
        self.raw_count = None
        self.reports = 0
        self.create_subscription(PointCloud2, RAW_TOPIC, self.on_raw, 10)
        self.create_subscription(PointCloud2, FILTERED_TOPIC, self.on_filtered, 10)

    def on_raw(self, msg):
        self.raw_count = msg.width * msg.height

    def on_filtered(self, msg):
        pts = to_xyz(msg)
        mask, model = ransac_plane(pts)
        model_txt = "無" if model is None else "a=%.3f b=%.3f c=%.3f d=%.3f" % model
        print(f"[{self.reports + 1}] 原始點數={self.raw_count} 濾波+降採樣後={len(pts)} "
              f"平面 inlier={int(mask.sum())} 雜點(outlier)={int((~mask).sum())} 平面={model_txt}",
              flush=True)
        if len(pts):
            print(f"    範圍 x[{pts[:,0].min():.2f},{pts[:,0].max():.2f}] "
                  f"y[{pts[:,1].min():.2f},{pts[:,1].max():.2f}] "
                  f"z[{pts[:,2].min():.2f},{pts[:,2].max():.2f}]", flush=True)
        self.reports += 1
        if self.reports >= SAMPLES_NEEDED:
            raise SystemExit(0)


def main():
    rclpy.init()
    node = CloudChecker()
    code = 0
    try:
        rclpy.spin(node)
    except SystemExit:
        pass
    except Exception as exc:
        print(f"錯誤：{exc}", file=sys.stderr)
        code = 1
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
    sys.exit(code)


if __name__ == "__main__":
    main()
