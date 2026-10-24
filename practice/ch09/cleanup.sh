#!/bin/bash
# 章末清理：停掉殘留的 ROS／MoveIt／Gazebo 行程並關閉 ros2 daemon
# 用 pgrep 列 PID 再排除自己，避免 pkill -f 誤殺本腳本
set -o pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on

PATTERN='gz sim|gzserver|ruby.*gz|parameter_bridge|robot_state_publisher|ros_gz_sim|static_transform_publisher|move_group|ros2_control_node|controller_manager|spawner|joint_space_planning|cartesian_space_planning|planning_with_obstacles|rviz2|rqt|ros2 run|ros2 launch|ros2 topic|ros2 action|ros2 service|tf2_echo|step2_mock|step3_'
SELF=$$
PIDS=$(pgrep -f -- "$PATTERN" | grep -vx "$SELF" | grep -vx "$PPID" || true)
if [ -n "$PIDS" ]; then
  echo "發現殘留行程："; ps -o pid,cmd -p $PIDS || true
  kill $PIDS 2>/dev/null || true; sleep 3; kill -9 $PIDS 2>/dev/null || true
else
  echo "沒有殘留的 ROS／Gazebo 行程"
fi
timeout 15 ros2 daemon stop || echo "daemon stop 逾時或 daemon 本來就沒在跑"
echo "=== 清理後檢查 ==="
LEFT=$(pgrep -f -- "$PATTERN|_ros2_daemon" | grep -vx "$SELF" | grep -vx "$PPID" || true)
if [ -z "$LEFT" ]; then echo "乾淨：無殘留"; else ps -o pid,cmd -p $LEFT; exit 1; fi
