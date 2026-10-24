#!/bin/bash
# 第 3 步：假 /scan → rf2o_laser_odometry → 看 /odom 是否估出平移
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch12/install/setup.bash

HERE=$(pwd)
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill -- -"$p" 2>/dev/null || true; done; }
trap cleanup EXIT

# robot_state_publisher 提供 base_footprint -> base_laser（rf2o 需要這段 TF）
setsid ros2 launch mobile_robot_model display.launch.py > "$HERE/logs/step3${TAG}_rsp.log" 2>&1 &
PIDS+=($!)
# rf2o：用書上的 launch（/scan、/odom、base_footprint、odom、15 Hz）
setsid ros2 launch rf2o_laser_odometry rf2o_laser_odometry.launch.py > "$HERE/logs/step3${TAG}_rf2o.log" 2>&1 &
PIDS+=($!)
sleep 4
# 假 LiDAR（取代 ldlidar_sl_ros2_node）
FAKE_FOV_DEG=${FAKE_FOV_DEG:-360} setsid python3 -u "$HERE/fake_scan.py" > "$HERE/logs/step3${TAG}_fake_scan.log" 2>&1 &
PIDS+=($!)
sleep 8

echo "=== node list ==="
timeout 20 ros2 node list --no-daemon || true
echo "=== /scan 頻率 ==="
timeout 8 ros2 topic hz /scan 2>&1 | head -4 || true

echo "=== 連續記錄 /odom 的 x（約 45 秒）==="
timeout 45 ros2 topic echo --no-daemon /odom nav_msgs/msg/Odometry --field pose.pose.position.x \
  > "$HERE/logs/step3${TAG}_odom_x.log" 2>&1 || true

echo "=== /odom 最後一則 ==="
timeout 15 ros2 topic echo --once --no-daemon /odom nav_msgs/msg/Odometry 2>&1 | head -30 || true
echo "=== /odom 頻率 ==="
timeout 8 ros2 topic hz /odom 2>&1 | head -4 || true
echo "=== tf2_echo odom -> base_footprint ==="
timeout 5 ros2 run tf2_ros tf2_echo odom base_footprint 2>&1 | head -8 || true

echo "=== /odom x 取樣（每 30 筆一筆）==="
grep -E '^-?[0-9]' "$HERE/logs/step3${TAG}_odom_x.log" | awk 'NR%30==1' || true
echo "=== 真值（fake_scan 最後幾行）==="
tail -3 "$HERE/logs/step3${TAG}_fake_scan.log"
echo "STEP3_DONE"
