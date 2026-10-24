#!/bin/bash
# 第 2 章實作：ros2 pkg create 建 C++／Python 套件，放入最小 timer 節點，colcon build
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
# 本演練改：區網上有其他機器也在用 domain 36，限定只探索本機
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

PRACTICE_DIR="$(pwd)"
WS=~/k136_ws/ch02
mkdir -p "$WS/src"
cd "$WS/src"

# 重跑時先清掉舊套件，確保結果可重現
rm -rf k136_hello_cpp k136_hello_py

echo "===== ros2 pkg create（C++ / ament_cmake）"
ros2 pkg create --build-type ament_cmake --license Apache-2.0 \
  --dependencies rclcpp --node-name hello_timer_cpp k136_hello_cpp

echo "===== ros2 pkg create（Python / ament_python）"
ros2 pkg create --build-type ament_python --license Apache-2.0 \
  --dependencies rclpy --node-name hello_timer_py k136_hello_py

# 用練習資料夾裡寫好的節點覆蓋 pkg create 產生的範本
cp "$PRACTICE_DIR/nodes/hello_timer_cpp.cpp" k136_hello_cpp/src/hello_timer_cpp.cpp
cp "$PRACTICE_DIR/nodes/hello_timer_py.py"  k136_hello_py/k136_hello_py/hello_timer_py.py

echo "===== 產生的檔案結構"
find . -type f | sort

echo "===== CMakeLists.txt 中 pkg create 自動加的 executable"
grep -n -E "add_executable|ament_target_dependencies|install\(TARGETS" -A1 k136_hello_cpp/CMakeLists.txt
echo "===== setup.py 中的 entry_points"
grep -n -A3 "console_scripts" k136_hello_py/setup.py

echo "===== colcon build --symlink-install"
cd "$WS"
colcon build --symlink-install
echo "BUILD_OK"
