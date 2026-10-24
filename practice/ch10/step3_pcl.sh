#!/bin/bash
# 第 3 步：合成點雲（平面＋雜點）→ 書上的 pcl_processing（PassThrough x/y/z + VoxelGrid 2cm）
# → cloud_checker 數點並用 RANSAC 分割平面
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
PRACTICE="$(pwd)"
OUT="$PRACTICE/logs"
mkdir -p "$OUT"
cd ~/k136_ws/ch10
source install/setup.bash

PGIDS=()
cleanup() {
  for g in "${PGIDS[@]}"; do kill -- -"$g" 2>/dev/null || true; done
  sleep 2
  for g in "${PGIDS[@]}"; do kill -9 -- -"$g" 2>/dev/null || true; done
}
trap cleanup EXIT

setsid install/pcl_processing/lib/pcl_processing/pcl_processing > "$OUT/step3_pcl_processing.log" 2>&1 &
PGIDS+=($!)
setsid python3 "$PRACTICE/fake_cloud_pub.py" > "$OUT/step3_fake_cloud.log" 2>&1 &
PGIDS+=($!)
sleep 8

echo "=== 節點清單 ==="
timeout 20 ros2 node list --no-daemon || true
echo "=== topic hz /filtered_pointcloud ==="
timeout 8 ros2 topic hz /filtered_pointcloud 2>&1 | head -4 || true
echo "=== cloud_checker（點數＋RANSAC 平面分割）==="
timeout 40 python3 "$PRACTICE/cloud_checker.py"
echo "=== fake_cloud_publisher log ==="
cat "$OUT/step3_fake_cloud.log" || true
echo "step3 完成"
