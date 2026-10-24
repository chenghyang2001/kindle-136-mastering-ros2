#!/bin/bash
# 第 1 章步驟 1：環境確認 + C++ talker / Python listener 跨語言互通 + 內省指令
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
# 本演練改：區網上有其他機器也在用 domain 36，限定只探索本機
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
mkdir -p ~/k136_ws/ch01/src logs

echo "=== printenv ROS_DISTRO ==="
printenv ROS_DISTRO
echo "=== RMW 預設值（未設定時為空，Jazzy 預設 Fast DDS）==="
echo "RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-<未設定>}"
# 本演練改：ros2 doctor 在 WSL 會卡住，改用 rmw 套件清單
ros2 pkg list | grep -E '^rmw_(fastrtps|cyclonedds|connextdds|zenoh)' || true
echo "=== ros2 pkg list | wc -l ==="
ros2 pkg list | wc -l

echo "=== 背景啟動 talker (C++) 與 listener (Python)，timeout 15 ==="
timeout 15 ros2 run demo_nodes_cpp talker > logs/talker.log 2>&1 &
TALKER_PID=$!
timeout 15 ros2 run demo_nodes_py listener > logs/listener.log 2>&1 &
LISTENER_PID=$!
sleep 4

echo "=== ros2 node list ==="
ros2 node list --no-daemon
echo "=== ros2 topic list -t ==="
ros2 topic list -t --no-daemon
echo "=== ros2 topic info /chatter -v（含 QoS）==="
ros2 topic info /chatter -v --no-daemon
echo "=== ros2 interface show std_msgs/msg/String ==="
ros2 interface show std_msgs/msg/String

wait $TALKER_PID || true
wait $LISTENER_PID || true
echo "=== talker 輸出（前 5 行）==="
head -5 logs/talker.log
echo "=== listener 輸出（前 5 行）==="
head -5 logs/listener.log
echo "listener 收到訊息數：$(grep -c 'I heard' logs/listener.log || true)"
