#!/bin/bash
# 第 1 步：複製 Chapter10 三個套件到 ~/k136_ws/ch10/src 並建置（書本 repo 原檔不動）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter10
WS=~/k136_ws/ch10
mkdir -p "$WS/src"
for pkg in my_opencv_package pcl_processing usb_cam_launcher; do
  rm -rf "$WS/src/$pkg"
  cp -r "$BOOK/$pkg" "$WS/src/"
  echo "已複製 $pkg"
done
cd "$WS"
colcon build --symlink-install --event-handlers console_direct+ 2>&1
echo "=== 建置產物 ==="
ls install/my_opencv_package/lib/my_opencv_package/ install/pcl_processing/lib/pcl_processing/ install/usb_cam_launcher/share/usb_cam_launcher/launch/
