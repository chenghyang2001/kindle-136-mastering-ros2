#!/bin/bash
# 第 2 步：用 image_tools cam2image（burger 模式）當假相機，餵給書上的 image_processing 節點
# 書上節點訂閱 /image_raw；cam2image 預設發布 /image，所以 remap image:=/image_raw
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
OUT="$(pwd)/logs"
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

setsid /opt/ros/jazzy/lib/image_tools/cam2image --ros-args -p burger_mode:=true -p frequency:=10.0 -r image:=/image_raw > "$OUT/step2_cam2image.log" 2>&1 &
PGIDS+=($!)
setsid install/my_opencv_package/lib/my_opencv_package/image_processing > "$OUT/step2_image_processing.log" 2>&1 &
PGIDS+=($!)
sleep 8

echo "=== 節點清單 ==="
timeout 20 ros2 node list --no-daemon || true
echo "=== 影像相關 topic ==="
timeout 20 ros2 topic list --no-daemon | grep image || true

for t in /image_raw /gray/image_raw /blur/image_raw /thresholded/image_raw /contours/image_raw /corner/image_raw /keypoints/image_raw; do
  echo "=== topic hz $t ==="
  timeout 8 ros2 topic hz "$t" 2>&1 | head -4 || true
done

echo "=== /gray/image_raw 單張影像中繼資料 ==="
timeout 20 ros2 topic echo --once --no-daemon /gray/image_raw --field encoding || true
timeout 20 ros2 topic echo --once --no-daemon /gray/image_raw --field width || true
timeout 20 ros2 topic echo --once --no-daemon /gray/image_raw --field height || true
echo "=== /prespective/image_raw（書上未實作透視轉換，發布空影像）==="
timeout 20 ros2 topic echo --once --no-daemon /prespective/image_raw --field width || true
echo "=== image_processing 節點 log（尾段）==="
tail -5 "$OUT/step2_image_processing.log" || true
echo "step2 完成"
