#!/bin/bash
# 無畫面跑 diffbot_gz.launch.py，發 cmd_vel 前進 10 秒，比對前後 odom 位置
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch05/install/setup.bash
LOG=logs/diffbot_launch.log

timeout 150 ros2 launch diffbot_gazebo diffbot_gz.launch.py > "$LOG" 2>&1 &
LPID=$!
trap 'kill -INT $LPID 2>/dev/null || true; sleep 5; kill -9 $LPID 2>/dev/null || true' EXIT

# 等 spawn 完成（最多 60 秒）
for i in $(seq 1 30); do
  grep -q -i "Entity creation successful\|Requested creation of entity" "$LOG" && break
  sleep 2
done
grep -i -E "entity|error" "$LOG" | head -5 || true
sleep 8

echo "=== gz topic -l（odom 相關）==="
timeout 10 gz topic -l | grep -E "odom|cmd_vel|tf|joint" || true
echo "=== ros2 topic list ==="
timeout 20 ros2 topic list --no-daemon || true

pose() { timeout 15 ros2 topic echo --once --no-daemon /odom nav_msgs/msg/Odometry --field pose.pose.position 2>&1 | head -4; }
echo "=== 前進前 odom ==="
pose | tee logs/odom_before.txt

echo "=== 發 cmd_vel linear.x=0.5，10 Hz，10 秒 ==="
timeout 10 ros2 topic pub -r 10 /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.5}, angular: {z: 0.0}}" > logs/cmd_vel_pub.log 2>&1 || true
tail -2 logs/cmd_vel_pub.log
sleep 2

echo "=== 前進後 odom ==="
pose | tee logs/odom_after.txt
echo "=== /odom 頻率 ==="
timeout 8 ros2 topic hz /odom 2>&1 | head -4 || true
