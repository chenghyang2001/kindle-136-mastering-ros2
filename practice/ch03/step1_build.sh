#!/bin/bash
# 複製 Chapter03 兩個套件到 WSL 工作區並 colcon build（書本 repo 原檔不動）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter03
WS=~/k136_ws/ch03
mkdir -p "$WS/src"
rm -rf "$WS/src/master_ros2_interface" "$WS/src/master_ros2_pkg"
cp -r "$BOOK/master_ros2_interface" "$BOOK/master_ros2_pkg" "$WS/src/"
cd "$WS"
date
colcon build --symlink-install --event-handlers console_direct- 2>&1 | tail -40
date
source install/setup.bash
ls install/master_ros2_pkg/lib/master_ros2_pkg/
