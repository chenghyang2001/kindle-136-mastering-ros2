#!/bin/bash
# 診斷：逐一測試 ros2 CLI 指令是否會卡住（每個限 10 秒）
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
t() { echo "--- $* ---"; timeout 10 "$@"; echo "exit=$?"; }
t ros2 pkg list -h >/dev/null
t ros2 daemon status
t ros2 node list --no-daemon
t ros2 topic list --no-daemon
ip -br addr
