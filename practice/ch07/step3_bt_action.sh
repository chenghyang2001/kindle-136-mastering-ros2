#!/bin/bash
# 步驟 3：bt_action.launch.py（行為樹呼叫 reach_location action server）
# 參數 $1 = 樹檔名（預設 bt_action.xml），$2 = 執行秒數（預設 60）
set -o pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch07/install/setup.bash
TREE=${1:-bt_action.xml}
DUR=${2:-60}
TREE_PATH=~/k136_ws/ch07/install/bt_action_server/share/bt_action_server/trees/$TREE
echo "使用樹檔：$TREE_PATH"; cat "$TREE_PATH" | sed -n '/<BehaviorTree/,/<\/BehaviorTree>/p'

echo "################ A. 沒有 action server 時跑 bt_action 6 秒"
timeout 6 ros2 run bt_action_server bt_action --ros-args -p tree_xml_file:="$TREE_PATH" 2>&1 | head -12 || true

echo "################ B. 先啟動 reach_location_server，再跑 bt_action ${DUR} 秒"
ros2 run bt_action_server reach_location_server > /tmp/ch07_server.log 2>&1 &
SRV_PID=$!
sleep 4
timeout 20 ros2 action list -t || echo "(action list 逾時；此指令不支援 --no-daemon)"
if [ "$TREE" = "bt_action.xml" ]; then
  timeout "$DUR" ros2 launch bt_action_server bt_action.launch.py > /tmp/ch07_bt.log 2>&1
else
  timeout "$DUR" ros2 run bt_action_server bt_action --ros-args -p tree_xml_file:="$TREE_PATH" > /tmp/ch07_bt.log 2>&1
fi
kill -INT $SRV_PID 2>/dev/null || true; sleep 1; kill $SRV_PID 2>/dev/null || true
wait $SRV_PID 2>/dev/null || true

echo "--- 行為樹端輸出（去除重複 Waiting 行）"
grep -v "Waiting server execution" /tmp/ch07_bt.log | head -40
echo "--- Waiting 行數: $(grep -c 'Waiting server execution' /tmp/ch07_bt.log)"
echo "--- action server 端輸出"
head -60 /tmp/ch07_server.log
echo "--- 統計"
echo "server Goal succeeded: $(grep -c 'Goal succeeded' /tmp/ch07_server.log)"
echo "server Goal failed:    $(grep -c 'Goal failed' /tmp/ch07_server.log)"
echo "BT CallAction Success: $(grep -c 'CallAction\]: Success' /tmp/ch07_bt.log)"
echo "BT CallAction Failure: $(grep -c 'CallAction\]: Failure' /tmp/ch07_bt.log)"
echo "BT WaitForServer Failure: $(grep -c 'WaitForServer\]: Failure' /tmp/ch07_bt.log)"
