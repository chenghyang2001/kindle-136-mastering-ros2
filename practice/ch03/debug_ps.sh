#!/bin/bash
# 診斷：列出 WSL 內所有 ROS 相關行程與 Fast DDS 共享記憶體檔
ps -eo pid,etime,cmd | grep -E "ros|_daemon|master_ros2|python3" | grep -v grep || true
echo "--- /dev/shm"; ls /dev/shm | head -30; ls /dev/shm | wc -l
