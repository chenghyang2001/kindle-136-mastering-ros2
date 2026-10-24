#!/bin/bash
# 用 ros2 interface show 看自訂 msg／srv／action
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
ros2 interface package master_ros2_interface
for i in master_ros2_interface/msg/CustomMsg master_ros2_interface/srv/ConcatStrings master_ros2_interface/action/MyCustomAction; do
  echo "===== ros2 interface show $i"; ros2 interface show "$i"
done
