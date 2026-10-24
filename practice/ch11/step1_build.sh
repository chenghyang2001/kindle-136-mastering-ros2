#!/bin/bash
# 第 1 步：clone px4_msgs（release/1.15）＋複製 Chapter11/px4_ctrl，一起建置（書本 repo 原檔不動）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter11
WS=~/k136_ws/ch11
PX4_MSGS_BRANCH=release/1.15
mkdir -p "$WS/src"
cd "$WS/src"
if [ ! -d px4_msgs ]; then
  git clone --depth 1 -b "$PX4_MSGS_BRANCH" https://github.com/PX4/px4_msgs.git || { echo "錯誤：clone px4_msgs 失敗"; exit 1; }
fi
echo "px4_msgs 版本：$(git -C px4_msgs rev-parse --abbrev-ref HEAD) $(git -C px4_msgs rev-parse --short HEAD)"
ls px4_msgs/srv/
test -f px4_msgs/srv/VehicleCommand.srv || { echo "錯誤：此分支沒有 VehicleCommand.srv"; exit 1; }
echo "msg 數量：$(ls px4_msgs/msg | wc -l)"

rm -rf px4_ctrl
cp -r "$BOOK/px4_ctrl" .
echo "已複製 px4_ctrl"

cd "$WS"
date
colcon build --symlink-install --parallel-workers 4 --event-handlers console_cohesion+ 2>&1
date
echo "=== 建置產物 ==="
ls -la install/px4_ctrl/lib/px4_ctrl/
