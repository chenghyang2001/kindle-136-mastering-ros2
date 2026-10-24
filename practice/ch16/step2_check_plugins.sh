#!/bin/bash
# 步驟 2：不開 RViz／rqt，改用 ament index + plugin XML + .so 符號確認 pluginlib 匯出成功
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
cd ~/k136_ws/ch16
source install/setup.bash

for p in circle_msgs circle_display_plugin cmd_vel cmd_vel_plugin; do
  echo "ros2 pkg prefix $p -> $(ros2 pkg prefix $p)"
done

echo; echo "=== circle_msgs 介面 ==="
ros2 interface show circle_msgs/msg/Circle

echo; echo "=== RViz display plugin：rviz_common 的 pluginlib 索引 ==="
IDX=install/circle_display_plugin/share/ament_index/resource_index/rviz_common__pluginlib__plugin/circle_display_plugin
echo "索引檔: $IDX"; cat "$IDX"; echo
XML="$(ros2 pkg prefix circle_display_plugin)/$(cat "$IDX")"
echo "--- $XML ---"; cat "$XML"; echo
echo "--- .so 內的類別符號 ---"
nm -C -D install/circle_display_plugin/lib/libcircle_display.so | grep -E "CircleDisplay::(onInitialize|processMessage)" | head -5
nm -C -D install/circle_display_plugin/lib/libcircle_display.so | grep -c class_loader && echo "(含 class_loader 註冊符號)"

echo; echo "=== rqt panel plugin（cmd_vel）：rqt_gui 的 pluginlib 索引 ==="
IDX2=install/cmd_vel/share/ament_index/resource_index/rqt_gui__pluginlib__plugin/cmd_vel
echo "索引檔: $IDX2"; cat "$IDX2"; echo
cat "$(ros2 pkg prefix cmd_vel)/$(cat "$IDX2")"; echo
nm -C -D install/cmd_vel/lib/cmd_vel/libcmd_vel.so | grep -E "cmd_vel::CmdVel::(initPlugin|shutdownPlugin)" | head -5

echo; echo "=== 用 ament_index_python 列出所有 rviz_common / rqt_gui 外掛，確認本章類別在清單內 ==="
python3 -c '
from ament_index_python.packages import get_resources
for base in ("rviz_common", "rqt_gui"):
    res = get_resources(base + "__pluginlib__plugin")
    print(f"[{base}] 共 {len(res)} 個套件匯出外掛")
    for pkg in ("circle_display_plugin", "cmd_vel"):
        if pkg in res:
            print(f"[{base}] {pkg} 已註冊，prefix={res[pkg]}")
'

echo; echo "=== Gazebo 系統外掛 .so（不走 pluginlib，走 GZ_SIM_SYSTEM_PLUGIN_PATH）==="
ls -l build/cmd_vel_plugin/libCmdVelPlugin.so
nm -C -D build/cmd_vel_plugin/libCmdVelPlugin.so | grep -i -E "GzPlugin|IgnitionPlugin|PluginInfo" | head -5
