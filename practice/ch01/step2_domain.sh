#!/bin/bash
# 第 1 章步驟 2：指定 RMW = Fast DDS，示範 ROS_DOMAIN_ID 隔離
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
# 本演練改：區網上有其他機器也在用 domain 36，限定只探索本機
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
mkdir -p logs

echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION"

# talker 在 domain 36 發布
ROS_DOMAIN_ID=36 timeout 40 ros2 run demo_nodes_cpp talker > logs/domain36_talker.log 2>&1 &
TALKER_PID=$!

# listener 在 domain 37：應收不到
ROS_DOMAIN_ID=37 timeout 20 ros2 run demo_nodes_py listener > logs/domain37_listener.log 2>&1 &
L37_PID=$!
# listener 在 domain 36：應收得到
ROS_DOMAIN_ID=36 timeout 20 ros2 run demo_nodes_py listener > logs/domain36_listener.log 2>&1 &
L36_PID=$!
sleep 10

echo "=== domain 36 看到的節點 ==="
ROS_DOMAIN_ID=36 ros2 node list --no-daemon
echo "=== domain 37 看到的節點（只會有自己的 listener，看不到 talker）==="
ROS_DOMAIN_ID=37 ros2 node list --no-daemon
echo "=== domain 37 的 /chatter 發布者數 ==="
ROS_DOMAIN_ID=37 ros2 topic info /chatter --no-daemon 2>&1 || true

wait $L37_PID || true
wait $L36_PID || true
kill $TALKER_PID 2>/dev/null || true
wait $TALKER_PID 2>/dev/null || true

N36=$(grep -c 'I heard' logs/domain36_listener.log || true)
N37=$(grep -c 'I heard' logs/domain37_listener.log || true)
echo "domain 36 listener 收到：$N36 則"
echo "domain 37 listener 收到：$N37 則"
if [ "$N36" -gt 0 ] && [ "$N37" -eq 0 ]; then
  echo "結果：PASS（不同 domain 互相看不到）"
else
  echo "結果：FAIL"; exit 1
fi
