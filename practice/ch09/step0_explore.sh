#!/bin/bash
# 步驟 0：看書本 Chapter09 結構、關鍵檔與 MoveIt 2 相關套件
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter09
ls "$BOOK"
echo "=== 檔案樹 ==="
find "$BOOK" -type f | grep -v -E '\.(stl|dae|STL|png|jpg)$' | sort
echo "=== MoveIt 套件 ==="
dpkg -l | grep -E 'ros-jazzy-(moveit|ros2-control|ros2-controllers|ros-gz|gz-ros2-control)' | awk '{print $2, $3}' | head -50
