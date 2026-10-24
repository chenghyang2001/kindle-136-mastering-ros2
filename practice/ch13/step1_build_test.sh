#!/bin/bash
# 第 1 步：複製 Chapter13 兩個套件到 ~/k136_ws/ch13/src，建置並執行 colcon test
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter13
WS=~/k136_ws/ch13
mkdir -p "$WS/src"
for p in first_gtest to_lowercase; do
  rm -rf "$WS/src/$p"
  cp -r "$BOOK/$p" "$WS/src/"
done

dpkg -s ros-jazzy-ament-cmake-gtest >/dev/null 2>&1 || sudo apt-get install -y ros-jazzy-ament-cmake-gtest

cd "$WS"
colcon build --symlink-install --event-handlers console_direct+ 2>&1
echo "BUILD_DONE"

# colcon test 本身遇測試失敗也回 0；test-result 有失敗時回非 0，所以用 || true 讓腳本走完
timeout 110 colcon test --event-handlers console_direct+ 2>&1 || echo "colcon test 回傳非 0"
echo "=== colcon test-result --verbose ==="
colcon test-result --verbose 2>&1 || echo "TEST_RESULT_HAS_FAILURES"
echo "TEST_DONE"
