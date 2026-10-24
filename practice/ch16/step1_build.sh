#!/bin/bash
# 步驟 1：複製 Chapter16 四個套件到 ~/k136_ws/ch16/src，補裝相依並建置
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
sudo ip link set lo multicast on

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter16
WS=~/k136_ws/ch16
mkdir -p "$WS/src"
for p in circle_msgs circle_display_plugin cmd_vel cmd_vel_plugin; do
  rm -rf "$WS/src/$p"
  cp -r "$BOOK/$p" "$WS/src/"
done
ls "$WS/src"

echo "=== 補裝相依（缺才裝）==="
NEED=""
for p in rviz-common rviz-rendering rqt-gui-cpp qt-gui-cpp ros-gz-sim ros-gz-bridge xacro robot-state-publisher; do
  dpkg -s "ros-jazzy-$p" >/dev/null 2>&1 || NEED="$NEED ros-jazzy-$p"
done
if [ -n "$NEED" ]; then
  sudo apt-get install -y $NEED
else
  echo "相依都已安裝"
fi

echo "=== colcon build ==="
cd "$WS"
colcon build --symlink-install 2>&1
echo "BUILD_EXIT=$?"
ls build/cmd_vel_plugin/*.so install/circle_display_plugin/lib/*.so install/cmd_vel/lib/cmd_vel/*.so
