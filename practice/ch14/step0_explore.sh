#!/bin/bash
# 第 0 步：看 Chapter14 有什麼、agent 程式長怎樣、venv 狀態
set -eo pipefail
B=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter14
ls -R "$B" | head -60
echo "=== package files ==="
P="$B/ros2_basic_agent"
cat "$P/setup.py" 2>/dev/null || true
cat "$P/package.xml" 2>/dev/null || true
find "$P" -name "*.py" -o -name "*.txt" -o -name "*.env" -o -name "*.launch*" | head -30
echo "=== turtlesim agent ==="
f=$(find "$P" -name "ros2_ai_agent_turtlesim*.py" | head -1)
echo "FILE=$f"
cat "$f"
echo "=== venv ==="
ls ~/k136_venv/bin/python 2>/dev/null && ~/k136_venv/bin/pip list 2>/dev/null | grep -i -E "langchain|openai|dotenv" || echo "no venv / no langchain"
python3 --version
