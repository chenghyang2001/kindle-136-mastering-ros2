#!/bin/bash
# 不開 RViz：背景跑 robot_state_publisher + joint_state_publisher（非 GUI），用 tf2_echo 與 topic echo 驗證
# 用法：bash step3_tf.sh <rrbot|rosbot>
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on
WS=~/k136_ws/ch04
source "$WS/install/setup.bash"
ROBOT=${1:-rrbot}
URDF=$WS/generated/$ROBOT.urdf
[ -f "$URDF" ] || { echo "錯誤：找不到 $URDF，請先跑 step2"; exit 1; }
case $ROBOT in
  rrbot)  FROM=world;     TO=link2 ;;
  rosbot) FROM=base_link; TO=left_wheel_1 ;;
  *) echo "錯誤：未知機器人 $ROBOT"; exit 1 ;;
esac

# 結束時一定停掉背景節點
PIDS=""
cleanup() { [ -n "$PIDS" ] && kill $PIDS 2>/dev/null; sleep 1; [ -n "$PIDS" ] && kill -9 $PIDS 2>/dev/null; true; }
trap cleanup EXIT

# 本演練改：書上用 launch 同時開 joint_state_publisher_gui + RViz，這裡只起兩個無 GUI 節點
ros2 run robot_state_publisher robot_state_publisher --ros-args -p robot_description:="$(cat "$URDF")" > /tmp/k136_rsp.log 2>&1 &
PIDS="$PIDS $!"
ros2 run joint_state_publisher joint_state_publisher > /tmp/k136_jsp.log 2>&1 &
PIDS="$PIDS $!"
sleep 8

echo "===== node list ====="
timeout 20 ros2 node list --no-daemon || true
echo "===== robot_state_publisher log ====="
head -20 /tmp/k136_rsp.log
echo "===== /robot_description（前 15 行）====="
timeout 20 ros2 topic echo /robot_description --once --no-daemon --full-length 2>&1 | head -15 || true
echo "===== /joint_states ====="
timeout 20 ros2 topic echo /joint_states --once --no-daemon 2>&1 | head -25 || true
echo "===== tf2_echo $FROM -> $TO ====="
timeout 10 ros2 run tf2_ros tf2_echo "$FROM" "$TO" 2>&1 | head -20 || true
echo "===== /tf_static 一筆 ====="
timeout 15 ros2 topic echo /tf_static --once --no-daemon 2>&1 | head -30 || true
