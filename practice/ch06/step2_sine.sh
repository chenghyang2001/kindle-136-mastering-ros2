#!/bin/bash
# Gazebo server 模式跑 start_simu.launch.py，查控制器／硬體介面，切換到 sine_controller 並錄 /joint_states
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
source ~/k136_ws/ch06/install/setup.bash
LOGDIR="$PWD/logs"

timeout 150 ros2 launch two_joints_robot start_simu.launch.py > "$LOGDIR/step2_launch.log" 2>&1 &
LPID=$!
trap 'kill -INT $LPID 2>/dev/null || true; sleep 3; kill $LPID 2>/dev/null || true' EXIT
echo "launch PID=$LPID，等 Gazebo 與 spawner 30 秒"
sleep 30

list_ctrl() {
  timeout 20 ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers \
    | grep -o -E "name='[a-z_]+', state='[a-z]+', type='[^']+'" || echo "(list_controllers 失敗)"
}
echo "=== list_controllers（切換前）==="; list_ctrl

echo "=== list_hardware_interfaces ==="
timeout 20 ros2 service call /controller_manager/list_hardware_interfaces controller_manager_msgs/srv/ListHardwareInterfaces \
  | grep -o -E "name='[^']+', data_type='[^']*', is_available=[A-Za-z]+, is_claimed=[A-Za-z]+|name='[^']+', is_available=[A-Za-z]+, is_claimed=[A-Za-z]+" || echo "(失敗)"

echo "=== switch：停 position_control、啟動 sine_controller ==="
timeout 20 ros2 service call /controller_manager/switch_controller controller_manager_msgs/srv/SwitchController \
  "{activate_controllers: [sine_controller], deactivate_controllers: [position_control], strictness: 2, activate_asap: true, timeout: {sec: 5}}" | tail -2
echo "=== list_controllers（切換後）==="; list_ctrl

echo "=== 發布 /sine_param：base_joint 振幅 0.5rad 頻率 0.5Hz、link1_link2 振幅 0.2m 頻率 0.5Hz ==="
timeout 4 ros2 topic pub -r 2 /sine_param std_msgs/msg/Float32MultiArray "{data: ${SINE_PARAM:-[0.5, 0.5, 0.2, 0.5]}}" > /dev/null 2>&1 || true

echo "=== 錄 /joint_states 8 秒 ==="
timeout 30 python3 ./record_joint_states.py 8 "$LOGDIR/joint_states${TAG}.csv"

echo "=== launch log 中 sine_controller 相關訊息 ==="
grep -E "sine_controller|Configuration successful|Activation successful" "$LOGDIR/step2_launch.log" | head -10 || true
