#!/bin/bash
set -eo pipefail
B=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter13
ls -la $B
find $B -type f | head -50
for f in $(find $B -type f \( -name "*.cpp" -o -name "*.txt" -o -name "*.xml" -o -name "*.py" -o -name "*.hpp" -o -name "*.h" -o -name "*.yml" -o -name "*.yaml" \) ); do echo "===== $f"; cat "$f"; done
