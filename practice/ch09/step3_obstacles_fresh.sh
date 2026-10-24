#!/bin/bash
# 步驟 3：重開 mock demo（手臂回到 ready 姿態），單獨跑 planning_with_obstacles，
# 並在節點執行中查 planning scene，確認桌子（table）與夾取物（grasp）有加進場景
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on

WS=~/k136_ws/ch09
source "$WS/install/setup.bash"
HERE=$(pwd)
mkdir -p logs
DEMO_LOG=logs/step3_demo_movegroup.log
NODE_LOG=logs/step3_planning_with_obstacles.log

setsid ros2 launch "$HERE/demo_headless.launch.py" > "$DEMO_LOG" 2>&1 &
DEMO_PGID=$!
NODE_PGID=""
cleanup() {
  [ -n "$NODE_PGID" ] && kill -INT -- -"$NODE_PGID" 2>/dev/null || true
  kill -INT -- -"$DEMO_PGID" 2>/dev/null || true
  sleep 5
  [ -n "$NODE_PGID" ] && kill -9 -- -"$NODE_PGID" 2>/dev/null || true
  kill -9 -- -"$DEMO_PGID" 2>/dev/null || true
}
trap cleanup EXIT

for i in $(seq 1 30); do
  grep -q "You can start planning now" "$DEMO_LOG" && break
  sleep 2
done
grep -q "You can start planning now" "$DEMO_LOG" || { echo "move_group 未就緒"; tail -40 "$DEMO_LOG"; exit 1; }
sleep 5
echo "=== /joint_states（起點）==="
timeout 20 ros2 topic echo --once --no-daemon /joint_states --field position || true

T0=$(date +%s.%N)
setsid ros2 launch panda_moveit_control planning_with_obstacles.launch.py > "$NODE_LOG" 2>&1 &
NODE_PGID=$!

# 等規劃結果（最多 60 秒），期間查一次 planning scene
SCENE_DONE=0
for i in $(seq 1 30); do
  sleep 2
  if [ "$SCENE_DONE" = 0 ] && grep -q "Planning request" "$NODE_LOG"; then
    echo "=== planning scene：世界物件與附著物件（components=4+2+8?→用 1023 全取，只 grep id）==="
    timeout 20 ros2 service call /get_planning_scene moveit_msgs/srv/GetPlanningScene \
      "{components: {components: 1023}}" | grep -o "id='[a-z0-9_]*'\|link_name='[a-z0-9_]*'" | sort | uniq -c || true
    SCENE_DONE=1
  fi
  grep -q -E "Plan and Execute request (complete|aborted)" "$NODE_LOG" && break
done
T1=$(date +%s.%N)
printf 'planning_with_obstacles 從啟動到 move() 結束：%.1f 秒\n' "$(echo "$T1 - $T0" | bc)"
grep -E -i "plan|fail|error|success|execut" "$NODE_LOG" | grep -v "Loaded adapter" | cut -c1-220 | head -20 || true
echo "=== /joint_states（之後）==="
timeout 20 ros2 topic echo --once --no-daemon /joint_states --field position || true
echo "=== move_group 端 ==="
grep -E -i "Motion plan|Solution found|RRTConnect|GOAL_STATE|FAILURE|Completed trajectory|Goal reached|collision|attach" "$DEMO_LOG" | cut -c1-230 | head -30 || true
echo STEP3_DONE
