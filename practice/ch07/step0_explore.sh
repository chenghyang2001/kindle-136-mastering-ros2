#!/bin/bash
# 步驟 0：讀書本 Chapter07 原始碼、確認 BehaviorTree.CPP 套件
set -eo pipefail
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter07
cd "$BOOK"
for f in $(find first_bts bt_action_server -type f | sort); do
  echo "=================== $f"
  cat "$f"
done
echo "=================== 套件檢查"
dpkg -l | grep -E "behaviortree|ros-jazzy-btcpp|groot" || echo "(未安裝 behaviortree 套件)"
