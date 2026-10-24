#!/bin/bash
# 探索 Chapter05 三個套件內容與所需套件
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter05
ls "$BOOK"
for p in rrbot_gazebo diffbot_gazebo rosbot_description; do
  echo "=== $p ==="
  find "$BOOK/$p" -type f | grep -v -E '\.(stl|STL|dae|png|jpg)$' | head -40
done
echo "=== package.xml 依賴 ==="
grep -h -E "<(exec_|build_)?depend>" "$BOOK"/*/package.xml | sort -u
for f in "$BOOK"/diffbot_gazebo/launch/*.py "$BOOK"/rrbot_gazebo/launch/*.py; do
  echo "##### $f"; cat "$f"
done
echo "=== config ==="
for f in $(find "$BOOK"/diffbot_gazebo "$BOOK"/rrbot_gazebo -name "*.yaml"); do echo "##### $f"; cat "$f"; done
echo "=== 已裝 ==="
dpkg -l | grep -E "ros-jazzy-(ros-gz|gz-ros2-control|ros2-control|ros2-controllers|xacro|joint-state-broadcaster|diff-drive)" | awk '{print $2}'
which gz || true
