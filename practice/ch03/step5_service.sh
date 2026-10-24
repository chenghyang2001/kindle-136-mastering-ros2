#!/bin/bash
# server_client.launch.py + 手動 ros2 service call
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
echo "===== A. launch server_client（client 送一次就結束）"
timeout 15 ros2 launch master_ros2_pkg server_client.launch.py 2>&1 || true
echo "===== B. 單獨啟 server，手動 service call"
ros2 run master_ros2_pkg simple_server > /tmp/k136_srv.out 2>&1 &
SPID=$!
sleep 5
timeout 20 ros2 service list -t --no-daemon | grep concat || true
timeout 20 ros2 service call /concat_strings master_ros2_interface/srv/ConcatStrings "{str1: 'K136 ', str2: 'Chapter03'}" || true
kill $SPID 2>/dev/null || true; wait $SPID 2>/dev/null || true
echo "===== server 端輸出"; cat /tmp/k136_srv.out
