#!/bin/bash
# 步驟 0b：印出 bridge 設定、gazebo 外掛、nav2 client 原始碼、nav2_params、地圖 yaml
set -eo pipefail
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter08
cd "$BOOK"
for f in rosbot_description/config/ros_gz_bridge_gazebo.yaml rosbot_description/urdf/rosbot.gazebo \
         rosbot_description/urdf/rosbot.ros2control rosbot_nav2_bringup/maps/hospital.yaml \
         nav2_client/include/nav2_client/*.h* nav2_client/src/*.cpp nav2_bt_client/config/map_locations.yaml \
         rosbot_nav2_bringup/params/nav2_params.yaml; do
  echo "=================== $f"; cat "$f"; echo
done
grep -n -E "world|spherical|<model|<include|<uri" rosbot_description/worlds/hospital.sdf | head -40
dpkg -l | grep -E "behaviortree" | awk '{print $2}' || true
