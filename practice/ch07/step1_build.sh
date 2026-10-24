#!/bin/bash
# 步驟 1：把書本 Chapter07 兩個套件複製到 ~/k136_ws/ch07/src 並建置（書本原檔不動）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter07
WS=~/k136_ws/ch07
mkdir -p "$WS/src"
for pkg in first_bts bt_action_server; do
  rm -rf "$WS/src/$pkg"
  cp -r "$BOOK/$pkg" "$WS/src/"
done
cd "$WS"
colcon build --symlink-install --event-handlers console_direct- 2>&1
echo "=== 建置結果 ==="
ls install/first_bts/lib/first_bts install/bt_action_server/lib/bt_action_server
