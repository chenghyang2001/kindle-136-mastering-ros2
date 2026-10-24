#!/bin/bash
# 第 3 步：啟動假飛控 fake_fcu.py，讓 px4_ctrl 通過「等服務」，再用 FIFO 餵選單指令
#         arm → takeoff → move，期間用 ros2 topic echo --once 抓 OffboardControlMode／TrajectorySetpoint
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch11/install/setup.bash

LOGDIR=./logs
EXE=~/k136_ws/ch11/install/px4_ctrl/lib/px4_ctrl/px4_ctrl
FIFO=/tmp/k136_ch11_px4_stdin
FCU_PGID=""; CTRL_PGID=""

cleanup() {
  exec 3>&- 2>/dev/null || true
  for g in $CTRL_PGID $FCU_PGID; do kill -INT -- -"$g" 2>/dev/null || true; done
  sleep 2
  for g in $CTRL_PGID $FCU_PGID; do kill -9 -- -"$g" 2>/dev/null || true; done
  rm -f "$FIFO"
}
trap cleanup EXIT

# setsid 讓節點自成行程群組，結束時 kill -- -PGID 才殺得乾淨
setsid python3 ./fake_fcu.py > "$LOGDIR/step3_fake_fcu.log" 2>&1 &
FCU_PGID=$!
sleep 8

rm -f "$FIFO"; mkfifo "$FIFO"
exec 3<>"$FIFO"   # 先以讀寫開啟，px4_ctrl 讀 stdin 時才不會一開始就拿到 EOF
setsid "$EXE" < "$FIFO" > "$LOGDIR/step3_px4_ctrl.log" 2>&1 &
CTRL_PGID=$!
sleep 6

echo "=== node list ==="
timeout 15 ros2 node list --no-daemon || true
echo "=== echo --once /fmu/in/offboard_control_mode（心跳，arm 之前就在發）==="
timeout 15 ros2 topic echo --once --no-daemon /fmu/in/offboard_control_mode | tee "$LOGDIR/step3_offboard_control_mode.txt" || echo "（逾時沒收到）"

echo "=== 背景先掛好 echo --once /fmu/in/trajectory_setpoint，再送 arm / takeoff ==="
timeout 30 ros2 topic echo --once --no-daemon /fmu/in/trajectory_setpoint > "$LOGDIR/step3_trajectory_setpoint_takeoff.txt" 2>&1 &
ECHO_PID=$!
sleep 5
printf 'arm\n' >&3; sleep 2
printf 'takeoff\n' >&3
wait $ECHO_PID || echo "（takeoff setpoint echo 逾時）"
cat "$LOGDIR/step3_trajectory_setpoint_takeoff.txt"

echo "=== move 到 3 0 -5（v_max 0.5 m/s、10 Hz，約 60 筆）；同時量 hz ==="
timeout 30 ros2 topic echo --once --no-daemon /fmu/in/trajectory_setpoint > "$LOGDIR/step3_trajectory_setpoint_move.txt" 2>&1 &
ECHO_PID=$!
timeout 12 ros2 topic hz /fmu/in/trajectory_setpoint > "$LOGDIR/step3_hz_trajectory.txt" 2>&1 &
HZ_PID=$!
sleep 5
printf 'move\n' >&3; sleep 1
printf '3 0 -5\n' >&3
wait $ECHO_PID || echo "（move setpoint echo 逾時）"
cat "$LOGDIR/step3_trajectory_setpoint_move.txt"
wait $HZ_PID || true
echo "--- hz ---"; tail -6 "$LOGDIR/step3_hz_trajectory.txt"
sleep 3
printf 'disarm\n' >&3; sleep 2
printf 'exit\n' >&3; sleep 1

cleanup; trap - EXIT
echo "=== px4_ctrl 輸出 ==="
cat "$LOGDIR/step3_px4_ctrl.log"
echo "=== fake_fcu 輸出 ==="
cat "$LOGDIR/step3_fake_fcu.log"
