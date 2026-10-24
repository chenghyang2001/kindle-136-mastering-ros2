#!/bin/bash
# 診斷：service 探索為何慢（只量測，不改程式）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
source ~/k136_ws/ch03/install/setup.bash
echo "RMW=${RMW_IMPLEMENTATION:-預設(rmw_fastrtps_cpp)}"
ros2 run master_ros2_pkg simple_server > /tmp/k136_dbg.out 2>&1 &
SPID=$!
sleep 8
for i in 1 2; do echo "--- service list 第 $i 次"; timeout 20 ros2 service list --no-daemon || true; done
echo "--- service call（timeout 45）"
date +%T; timeout 45 ros2 service call /concat_strings master_ros2_interface/srv/ConcatStrings "{str1: 'K136 ', str2: 'Chapter03'}" || true; date +%T
kill $SPID; wait $SPID 2>/dev/null || true
cat /tmp/k136_dbg.out
