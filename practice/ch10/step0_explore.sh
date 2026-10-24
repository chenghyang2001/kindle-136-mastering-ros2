#!/bin/bash
# 第 0 步：檢視書本 Chapter10 原始碼與已安裝的相依套件
set -eo pipefail
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter10
cd "$BOOK"
for f in $(find . -type f | sort); do
  echo "=================== $f"
  cat "$f"
done
echo "=================== 已安裝套件檢查"
dpkg -l | grep -E 'ros-jazzy-(cv-bridge|image-tools|pcl-conversions|pcl-ros|usb-cam|image-transport|rmw-cyclonedds)' | awk '{print $2, $3}' || true
dpkg -l | grep -E 'libpcl-dev|libopencv-dev' | awk '{print $2, $3}' || true
