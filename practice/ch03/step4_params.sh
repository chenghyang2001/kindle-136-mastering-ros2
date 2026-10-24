#!/bin/bash
# pub_params_sub.launch.py：執行期間用 ros2 param list／get／set 改參數
# 注意：launch 用 name='publisher_node' 覆寫了程式裡的 publisher_node_params 節點名
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
timeout 15 ros2 launch master_ros2_pkg pub_params_sub.launch.py > /tmp/k136_params.out 2>&1 &
LPID=$!
sleep 5
echo "===== param list /publisher_node"; timeout 8 ros2 param list /publisher_node --no-daemon || { sleep 1; timeout 8 ros2 param list /publisher_node --no-daemon; } || true
echo "===== param get（設定前）"; timeout 8 ros2 param get /publisher_node custom_string --no-daemon || true
echo "===== param set custom_string / custom_number"
timeout 8 ros2 param set /publisher_node custom_string "Set from CLI" --no-daemon || true
timeout 8 ros2 param set /publisher_node custom_number 99 --no-daemon || true
echo "===== param list（節點已被探索到後再查）"; timeout 8 ros2 param list /publisher_node --no-daemon || true
wait $LPID || true
echo "===== launch 輸出（看 CLI 設定的值是否出現在 Publishing custom message）"; cat /tmp/k136_params.out
