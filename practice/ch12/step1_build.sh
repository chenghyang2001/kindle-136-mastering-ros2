#!/bin/bash
# 第 1 步：複製 Chapter12 三個套件到 ~/k136_ws/ch12/src 並建置
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter12
WS=~/k136_ws/ch12
mkdir -p "$WS/src"
for p in mobile_robot_model ldlidar_sl_ros2 rf2o_laser_odometry; do
  rm -rf "$WS/src/$p"
  cp -r "$BOOK/$p" "$WS/src/"
done

# 驗證會用到的工具（tf2_tools 產 TF 樹 PDF、poppler 轉 PNG）
need=""
dpkg -s ros-jazzy-tf2-tools >/dev/null 2>&1 || need="$need ros-jazzy-tf2-tools"
dpkg -s poppler-utils >/dev/null 2>&1 || need="$need poppler-utils"
dpkg -s graphviz >/dev/null 2>&1 || need="$need graphviz"
if [ -n "$need" ]; then
  echo "安裝缺少的套件：$need"
  sudo apt-get install -y $need
fi

cd "$WS"
colcon build --symlink-install --event-handlers console_direct+ 2>&1
echo "=== 建置結果 ==="
ls install
echo "BUILD_DONE"
