#!/bin/bash
# 複製 Chapter04 三個套件到 WSL 工作區並 colcon build（書本 repo 原檔不動）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter04
WS=~/k136_ws/ch04
PKGS="urdf_tutorial rrbot_description rosbot_description"
mkdir -p "$WS/src"
for p in $PKGS; do rm -rf "$WS/src/$p"; cp -r "$BOOK/$p" "$WS/src/"; done
# 套件需要的 urdf_launch（urdf_tutorial 的 display.launch.py 用到）若沒裝就補
dpkg -s ros-jazzy-urdf-launch >/dev/null 2>&1 || sudo apt-get install -y ros-jazzy-urdf-launch 2>&1 | tail -2
cd "$WS"
date
colcon build --symlink-install --event-handlers console_direct- 2>&1 | tail -30
date
source install/setup.bash
for p in $PKGS; do echo "$p -> $(ros2 pkg prefix $p)"; done
