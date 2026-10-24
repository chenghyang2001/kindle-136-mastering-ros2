#!/bin/bash
# 步驟 3：Gazebo server 模式跑 cmd_vel_plugin.launch.py，驗證自訂系統外掛
#   ROS /cmd_vel_from_ros  --(CmdVelPlugin, 限速)-->  gz /cmd_vel  --(DiffDrive)--> 模型移動
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export GZ_IP=127.0.0.1
sudo ip link set lo multicast on

WS=~/k136_ws/ch16
cd "$WS"
source install/setup.bash
LOGDIR="$OLDPWD/logs"
mkdir -p "$LOGDIR"

# 本演練改：書上 gz_args='-r -v 4 empty.sdf' 會開 GUI，改成 server 模式 -s（只改工作區複製檔）
LAUNCH=src/cmd_vel_plugin/launch/cmd_vel_plugin.launch.py
sed -i "s/'gz_args': f'-r -v 4 empty.sdf'/'gz_args': f'-s -r -v 2 empty.sdf'  # 本演練改：server 模式，不開 GUI/" "$LAUNCH"
grep -n "gz_args" "$LAUNCH"

# launch 用 os.getcwd()/build/cmd_vel_plugin 當外掛路徑，所以必須在工作區根目錄啟動
setsid ros2 launch cmd_vel_plugin cmd_vel_plugin.launch.py > "$LOGDIR/step3_launch.log" 2>&1 &
LPID=$!
PGID=$(ps -o pgid= -p $LPID | tr -d ' ')
echo "launch PID=$LPID PGID=$PGID"
cleanup() { kill -- -"$PGID" 2>/dev/null || true; sleep 3; kill -9 -- -"$PGID" 2>/dev/null || true; }
trap cleanup EXIT

sleep 25

echo "=== gz 端 topic（應含 /cmd_vel、/model/diff_drive/odometry）==="
timeout 15 gz topic -l | grep -E "cmd_vel|odometry" || echo "(gz topic -l 沒列到)"

echo "=== ROS 節點（外掛內的 rclcpp 節點 cmd_vel_plugin 應出現）==="
timeout 20 ros2 node list --no-daemon || true
echo "=== /cmd_vel_from_ros 訂閱者 ==="
timeout 20 ros2 topic info /cmd_vel_from_ros --no-daemon || true

echo "=== 移動前 odometry ==="
timeout 20 ros2 topic echo --once --no-daemon /model/diff_drive/odometry nav_msgs/msg/Odometry --field pose.pose.position || true

echo "=== 從 ROS 發 /cmd_vel_from_ros（x=0.5 → 外掛應限到 0.2；z=0.3）==="
timeout 20 ros2 topic pub -r 10 /cmd_vel_from_ros geometry_msgs/msg/Twist "{linear: {x: 0.5}, angular: {z: 0.3}}" > "$LOGDIR/step3_pub.log" 2>&1 &
PUBPID=$!
sleep 6
echo "=== gz /cmd_vel（外掛發出，應看到 linear.x=0.2）==="
timeout 15 gz topic -e -t /cmd_vel -n 1 || echo "(沒收到 gz /cmd_vel)"
sleep 8
echo "=== 移動後 odometry ==="
timeout 20 ros2 topic echo --once --no-daemon /model/diff_drive/odometry nav_msgs/msg/Odometry --field pose.pose.position || true
echo "=== 移動後速度 ==="
timeout 20 ros2 topic echo --once --no-daemon /model/diff_drive/odometry nav_msgs/msg/Odometry --field twist.twist || true
wait $PUBPID 2>/dev/null || true
echo "STEP3_DONE"
