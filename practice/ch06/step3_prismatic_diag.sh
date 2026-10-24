#!/bin/bash
# 診斷：link1_link2（滑動關節）為何卡在上限 0.3——切換前先錄、再用 position_control 送指令
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch06/install/setup.bash
LOGDIR="$PWD/logs"

timeout 110 ros2 launch two_joints_robot start_simu.launch.py > "$LOGDIR/step3_launch.log" 2>&1 &
LPID=$!
trap 'kill -INT $LPID 2>/dev/null || true; sleep 3; kill $LPID 2>/dev/null || true' EXIT
sleep 12
echo "=== A. 剛啟動（12 秒，position_control 尚未收到任何指令）==="
timeout 30 python3 ./record_joint_states.py 3 "$LOGDIR/diag_a_startup.csv"
sleep 15
echo "=== B. 30 秒後 ==="
timeout 30 python3 ./record_joint_states.py 3 "$LOGDIR/diag_b_idle.csv"
echo "=== C. position_control 送 [1.3, -0.2]，持續 6 秒 ==="
timeout 6 ros2 topic pub -r 10 /position_control/commands std_msgs/msg/Float64MultiArray "{data: [1.3, -0.2]}" > /dev/null 2>&1 || true
timeout 30 python3 ./record_joint_states.py 3 "$LOGDIR/diag_c_cmd.csv"
