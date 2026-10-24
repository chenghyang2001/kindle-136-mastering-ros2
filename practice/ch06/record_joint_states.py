"""訂閱 /joint_states 指定秒數，存成 CSV 並印出各關節最大／最小值與振幅（驗證正弦運動）"""
import csv
import sys
import time

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import JointState


def main():
    duration = float(sys.argv[1]) if len(sys.argv) > 1 else 6.0
    out_path = sys.argv[2] if len(sys.argv) > 2 else "joint_states.csv"
    rclpy.init()
    node = Node("k136_joint_recorder")
    rows = []
    joint_names = []

    def on_msg(msg):
        if not joint_names:
            joint_names.extend(msg.name)
        # 書上的 launch 沒有橋接 /clock，header.stamp 全是 0，改記接收當下的 wall time
        stamp = time.time()
        by_name = dict(zip(msg.name, msg.position))
        rows.append([stamp] + [by_name.get(n, float("nan")) for n in joint_names])

    node.create_subscription(JointState, "/joint_states", on_msg, 50)
    end = time.time() + duration
    try:
        while time.time() < end:
            rclpy.spin_once(node, timeout_sec=0.1)
    finally:
        node.destroy_node()
        rclpy.shutdown()

    if not rows:
        print("錯誤：沒收到任何 /joint_states", file=sys.stderr)
        sys.exit(1)
    try:
        with open(out_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["stamp"] + joint_names)
            writer.writerows(rows)
    except OSError as e:
        print(f"錯誤：寫檔失敗 {out_path}: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"收到 {len(rows)} 筆，時間跨度 {rows[-1][0] - rows[0][0]:.2f} 秒（wall time），存到 {out_path}")
    for i, name in enumerate(joint_names, start=1):
        vals = [r[i] for r in rows]
        lo, hi = min(vals), max(vals)
        print(f"{name}: min={lo:.4f} max={hi:.4f} 峰對峰={hi - lo:.4f} 半振幅={(hi - lo) / 2:.4f}")


if __name__ == "__main__":
    main()
