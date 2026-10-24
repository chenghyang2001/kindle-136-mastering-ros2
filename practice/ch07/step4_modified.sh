#!/bin/bash
# 步驟 4：修改版 tree XML 重跑並與原版比較
#   (a) number_checker：原版 vs Sequence 版，各跑 30 秒，統計 /generated_number 發布次數
#   (b) bt_action：Fallback 版（第一個 goal 必失敗 → 改走第二個 goal）
set -o pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
WS=~/k136_ws/ch07
# 修改版樹檔放進工作區複製檔（書本 repo 不動），重建讓它被安裝
cp trees/number_checker_seq.xml "$WS/src/first_bts/trees/"
cp trees/bt_action_fallback.xml "$WS/src/bt_action_server/trees/"
(cd "$WS" && colcon build --symlink-install > /tmp/ch07_rebuild.log 2>&1) || { echo "重建失敗"; tail -20 /tmp/ch07_rebuild.log; exit 1; }
source "$WS/install/setup.bash"
SHARE=$WS/install/first_bts/share/first_bts/trees

run_nc() {  # $1=樹檔 $2=標籤
  ros2 run first_bts number_checker --ros-args -p tree_xml_file:="$SHARE/$1" > /tmp/ch07_nc_$2.log 2>&1 &
  local pid=$!
  sleep 3
  timeout 30 ros2 topic echo /generated_number std_msgs/msg/Int32 --no-daemon > /tmp/ch07_echo_$2.log 2>&1
  kill -INT $pid 2>/dev/null; sleep 1; kill $pid 2>/dev/null; wait $pid 2>/dev/null
  echo "=== [$2] $1：節點輸出前 15 行"
  head -15 /tmp/ch07_nc_$2.log
  echo "=== [$2] 統計：Success=$(grep -c 'Success!' /tmp/ch07_nc_$2.log) Failure=$(grep -c 'Failure!' /tmp/ch07_nc_$2.log)"
  echo "=== [$2] 30 秒內 /generated_number 收到筆數：$(grep -c '^data:' /tmp/ch07_echo_$2.log)；其中 -1 的筆數：$(grep -c '^data: -1' /tmp/ch07_echo_$2.log)"
  echo "=== [$2] 收到的值：$(grep '^data:' /tmp/ch07_echo_$2.log | awk '{print $2}' | tr '\n' ' ')"
}

echo "################ (a) number_checker 原版 vs Sequence 版"
run_nc number_checker.xml orig
run_nc number_checker_seq.xml seq

echo "################ (b) bt_action Fallback 版（跑 70 秒）"
bash ./step3_bt_action.sh bt_action_fallback.xml 70
