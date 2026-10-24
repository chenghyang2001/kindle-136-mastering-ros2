#!/bin/bash
# 探索 Chapter04 三個套件內容與所需工具
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter04
ls "$BOOK"
for p in urdf_tutorial rrbot_description rosbot_description; do
  echo "=== $p ==="
  find "$BOOK/$p" -type f | grep -v -E '\.(stl|STL|dae|png|jpg)$' | head -40
done
echo "=== package.xml 依賴 ==="
grep -h -E "<(exec_|build_)?depend>" "$BOOK"/*/package.xml | sort -u
echo "=== 工具 ==="
which check_urdf urdf_to_graphviz xacro dot pdftoppm || true
dpkg -l | grep -E "ros-jazzy-(xacro|urdfdom|liburdfdom|robot-state|joint-state|gz-ros2-control|ros2-control)" | awk '{print $2}'
