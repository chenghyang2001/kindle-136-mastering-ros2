#!/bin/bash
# 驗證：colcon list、ros2 pkg executables、ros2 run 各跑 5 秒（timeout）、兩節點同時跑時 node list
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
# 本演練改：區網上有其他機器也在用 domain 36，限定只探索本機
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

cd ~/k136_ws/ch02
source install/setup.bash

echo "===== colcon list"
colcon list

echo "===== ros2 pkg executables k136_hello_cpp / k136_hello_py"
ros2 pkg executables k136_hello_cpp
ros2 pkg executables k136_hello_py

echo "===== ros2 pkg prefix"
ros2 pkg prefix k136_hello_cpp
ros2 pkg prefix k136_hello_py

# timeout 到時回傳 124，屬於預期結束，不讓 set -e 中斷
echo "===== ros2 run k136_hello_cpp hello_timer_cpp（timeout 5）"
timeout 5 ros2 run k136_hello_cpp hello_timer_cpp || echo "[exit $?：timeout 結束屬預期]"

echo "===== ros2 run k136_hello_py hello_timer_py（timeout 5）"
timeout 5 ros2 run k136_hello_py hello_timer_py || echo "[exit $?：timeout 結束屬預期]"

echo "===== 兩節點同時背景執行，查 node list"
timeout 20 ros2 run k136_hello_cpp hello_timer_cpp > /tmp/k136_ch02_cpp.log 2>&1 &
CPP_PID=$!
timeout 20 ros2 run k136_hello_py hello_timer_py > /tmp/k136_ch02_py.log 2>&1 &
PY_PID=$!
# Python 節點啟動要 3~5 秒
sleep 8
NODES=$(timeout 15 ros2 node list --no-daemon || true)
if ! echo "$NODES" | grep -q hello_timer_py; then
  sleep 3
  NODES=$(timeout 15 ros2 node list --no-daemon || true)
fi
echo "$NODES"
timeout 15 ros2 node info /hello_timer_cpp --no-daemon || true

kill $CPP_PID $PY_PID 2>/dev/null || true
wait $CPP_PID $PY_PID 2>/dev/null || true
echo "--- 背景 C++ 節點 log（前 3 行）"; head -3 /tmp/k136_ch02_cpp.log
echo "--- 背景 Python 節點 log（前 3 行）"; head -3 /tmp/k136_ch02_py.log
rm -f /tmp/k136_ch02_cpp.log /tmp/k136_ch02_py.log
echo "VERIFY_DONE"
