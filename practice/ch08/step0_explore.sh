#!/bin/bash
# 步驟 0：看書本 Chapter08 結構與關鍵檔、確認 nav2 / gz 套件
set -eo pipefail
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter08
cd "$BOOK"
echo "=== 目錄結構"
find . -maxdepth 3 -not -path '*/meshes/*' | sort | head -150
echo "=== launch / config"
for f in $(find . -name "*.launch.py" -o -name "package.xml" -o -name "CMakeLists.txt" -o -name "setup.py" | grep -v meshes | sort); do
  echo "=================== $f"; cat "$f"
done
echo "=== 已安裝套件"
dpkg -l | grep -E "ros-jazzy-(navigation2|nav2-bringup|nav2-minimal|ros-gz|gz-ros2-control|ros2-control|diff-drive|slam)" | awk '{print $2}' || true
