#!/bin/bash
# 第 0 步：查看書本 Chapter11 內容（唯讀）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter11
find "$BOOK" -maxdepth 4 | head -100
echo "=== package.xml ==="
cat "$BOOK"/px4_ctrl/package.xml
echo "=== CMakeLists.txt ==="
cat "$BOOK"/px4_ctrl/CMakeLists.txt
echo "=== 原始碼 ==="
find "$BOOK"/px4_ctrl -name "*.cpp" -o -name "*.py" -o -name "*.launch*" | while read -r f; do echo "----- $f"; cat "$f"; done
echo "=== 其他文字檔 ==="
find "$BOOK" -maxdepth 2 -iname "*.md" -o -maxdepth 2 -iname "*.txt" | head
