#!/bin/bash
# 步驟 2：mock 硬體（ros2_control mock_components）跑 move_group＋控制器（無 RViz），
# 再依序跑書本三支規劃程式，記錄規劃成功與否與耗時
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
DEMO_LOG=logs/step2_demo_movegroup.log

# 背景啟動無頭 demo（setsid 開新行程群組，結束時整群殺掉）
setsid ros2 launch "$HERE/demo_headless.launch.py" > "$DEMO_LOG" 2>&1 &
DEMO_PGID=$!
echo "demo PGID=$DEMO_PGID"
cleanup() {
  kill -INT -- -"$DEMO_PGID" 2>/dev/null || true
  sleep 5
  kill -9 -- -"$DEMO_PGID" 2>/dev/null || true
}
trap cleanup EXIT

# 等 move_group 就緒（最多 60 秒）
for i in $(seq 1 30); do
  grep -q "You can start planning now" "$DEMO_LOG" && break
  sleep 2
done
grep -n "You can start planning now" "$DEMO_LOG" || { echo "move_group 未就緒"; tail -40 "$DEMO_LOG"; exit 1; }
echo "demo log 中 rviz 字樣行數：$(grep -c -i rviz "$DEMO_LOG" || true)"
echo "=== ros2_control 硬體載入紀錄 ==="
grep -E -i "hardware|GenericSystem|GazeboSim|Loaded|resource|interface.*(exist|already)" "$DEMO_LOG" | head -20 || true
sleep 5

echo "=== 控制器清單 ==="
timeout 20 ros2 service call /controller_manager/list_controllers \
  controller_manager_msgs/srv/ListControllers | grep -o "name='[a-z_]*'\|state='[a-z]*'" || true
echo "=== /joint_states（初始）==="
timeout 20 ros2 topic echo --once --no-daemon /joint_states --field position || true

run_planner() {
  local name=$1 limit=$2
  echo "=================== $name（timeout ${limit}s）==================="
  local t0=$(date +%s.%N)
  set +e
  timeout -s INT "$limit" ros2 launch panda_moveit_control "$name.launch.py" > "logs/step2_$name.log" 2>&1
  local rc=$?
  set -e
  local t1=$(date +%s.%N)
  printf '%s 結束碼=%s（124=被 timeout 收掉）牆鐘耗時=%.1f 秒\n' "$name" "$rc" "$(echo "$t1 - $t0" | bc)"
  grep -E -i "plan|fraction|fail|error|success|execut|attach|Could not" "logs/step2_$name.log" | head -25 || true
  echo "--- /joint_states（$name 之後）---"
  timeout 20 ros2 topic echo --once --no-daemon /joint_states --field position || true
}

MG_LINES0=$(wc -l < "$DEMO_LOG")
run_planner joint_space_planning 90
run_planner cartesian_space_planning 60
run_planner planning_with_obstacles 90

echo "=================== move_group 端規劃紀錄 ==================="
tail -n +"$MG_LINES0" "$DEMO_LOG" | grep -E -i "Planning request|Solution found|took|Plan and Execute|Execution|computed Cartesian|Motion plan|Fail|Success|Goal|collision" | head -80 || true
echo STEP2_DONE
