#!/bin/bash
# 步驟 1：複製 Chapter08 四個套件到 ~/k136_ws/ch08/src 並建置（書本原檔不動）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter08
WS=~/k136_ws/ch08
mkdir -p "$WS/src"
for pkg in rosbot_description rosbot_nav2_bringup nav2_client nav2_bt_client; do
  rm -rf "$WS/src/$pkg"
  cp -r "$BOOK/$pkg" "$WS/src/"
done

# 本演練改：nav2.launch.py 寫死啟動 RViz，演練無人看管不開圖形視窗 → 註解掉 rviz action
sed -i 's/^    ld.add_action(rviz_launch_cmd)/    # 本演練改：不啟動 RViz\n    # ld.add_action(rviz_launch_cmd)/' \
  "$WS/src/rosbot_nav2_bringup/launch/nav2.launch.py"
# 本演練改：gazebo.launch.py 改 server 模式（-s -r），不開 Gazebo GUI
sed -i "s/PythonExpression(\[\"'\", world_file, \" -r'\"\])/PythonExpression([\"'\", world_file, \" -s -r'\"])/" \
  "$WS/src/rosbot_description/launch/gazebo.launch.py"
grep -n "rviz_launch_cmd)" "$WS/src/rosbot_nav2_bringup/launch/nav2.launch.py"
grep -n "gz_args" -A1 "$WS/src/rosbot_description/launch/gazebo.launch.py"

cd "$WS"
colcon build --symlink-install --event-handlers console_direct- 2>&1
echo "=== 建置結果 ==="
ls install/nav2_client/lib/nav2_client install/nav2_bt_client/lib/nav2_bt_client
ls install/rosbot_description/share/rosbot_description install/rosbot_nav2_bringup/share/rosbot_nav2_bringup
echo BUILD_DONE
