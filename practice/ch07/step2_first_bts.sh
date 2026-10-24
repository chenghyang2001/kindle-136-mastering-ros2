#!/bin/bash
# 步驟 2：跑 sequence_tree 與 number_checker（timeout 包住），並抓 /generated_number 主題
set -o pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch07/install/setup.bash

echo "################ A. sequence_tree.launch.py（跑 5 秒）"
timeout 5 ros2 launch first_bts sequence_tree.launch.py 2>&1 | head -30 || true

echo "################ B. number_checker.launch.py（跑 15 秒）＋ 抓主題"
ros2 launch first_bts number_checker.launch.py > /tmp/ch07_nc.log 2>&1 &
NC_PID=$!
sleep 6
echo "--- topic list（--no-daemon）"
timeout 20 ros2 topic list --no-daemon || true
echo "--- topic echo /generated_number（取 5 筆）"
timeout 20 ros2 topic echo /generated_number std_msgs/msg/Int32 --no-daemon --once || echo "(echo 逾時)"
sleep 6
kill -INT $NC_PID 2>/dev/null || true
sleep 2; kill $NC_PID 2>/dev/null || true
wait $NC_PID 2>/dev/null || true
echo "--- number_checker 節點輸出（前 40 行）"
head -40 /tmp/ch07_nc.log
echo "--- 統計"
echo "Success 次數: $(grep -c 'Success!' /tmp/ch07_nc.log)"
echo "Failure 次數: $(grep -c 'Failure!' /tmp/ch07_nc.log)"
