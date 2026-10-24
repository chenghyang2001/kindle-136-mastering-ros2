#!/bin/bash
# 列出 ch07 相關殘留行程（只看不殺）
ps -eo pid,ppid,etime,cmd | grep -E "number_checker|sequence_tree|bt_action|reach_location|ros2" | grep -v grep || echo "無殘留"
