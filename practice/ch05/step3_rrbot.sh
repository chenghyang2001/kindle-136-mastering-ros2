#!/bin/bash
# 無畫面跑 rrbot_gazebo.launch.py，列出 ros_gz_bridge 橋接的 topic 與 controller 狀態
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch05/install/setup.bash
LOG=logs/rrbot_launch.log

timeout 110 ros2 launch rrbot_gazebo rrbot_gazebo.launch.py > "$LOG" 2>&1 &
LPID=$!
trap 'kill -INT $LPID 2>/dev/null || true; sleep 5; kill -9 $LPID 2>/dev/null || true' EXIT

for i in $(seq 1 30); do
  grep -q "Entity creation successful" "$LOG" && break
  sleep 2
done
sleep 12

echo "=== ros_gz_bridge 建立的橋接（launch log）==="
grep -i "Creating GZ->ROS\|Creating ROS->GZ" "$LOG" || true
echo "=== gz topic -l ==="
timeout 10 gz topic -l || true
echo "=== ros2 topic list -t ==="
timeout 20 ros2 topic list -t --no-daemon || true
echo "=== parameter_bridge 節點的 topic ==="
timeout 20 ros2 node info --no-daemon /ros_gz_bridge 2>&1 | head -30 || true
echo "=== /clock 一筆 ==="
timeout 15 ros2 topic echo --once --no-daemon /clock 2>&1 | head -4 || true
echo "=== controllers ==="
grep -E "spawner.*(Configured|activated|Loaded)" "$LOG" || true
timeout 20 ros2 control list_controllers --no-daemon 2>&1 || true
echo "=== 送一個 arm_controller 軌跡（joint1=0.5, joint2=-0.5）==="
timeout 20 ros2 action send_goal /arm_controller/follow_joint_trajectory control_msgs/action/FollowJointTrajectory \
  "{trajectory: {joint_names: [joint1, joint2], points: [{positions: [0.5, -0.5], time_from_start: {sec: 2}}]}}" 2>&1 | tail -6 || true
sleep 1
echo "=== /joint_states 一筆 ==="
timeout 15 ros2 topic echo --once --no-daemon /joint_states --field position 2>&1 | head -4 || true
