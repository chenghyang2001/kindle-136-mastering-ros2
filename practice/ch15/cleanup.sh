#!/bin/bash
# 章末清理：停掉殘留的 ROS 2 CLI／gz／rviz／訓練程式行程，再停 daemon（本章沒有啟動 ROS 節點，屬保險步驟）
# 獨立成腳本執行，避免 pkill -f 比對到呼叫端的 bash -c 自己
set -o pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

PATTERN='ros2 (topic|launch|run|node|service|action)|gz sim|rviz2|_ros2_daemon|cartpole_qlearning.py|turtlesim_node'
show() { ps -eo pid,args | grep -E "$PATTERN" | grep -v -E "grep|cleanup\.sh" || true; }

echo "=== 清理前 ==="
show
for pid in $(show | awk '{print $1}'); do kill "$pid" 2>/dev/null || true; done
sleep 2
for pid in $(show | awk '{print $1}'); do kill -9 "$pid" 2>/dev/null || true; done

echo "=== ros2 daemon stop ==="
timeout 15 ros2 daemon stop || true

echo "=== 清理後（空白代表沒有殘留）==="
LEFT=$(show)
echo "$LEFT"
[ -z "$LEFT" ] && echo "NO_LEFTOVER" || echo "LEFTOVER_FOUND"
