#!/bin/bash
# 步驟 2：Gazebo server 模式 + nav2.launch.py（hospital 地圖、不開 RViz），
#         等 lifecycle 節點全 active 後送近距離 NavigateToPose 目標，記錄 feedback 與結果
# 會跑數分鐘，請用 nohup 背景執行；所有等待迴圈都有次數上限
set -o pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on

WS=~/k136_ws/ch08
LOG=$(pwd)/logs
source "$WS/install/setup.bash"
# gazebo.launch.py 把設定 GZ_SIM_RESOURCE_PATH 的兩行註解掉了，hospital 模型找不到 → 這裡手動補
export GZ_SIM_RESOURCE_PATH="$WS/src/rosbot_description/models:$WS/src:$WS/install/rosbot_description/share:${GZ_SIM_RESOURCE_PATH}"

GOAL_X=${GOAL_X:-1.5}
GOAL_Y=${GOAL_Y:-0.0}
PGIDS=()

cleanup() {
  echo "=== 清理背景行程群組: ${PGIDS[*]}"
  for g in "${PGIDS[@]}"; do kill -INT -- "-$g" 2>/dev/null || true; done
  sleep 5
  for g in "${PGIDS[@]}"; do kill -9 -- "-$g" 2>/dev/null || true; done
}
trap cleanup EXIT

echo "=== 0. 目標點在地圖上是否為空地（讀 hospital.pgm）"
python3 - "$WS/src/rosbot_nav2_bringup/maps/hospital.pgm" "$GOAL_X" "$GOAL_Y" <<'PY' || true
import sys
path, gx, gy = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
data = open(path, 'rb').read()
# P5 標頭：magic、寬高、maxval（可能夾註解）
tokens, i = [], 0
while len(tokens) < 4:
    while data[i:i+1].isspace(): i += 1
    if data[i:i+1] == b'#':
        while data[i:i+1] != b'\n': i += 1
        continue
    j = i
    while not data[j:j+1].isspace(): j += 1
    tokens.append(data[i:j]); i = j
i += 1
w, h = int(tokens[1]), int(tokens[2])
px = data[i:]
ox, oy, res = -1.79, -8.72, 0.05
for name, x, y in [("robot(0,0)", 0.0, 0.0), ("goal", gx, gy)]:
    c = int((x - ox) / res); r = h - 1 - int((y - oy) / res)
    print(f"{name}: map=({x},{y}) pixel=({c},{r}) value={px[r*w+c]} (254=free, 0=occupied, 205=unknown) size={w}x{h}")
PY

echo "=== 1. 啟動 Gazebo（server 模式）+ bridge + robot_state_publisher + spawn"
setsid ros2 launch rosbot_description gazebo.launch.py > "$LOG/gazebo.log" 2>&1 &
PGIDS+=($!)
for i in $(seq 1 30); do
  sleep 3
  if timeout 15 ros2 topic list --no-daemon 2>/dev/null | grep -q '^/scan$' && grep -q "Entity creation successful" "$LOG/gazebo.log"; then
    echo "Gazebo 就緒（第 $i 次檢查）"; break
  fi
done
grep -E "Entity creation|ERROR|Error" "$LOG/gazebo.log" | head -10 || true
timeout 20 ros2 topic echo --once --no-daemon /clock 2>&1 | head -4 || true
timeout 20 ros2 topic echo --once --no-daemon /odom --field pose.pose 2>&1 | head -10 || true
timeout 20 ros2 topic echo --once --no-daemon /scan --field range_max 2>&1 | head -3 || true

echo "=== 2. 啟動 nav2.launch.py（hospital 地圖、本演練已拿掉 RViz）"
T0=$(date +%s)
setsid ros2 launch rosbot_nav2_bringup nav2.launch.py > "$LOG/nav2.log" 2>&1 &
PGIDS+=($!)
ACTIVE=0
for i in $(seq 1 40); do
  sleep 5
  N=$(grep -c "Managed nodes are active" "$LOG/nav2.log" || true)
  echo "第 $i 次檢查：已有 $N 個 lifecycle_manager 回報 active"
  if [ "$N" -ge 2 ]; then ACTIVE=1; break; fi
done
echo "nav2 啟動耗時 $(( $(date +%s) - T0 )) 秒，ACTIVE=$ACTIVE"
grep -E "Managed nodes are active|Activating|\[ERROR\]|\[FATAL\]" "$LOG/nav2.log" | head -40 || true

echo "=== 3. 逐一查 lifecycle 狀態"
for n in map_server amcl controller_server smoother_server planner_server behavior_server \
         velocity_smoother collision_monitor bt_navigator waypoint_follower docking_server; do
  S=$(timeout 15 ros2 service call /$n/get_state lifecycle_msgs/srv/GetState 2>&1 | grep -o "label='[a-z]*'" || echo "查不到")
  echo "$n: $S"
done

echo "=== 4. TF map→base_link（static map→odom + DiffDrive odom→base_footprint）"
timeout 10 ros2 run tf2_ros tf2_echo map base_link 2>&1 | head -8 || true

if [ "$ACTIVE" = "1" ]; then
  echo "=== 5. ros2 action send_goal /navigate_to_pose → ($GOAL_X, $GOAL_Y)"
  timeout 120 ros2 action send_goal --feedback /navigate_to_pose nav2_msgs/action/NavigateToPose \
    "{pose: {header: {frame_id: map}, pose: {position: {x: $GOAL_X, y: $GOAL_Y}, orientation: {w: 1.0}}}}" \
    > "$LOG/send_goal.log" 2>&1
  echo "send_goal 結束碼 $?"
  grep -E "Goal accepted|distance_remaining|navigation_time" "$LOG/send_goal.log" | awk 'NR%15==1' | head -30
  tail -12 "$LOG/send_goal.log"
  echo "=== 6. 到點後 /odom 位置"
  timeout 20 ros2 topic echo --once --no-daemon /odom --field pose.pose.position 2>&1 | head -5 || true

  echo "=== 7. 書附 nav2_client（互動式，輸入 1 → 先去 medical_shop 26m 外）只跑 40 秒看 feedback"
  printf '1\n' | timeout 40 "$WS/install/nav2_client/lib/nav2_client/navigation_client" \
    > "$LOG/nav2_client.log" 2>&1 || true
  head -5 "$LOG/nav2_client.log"; echo "..."; tail -5 "$LOG/nav2_client.log"
fi
echo NAV_DONE
