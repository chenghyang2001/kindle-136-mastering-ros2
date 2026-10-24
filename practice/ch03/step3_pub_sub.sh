#!/bin/bash
# pub_sub.launch.py：std_msgs/String + 自訂 CustomMsg，QoS reliable + transient_local
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
timeout 15 ros2 launch master_ros2_pkg pub_sub.launch.py > /tmp/k136_pubsub.out 2>&1 &
LPID=$!
sleep 8
echo "===== node list"; timeout 20 ros2 node list --no-daemon || true
echo "===== topic info -v /custom_topic"; timeout 20 ros2 topic info -v /custom_topic --no-daemon || true
echo "===== topic echo --once /custom_topic（需同樣 transient_local QoS 才收得到舊訊息，這裡即時收）"
timeout 10 ros2 topic echo --once --no-daemon /custom_topic master_ros2_interface/msg/CustomMsg || true
wait $LPID || true
echo "===== launch 輸出（timeout 15 結束）"; cat /tmp/k136_pubsub.out
