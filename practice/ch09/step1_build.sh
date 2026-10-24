#!/bin/bash
# 步驟 1：複製 Chapter09 三個套件到 ~/k136_ws/ch09/src 並建置（書本原檔不動）
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# panda_arm.xacro 會 include realsense2_description 的 D435 模型
if ! dpkg -s ros-jazzy-realsense2-description >/dev/null 2>&1; then
  sudo apt-get install -y ros-jazzy-realsense2-description
fi

BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter09
WS=~/k136_ws/ch09
mkdir -p "$WS/src"
for pkg in panda_description panda_moveit_config panda_moveit_control; do
  rm -rf "$WS/src/$pkg"
  cp -r "$BOOK/$pkg" "$WS/src/"
done

# 本演練改：三支規劃 launch 寫死 use_sim_time=True（給 Gazebo 用），
# mock 硬體沒有 /clock，改成 False 才能用 wall time 跟 move_group 對時
sed -i 's/{"use_sim_time": True},/{"use_sim_time": False},  # 本演練改：mock 硬體無 \/clock/' \
  "$WS"/src/panda_moveit_control/launch/*.launch.py
grep -n use_sim_time "$WS"/src/panda_moveit_control/launch/*.launch.py

# 本演練改：panda_arm.xacro 無條件寫入 Gazebo 專用的 ros2_control 區塊（2DofPosition／GazeboSimSystem），
# mock 版 move_group 環境載不到這個外掛 → 整組硬體初始化失敗、沒有 /joint_states。
# 用 xacro 參數 gz_control 包起來：panda_description 預設 true（Gazebo 版行為不變），
# panda_moveit_config 的 URDF 在 include 前先宣告 false（xacro:arg 先宣告者優先）
ARM="$WS/src/panda_description/urdf/panda_arm.xacro"
perl -0pi -e 's#(\s*<ros2_control name="2DofPosition".*?</ros2_control>)#\n   <!-- 本演練改：Gazebo 專用硬體介面，mock 版關掉 -->\n   <xacro:if value="\$(arg gz_control)">$1\n   </xacro:if>#s' "$ARM"
perl -0pi -e 's#(<xacro:arg name="ros2_control" default="true"/>)#$1\n  <!-- 本演練改：是否輸出 Gazebo 專用 ros2_control 區塊 -->\n  <xacro:arg name="gz_control" default="true"/>#' \
  "$WS/src/panda_description/urdf/panda.urdf.xacro"
perl -0pi -e 's#(<xacro:arg name="initial_positions_file"[^\n]*\n)#$1    <!-- 本演練改：mock 硬體版不要 Gazebo 的 ros2_control 區塊 -->\n    <xacro:arg name="gz_control" default="false" />\n#' \
  "$WS/src/panda_moveit_config/config/panda.urdf.xacro"
# 本演練改：mock 初始姿態全 0，但 Panda joint4 合法範圍約 [-3.07, -0.07]，
# move_group 的 CheckStartStateBounds 會拒絕規劃（run1 實測）→ 改成和 Gazebo 版相同的 ready 姿態
printf '%s\n' '# 本演練改：原本全 0（joint4=0 超出關節限制），改成和 Gazebo 版 2DofPosition 相同的 ready 姿態' \
  'initial_positions:' '  joint1: 0.0' '  joint2: -0.78' '  joint3: 0.0' '  joint4: -2.35' \
  '  joint5: 0.0' '  joint6: 1.57' '  joint7: 0.78' > "$WS/src/panda_moveit_config/config/initial_positions.yaml"
grep -n "gz_control" "$ARM" "$WS/src/panda_description/urdf/panda.urdf.xacro" "$WS/src/panda_moveit_config/config/panda.urdf.xacro"

cd "$WS"
colcon build --symlink-install --event-handlers console_direct- 2>&1
echo "=== 建置結果 ==="
ls install/panda_moveit_control/lib/panda_moveit_control
source install/setup.bash
echo "=== xacro 展開測試（moveit_config 版 URDF，含 mock ros2_control）==="
xacro "$WS/src/panda_moveit_config/config/panda.urdf.xacro" > /tmp/k136_ch09_panda.urdf
grep -c "<link " /tmp/k136_ch09_panda.urdf
grep -n "mock_components\|gz_ros2_control" /tmp/k136_ch09_panda.urdf
echo "=== xacro 展開測試（panda_description 原版 URDF，Gazebo 用）==="
xacro "$WS/src/panda_description/urdf/panda.urdf.xacro" | grep -n "<plugin>" || true
echo BUILD_DONE
