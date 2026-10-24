#!/bin/bash
# 第 0b 步：看 requirements、openai.env 的欄位（值遮蔽）、turtlesim launch
set -eo pipefail
B=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter14
cat "$B/docker_llm/requirements.txt"
echo "=== openai.env（只顯示欄位名稱）==="
sed 's/=.*/=<遮蔽>/' "$B/ros2_basic_agent/config/openai.env"
echo "=== start_turtlesim_agent.py ==="
cat "$B/ros2_basic_agent/launch/start_turtlesim_agent.py"
