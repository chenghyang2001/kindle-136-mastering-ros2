#!/bin/bash
# 診斷 2：清掉舊 Fast DDS SHM 檔後重測；再用 FASTDDS_BUILTIN_TRANSPORTS=UDPv4 對照
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
source ~/k136_ws/ch03/install/setup.bash
rm -f /dev/shm/fastrtps_* /dev/shm/sem.fastrtps_* || true
try() {
  echo "######## 模式：$1"
  ros2 run master_ros2_pkg simple_server > /tmp/k136_dbg.out 2>&1 &
  SPID=$!
  sleep 6
  timeout 15 ros2 service list --no-daemon | grep -E "concat|string_concat" || echo "(service list 沒看到)"
  date +%T; timeout 25 ros2 service call /concat_strings master_ros2_interface/srv/ConcatStrings "{str1: 'K136 ', str2: 'Chapter03'}" || true; date +%T
  kill $SPID; wait $SPID 2>/dev/null || true
  cat /tmp/k136_dbg.out
}
try "預設（SHM+UDP）"
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
try "UDPv4 only"
