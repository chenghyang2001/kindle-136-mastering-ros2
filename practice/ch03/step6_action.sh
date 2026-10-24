#!/bin/bash
# action_server_client.launch.py + 手動 ros2 action send_goal --feedback
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
# 本演練改：區網上有其他機器也在用 domain 36，限定只探索本機
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
# 本演練改：此 WSL 上預設的 Fast DDS 跨行程探索極慢、service／action 幾乎連不上（見 logs/debug_*.log），改用 Cyclone DDS
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
# 本演練改：WSL 的 lo 預設沒開 MULTICAST，LOCALHOST 探索會極慢或找不到（見 logs/debug_lo.log）；WSL 重啟後會失效所以每次都設
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch03/install/setup.bash
echo "===== A. launch action_server_client（goal_value=10，每 0.5s 一次 feedback）"
timeout 15 ros2 launch master_ros2_pkg action_server_client.launch.py 2>&1 || true
echo "===== B. 單獨啟 action_server，手動 send_goal --feedback"
ros2 run master_ros2_pkg action_server > /tmp/k136_act.out 2>&1 &
APID=$!
sleep 5
timeout 20 ros2 action list -t || true
timeout 30 ros2 action send_goal --feedback /my_custom_action master_ros2_interface/action/MyCustomAction "{goal_value: 4}" || true
kill $APID 2>/dev/null || true; wait $APID 2>/dev/null || true
echo "===== server 端輸出"; cat /tmp/k136_act.out
