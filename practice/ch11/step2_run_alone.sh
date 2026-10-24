#!/bin/bash
# 第 2 步：沒有飛控（也沒有假飛控）時，直接跑 px4_ctrl 10 秒，看它卡在哪、發了什麼
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch11/install/setup.bash

LOGDIR=./logs
EXE=~/k136_ws/ch11/install/px4_ctrl/lib/px4_ctrl/px4_ctrl
# 直接執行 exe（不經 ros2 run），PID 就是節點本身，結束時好殺乾淨
timeout 10 "$EXE" < /dev/null > "$LOGDIR/step2_px4_ctrl_alone.log" 2>&1 &
NODE_PID=$!
sleep 4
echo "=== node list ==="
timeout 15 ros2 node list --no-daemon || true
echo "=== topic list（/fmu 開頭）==="
timeout 15 ros2 topic list --no-daemon | grep fmu || true
echo "=== echo --once /fmu/in/offboard_control_mode（最多等 4 秒）==="
timeout 4 ros2 topic echo --once --no-daemon /fmu/in/offboard_control_mode || echo "（4 秒內沒有收到任何訊息）"
wait $NODE_PID || echo "px4_ctrl 被 timeout 10 結束（exit=$?）"
echo "=== px4_ctrl 自己的輸出 ==="
cat "$LOGDIR/step2_px4_ctrl_alone.log"
