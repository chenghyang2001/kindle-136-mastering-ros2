#!/bin/bash
# 第 2 步：複製 ros2_basic_agent 到 ~/k136_ws/ch14/src，套用假 LLM 修改，colcon build
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on

HERE=$(pwd)
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter14
WS=~/k136_ws/ch14
PKG=$WS/src/ros2_basic_agent
mkdir -p "$WS/src"
rm -rf "$PKG"
cp -r "$BOOK/ros2_basic_agent" "$WS/src/"

# 本演練改：加假 LLM、改 agent、換成不含金鑰的 openai.env 範本
cp "$HERE/src_patch/fake_llm.py" "$PKG/ros2_basic_agent/fake_llm.py"
python3 "$HERE/src_patch/patch_agent.py" "$PKG/ros2_basic_agent/ros2_ai_agent_turtlesim.py"
cp "$HERE/config/openai.env" "$PKG/config/openai.env"
grep -n "本演練改" -A8 "$PKG/ros2_basic_agent/ros2_ai_agent_turtlesim.py" | head -12

echo "=== 假 LLM 冒煙測試（venv python）==="
PYTHONPATH="$PKG:$PYTHONPATH" ~/k136_venv/bin/python "$PKG/ros2_basic_agent/fake_llm.py" || echo "（langchain 尚未裝好，自測略過）"

cd "$WS"
colcon build --symlink-install --packages-select ros2_basic_agent --event-handlers console_direct+ 2>&1
echo "BUILD_DONE"
ls install/ros2_basic_agent/lib/ros2_basic_agent/
