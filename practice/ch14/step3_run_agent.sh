#!/bin/bash
# 第 3 步：turtlesim（offscreen）+ AI agent（假 LLM），送「往前走」指令，讀 /turtle1/pose 證明有移動
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on

# 用法：bash step3_run_agent.sh minimal   → 備案：不依賴 langchain 的最小假 agent
#       bash step3_run_agent.sh langchain → 書上 agent + langchain 假 LLM
MODE=${1:-minimal}
HERE=$(pwd)
LOG=$HERE/logs/run_$MODE
mkdir -p "$LOG"
WS=~/k136_ws/ch14
if [ "$MODE" = "langchain" ]; then
  source "$WS/install/setup.bash"
  # agent 的執行檔 shebang 是系統 python3，把 venv 的 site-packages 接到 PYTHONPATH 才找得到 langchain
  VENV_SITE=$(~/k136_venv/bin/python -c "import site; print(site.getsitepackages()[0])")
  export PYTHONPATH="$PYTHONPATH:$VENV_SITE"
  AGENT_CMD=("$WS/install/ros2_basic_agent/lib/ros2_basic_agent/ros2_ai_agent_turtlesim")
else
  python3 "$HERE/src_patch/minimal_agent.py" --selftest
  AGENT_CMD=(python3 "$HERE/src_patch/minimal_agent.py")
fi
echo "MODE=$MODE"
export PYTHONUNBUFFERED=1
export QT_QPA_PLATFORM=offscreen
unset OPENAI_API_KEY
export LLM_BACKEND=fake

PIDS=()
cleanup() {
  for p in "${PIDS[@]}"; do kill -- -"$p" 2>/dev/null || true; done
  sleep 1
  for p in "${PIDS[@]}"; do kill -9 -- -"$p" 2>/dev/null || true; done
}
trap cleanup EXIT

# 用 setsid 開新行程群組，結束時整組殺掉（避免子行程殘留）
setsid /opt/ros/jazzy/lib/turtlesim/turtlesim_node > "$LOG/turtlesim_node.log" 2>&1 &
PIDS+=($!)
setsid "${AGENT_CMD[@]}" > "$LOG/agent_node.log" 2>&1 &
PIDS+=($!)
sleep 10

echo "=== node list ==="
timeout 20 ros2 node list --no-daemon || true

pose_x() { timeout 20 ros2 topic echo --once --no-daemon /turtle1/pose 2>/dev/null | tee -a "$LOG/pose_samples.txt" || true; }
: > "$LOG/pose_samples.txt"

echo "=== pose（指令前）==="
BEFORE=$(pose_x); echo "$BEFORE"

# 背景錄下 agent 發出的 cmd_vel
setsid timeout 30 ros2 topic echo --no-daemon /turtle1/cmd_vel > "$LOG/cmd_vel_echo.txt" 2>&1 &
PIDS+=($!)
sleep 4

echo "=== 送出指令 1：Move the turtle forward 2 units ==="
timeout 20 ros2 topic pub --once -w 1 /prompt std_msgs/msg/String "{data: 'Move the turtle forward 2 units'}"
sleep 4
AFTER1=$(pose_x); echo "$AFTER1"

echo "=== 送出指令 2：往前走 5 單位 ==="
timeout 20 ros2 topic pub --once -w 1 /prompt std_msgs/msg/String "{data: '往前走 5 單位'}"
sleep 4
AFTER2=$(pose_x); echo "$AFTER2"

echo "=== 送出指令 3：where is the turtle?（get_pose 工具）==="
timeout 20 ros2 topic pub --once -w 1 /prompt std_msgs/msg/String "{data: 'where is the turtle?'}"
sleep 3

getx() { echo "$1" | awk '/^x:/{print $2; exit}'; }
X0=$(getx "$BEFORE"); X1=$(getx "$AFTER1"); X2=$(getx "$AFTER2")
python3 -c "
x0,x1,x2=float('$X0'),float('$X1'),float('$X2')
print(f'x: {x0:.4f} -> {x1:.4f} -> {x2:.4f}  (dx1={x1-x0:+.4f}, dx2={x2-x1:+.4f})')
print('MOVED_OK' if x1>x0+0.05 and x2>x1+0.05 else 'NOT_MOVED')
"

sleep 2
echo "=== cmd_vel 收到的訊息（linear.x）==="
grep -A1 "^linear:" "$LOG/cmd_vel_echo.txt" | grep "x:" || echo "（沒錄到 cmd_vel）"
echo "=== agent log ==="
cat "$LOG/agent_node.log"
echo "STEP3_DONE"
