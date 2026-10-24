#!/bin/bash
# 步驟 5：重做 number_checker 原版 vs Sequence 版比較
# 修正 step4 的問題：ros2 run 會再開子行程，kill $! 只殺到外層 python，
# 舊節點殘留繼續發布，污染下一輪。這裡改成直接執行二進位檔，$! 就是節點本身。
set -o pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
WS=~/k136_ws/ch07
source "$WS/install/setup.bash"
BIN=$WS/install/first_bts/lib/first_bts/number_checker
SHARE=$WS/install/first_bts/share/first_bts/trees

run_nc() {  # $1=樹檔 $2=標籤
  "$BIN" --ros-args -p tree_xml_file:="$SHARE/$1" > /tmp/ch07_nc_$2.log 2>&1 &
  local pid=$!
  sleep 3
  timeout 30 ros2 topic echo /generated_number std_msgs/msg/Int32 --no-daemon > /tmp/ch07_echo_$2.log 2>&1
  kill -INT $pid 2>/dev/null; sleep 1; kill -9 $pid 2>/dev/null; wait $pid 2>/dev/null
  echo "--- [$2] 殺掉後是否還有 number_checker：$(pgrep -c -x number_checker || true) 個"
  echo "=== [$2] $1：節點輸出前 12 行"
  head -12 /tmp/ch07_nc_$2.log
  echo "=== [$2] 統計：Success=$(grep -c 'Success!' /tmp/ch07_nc_$2.log) Failure=$(grep -c 'Failure!' /tmp/ch07_nc_$2.log)"
  echo "=== [$2] 30 秒內 /generated_number 收到筆數：$(grep -c '^data:' /tmp/ch07_echo_$2.log)；其中 -1：$(grep -c '^data: -1' /tmp/ch07_echo_$2.log)"
  echo "=== [$2] 收到的值：$(grep '^data:' /tmp/ch07_echo_$2.log | awk '{print $2}' | tr '\n' ' ')"
}

echo "開始前 number_checker 行程數：$(pgrep -c -x number_checker || true)"
run_nc number_checker.xml orig
run_nc number_checker_seq.xml seq
echo "--- Sequence 版中『三關全過』的次數（CheckNumber3 門檻 80 的 Success）：$(grep -c 'Threshold: 80 - Success' /tmp/ch07_nc_seq.log)"
