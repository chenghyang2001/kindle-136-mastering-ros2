#!/bin/bash
# 診斷 3：LOCALHOST 探索在 lo 上需要 multicast；檢查並（暫時）打開
ip link show lo
if ! ip link show lo | grep -q MULTICAST; then
  echo "lo 沒有 MULTICAST，暫時開啟（WSL 重啟後失效）"
  sudo ip link set lo multicast on
  ip link show lo
fi
