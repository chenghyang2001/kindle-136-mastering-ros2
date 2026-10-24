#!/bin/bash
# 診斷 4：改用 rmw_cyclonedds_cpp 測 service 探索
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
if ! dpkg -s ros-jazzy-rmw-cyclonedds-cpp >/dev/null 2>&1; then
  sudo apt-get install -y ros-jazzy-rmw-cyclonedds-cpp 2>&1 | tail -3
fi
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
source ~/k136_ws/ch03/install/setup.bash
ros2 run master_ros2_pkg simple_server > /tmp/k136_dbg.out 2>&1 &
SPID=$!
sleep 3
date +%T; timeout 25 ros2 service call /concat_strings master_ros2_interface/srv/ConcatStrings "{str1: 'K136 ', str2: 'Cyclone'}" || true; date +%T
kill $SPID; wait $SPID 2>/dev/null || true
cat /tmp/k136_dbg.out
