#!/bin/bash
# 複製 Chapter06 兩個套件到 WSL 工作區，改成無畫面版本後 colcon build（書本 repo 原檔不動）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter06
WS=~/k136_ws/ch06
mkdir -p "$WS/src"
for p in two_joints_robot sine_ctrl; do rm -rf "$WS/src/$p"; cp -r "$BOOK/$p" "$WS/src/"; done

F="$WS/src/two_joints_robot/launch/start_simu.launch.py"
# 本演練改：Gazebo 改 server 模式（加 -s），不開 GUI
sed -i "s/' -r -v 4 empty.sdf'/' -s -r -v 4 empty.sdf'/" "$F"
# 本演練改：ros2 control load_controller 會經過本機卡死的 daemon，改用 spawner
sed -i "s/cmd=\['ros2', 'control', 'load_controller', '--set-state', 'active',/cmd=['ros2', 'run', 'controller_manager', 'spawner',/" "$F"
sed -i "s/cmd=\['ros2', 'control', 'load_controller', '--set-state', 'inactive',/cmd=['ros2', 'run', 'controller_manager', 'spawner', '--inactive',/" "$F"
echo "--- 修改後 launch 關鍵行 ---"; grep -n -E "gz_args|spawner|velocity_control'|sine_controller'|position_control'|joint_state_broadcaster'" "$F"

# 本演練改：Jazzy 的 LoanedCommandInterface::set_value 是樣板，傳 float 會在執行期丟
# "Invalid data type : 'float' ... expected : 'double'"，控制器被強制停用；改成轉 double
C="$WS/src/sine_ctrl/src/sine_controller.cpp"
sed -i 's|command_interfaces_\[i\].set_value(desired_joint_positions_\[i\]);|(void)command_interfaces_[i].set_value(static_cast<double>(desired_joint_positions_[i]));  // 本演練改|' "$C"
# 本演練改（診斷用）：on_activate 印出讀到的初始位置與介面數量
sed -i 's|RCLCPP_INFO(get_node()->get_logger(), "Activation successful");|RCLCPP_INFO(get_node()->get_logger(), "Activation successful"); RCLCPP_INFO(get_node()->get_logger(), "[k136] init0=%f init1=%f n0=%zu n1=%zu", initial_joint_position_[0], initial_joint_position_[1], joint_state_interfaces_[0].size(), joint_state_interfaces_[1].size());  /* 本演練改 */|' "$C"
grep -n "本演練改" "$C"

echo "--- 依賴檢查 ---"
dpkg -l | grep -E "ros-jazzy-(ros-gz-sim|gz-ros2-control|ros2-controllers|forward-command-controller|joint-state-broadcaster|xacro|controller-manager) " | awk '{print $2}'

cd "$WS"
colcon build --symlink-install 2>&1 | tail -30
source install/setup.bash
echo "--- plugin 註冊檢查 ---"
ros2 pkg prefix sine_ctrl
cat install/sine_ctrl/share/ament_index/resource_index/controller_interface__pluginlib__plugin/sine_ctrl
ls install/sine_ctrl/lib/
