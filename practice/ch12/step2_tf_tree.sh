#!/bin/bash
# 第 2 步：只跑 robot_state_publisher（不開 RViz），確認 TF 樹並產 PDF/PNG
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch12/install/setup.bash

HERE=$(pwd)
mkdir -p "$HERE/logs/tf"

# 書上的 display.launch.py 本來就只有 robot_state_publisher，不用改
setsid ros2 launch mobile_robot_model display.launch.py > "$HERE/logs/step2_rsp.log" 2>&1 &
RSP_PID=$!
trap 'kill -- -$RSP_PID 2>/dev/null || true' EXIT
sleep 8

echo "=== node list ==="
timeout 20 ros2 node list --no-daemon || true
echo "=== /tf_static 一則 ==="
timeout 20 ros2 topic echo --once --no-daemon /tf_static tf2_msgs/msg/TFMessage --qos-durability transient_local | grep -E "frame_id|child_frame_id" || true

echo "=== tf2_echo base_footprint -> base_laser ==="
timeout 6 ros2 run tf2_ros tf2_echo base_footprint base_laser 2>&1 | head -12 || true

echo "=== view_frames ==="
cd "$HERE/logs/tf"
timeout 40 ros2 run tf2_tools view_frames 2>&1 | tail -5 || true
PDF=$(ls -t frames_*.pdf 2>/dev/null | head -1)
if [ -n "$PDF" ]; then
  cp "$PDF" frames.pdf
  pdftoppm -png -r 110 -singlefile frames.pdf frames
  ls -la frames.pdf frames.png
  GV=$(ls -t frames_*.gv | head -1)
  echo "--- TF 邊（from gv）---"
  grep -- '->' "$GV" || true
else
  echo "view_frames 沒有產生 PDF"
fi
echo "STEP2_DONE"
