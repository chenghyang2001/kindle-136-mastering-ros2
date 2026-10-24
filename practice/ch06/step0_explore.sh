#!/bin/bash
# 探索 Chapter06 套件內容
set -eo pipefail
B=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter06
ls $B
for p in two_joints_robot sine_ctrl; do echo "=== $p ==="; find $B/$p -type f | grep -v -E "\.(stl|STL|dae|png)$"; done
for f in $(find $B/two_joints_robot $B/sine_ctrl -type f \( -name "*.py" -o -name "*.xml" -o -name "*.yaml" -o -name "*.xacro" -o -name "*.urdf" -o -name "CMakeLists.txt" -o -name "*.cpp" -o -name "*.hpp" -o -name "*.h" \)); do echo "##### $f"; cat $f; done
