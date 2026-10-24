#!/bin/bash
# 複製 Chapter05 三個套件到 WSL 工作區，改成無畫面版本後 colcon build（書本 repo 原檔不動）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter05
WS=~/k136_ws/ch05
PKGS="rrbot_gazebo diffbot_gazebo rosbot_description"
mkdir -p "$WS/src"
for p in $PKGS; do rm -rf "$WS/src/$p"; cp -r "$BOOK/$p" "$WS/src/"; done
# 本演練改：rrbot.xacro 會 $(find rrbot_description)，該套件在 Chapter04，一起複製
rm -rf "$WS/src/rrbot_description"; cp -r "$BOOK/../Chapter04/rrbot_description" "$WS/src/"

# ---- 本演練改：Gazebo 改 server 模式（-s），拿掉 rviz / rqt 這些 GUI ----
for f in "$WS"/src/diffbot_gazebo/launch/diffbot_gz.launch.py "$WS"/src/rrbot_gazebo/launch/rrbot_gazebo.launch.py; do
  sed -i 's/" -r'"'"'"\]/" -s -r'"'"'"]/' "$f"
  sed -i -E 's/^( *)rviz,$/\1# rviz,  # 本演練改：不開 RViz/' "$f"
  sed -i -E 's/^( *)(rqt_robot_steering|delayed_rqt_traj_controller),$/\1# \2,  # 本演練改：不開 rqt/' "$f"
  echo "--- $f 修改後 ---"; grep -n -E "gz_args|# rviz|# rqt|# delayed" "$f"
done

# ---- 本演練改：ros2 control load_controller 會經 ros2 daemon（本機會卡死），改用 spawner ----
F="$WS"/src/rrbot_gazebo/launch/rrbot_gazebo.launch.py
sed -i "s/cmd=\['ros2', 'control', 'load_controller', '--set-state', 'active',/cmd=['ros2', 'run', 'controller_manager', 'spawner',/" "$F"
grep -n "spawner" "$F"

# ---- 本演練改：gz DiffDrive 的 odom 沒有橋接到 ROS，補一條 /odom 讓 ros2 topic echo 能比對 ----
printf '%s\n' \
  '# 本演練改：補橋接 gz DiffDrive plugin 發布的 odom' \
  '- ros_topic_name: "/odom"' \
  '  gz_topic_name: "/odom"' \
  '  ros_type_name: "nav_msgs/msg/Odometry"' \
  '  gz_type_name: "gz.msgs.Odometry"' \
  '  direction: GZ_TO_ROS' >> "$WS/src/diffbot_gazebo/config/ros_gz_bridge_gazebo.yaml"
tail -7 "$WS/src/diffbot_gazebo/config/ros_gz_bridge_gazebo.yaml"

cd "$WS"
date
colcon build --symlink-install --event-handlers console_direct- 2>&1 | tail -20
date
source install/setup.bash
ros2 pkg list | grep -E "rrbot_gazebo|diffbot_gazebo|rosbot_description"
