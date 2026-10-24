#!/bin/bash
# 第 0 步：查看書本 Chapter12 內容（唯讀）
set -eo pipefail
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter12
find "$BOOK" -maxdepth 3 -not -path "*/.git*" | head -150
for p in mobile_robot_model ldlidar_sl_ros2 rf2o_laser_odometry; do echo "===== $p ====="; cat "$BOOK/$p/package.xml" | head -40; find "$BOOK/$p" -name "*.launch*" -o -name "*.xacro" -o -name "*.urdf" | head; done
echo "===== launch 檔內容 ====="
find "$BOOK/mobile_robot_model" "$BOOK/rf2o_laser_odometry" -name "*.launch*" | while read -r f; do echo "----- $f"; cat "$f"; done
