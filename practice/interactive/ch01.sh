#!/bin/bash
# 《Mastering ROS 2》第 1 章互動導覽：環境、跨語言 talker/listener、內省指令、ROS_DOMAIN_ID 隔離
# 用法：bash ch01.sh [起始段落]
CH=1; TOTAL=5
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOG_TALKER=/tmp/k136_ch01_talker.log
LOG_LISTENER=/tmp/k136_ch01_listener.log

cleanup() { pkill -f "[d]emo_nodes" 2>/dev/null; }
trap cleanup EXIT

# 第 3 段要有 /chatter 才看得到 QoS；從第 3 段直接開始時要先補啟動
start_chatter() {
  pgrep -f "[d]emo_nodes_cpp/talker" >/dev/null || \
    ros2 run demo_nodes_cpp talker > "$LOG_TALKER" 2>&1 &
  pgrep -f "[d]emo_nodes_py/listener" >/dev/null || \
    ros2 run demo_nodes_py listener > "$LOG_LISTENER" 2>&1 &
}

if seg 1 "ROS_DISTRO 與 RMW 中介軟體"; then
  note "source /opt/ros/jazzy/setup.bash 之後，環境變數告訴你現在用哪一版 ROS 2："
  run "printenv | grep -E '^ROS_' | sort"
  note "RMW 是 ROS 2 和 DDS 之間的轉接層；沒設定 RMW_IMPLEMENTATION 時 Jazzy 預設用 Fast DDS。"
  run "echo \"RMW_IMPLEMENTATION=\${RMW_IMPLEMENTATION:-<未設定，用預設 Fast DDS>}\""
  note "本機裝了哪些 RMW 實作（書上用 ros2 doctor，但它在 WSL 會卡住，改看套件清單）："
  run "ros2 pkg list | grep -E '^rmw_(fastrtps|cyclonedds|connextdds|zenoh)'"
  next
fi

if seg 2 "C++ talker ＋ Python listener，不需要中央主機"; then
  note "ROS 1 要先開 roscore；ROS 2 靠 DDS 自動探索，兩個節點直接找到彼此。"
  echo -e "${G}\$ ros2 run demo_nodes_cpp talker > $LOG_TALKER &    # C++${N}"
  ros2 run demo_nodes_cpp talker > "$LOG_TALKER" 2>&1 &
  echo -e "${G}\$ ros2 run demo_nodes_py listener > $LOG_LISTENER &  # Python${N}"
  ros2 run demo_nodes_py listener > "$LOG_LISTENER" 2>&1 &
  echo
  note "Python 節點啟動比較慢，等 6 秒再查（--no-daemon：WSL 上 ros2 daemon 常卡住，直接探索；--spin-time 3：多等 3 秒探索，預設 0.5 秒常漏掉 listener）"
  sleep 6
  run "timeout 15 ros2 node list --no-daemon --spin-time 3"
  note "-t 會同時顯示每個 topic 的訊息型別："
  run "timeout 15 ros2 topic list -t --no-daemon --spin-time 3"
  next
fi

if seg 3 "看 /chatter 的 QoS 與訊息型別"; then
  start_chatter
  note "-v 列出每個發布者／訂閱者的 QoS；兩邊 QoS 相容才連得上（Reliability、Durability…）"
  run "timeout 15 ros2 topic info /chatter -v --no-daemon --spin-time 3"
  note "std_msgs/msg/String 只有一個 string data 欄位，C++ 和 Python 用同一份定義："
  run "ros2 interface show std_msgs/msg/String"
  note "Python listener 確實收到 C++ talker 發的訊息："
  run "tail -5 $LOG_LISTENER"
  next
fi

if seg 4 "ROS_DOMAIN_ID 隔離"; then
  note "先停掉上一段的節點，避免干擾計數："
  run "pkill -f '[d]emo_nodes'; sleep 1"
  note "talker 在 domain 36；兩個 listener 分別在 36 和 37。domain 不同，DDS 封包互相看不到。"
  echo -e "${G}\$ ROS_DOMAIN_ID=36 timeout 30 ros2 run demo_nodes_cpp talker &${N}"
  ROS_DOMAIN_ID=36 timeout 30 ros2 run demo_nodes_cpp talker > /tmp/k136_ch01_d36_talker.log 2>&1 &
  echo -e "${G}\$ ROS_DOMAIN_ID=37 timeout 15 ros2 run demo_nodes_py listener &${N}"
  ROS_DOMAIN_ID=37 timeout 15 ros2 run demo_nodes_py listener > /tmp/k136_ch01_d37.log 2>&1 &
  L37_PID=$!
  echo -e "${G}\$ ROS_DOMAIN_ID=36 timeout 15 ros2 run demo_nodes_py listener &${N}"
  ROS_DOMAIN_ID=36 timeout 15 ros2 run demo_nodes_py listener > /tmp/k136_ch01_d36.log 2>&1 &
  L36_PID=$!
  echo
  note "等 8 秒讓節點啟動並互相探索…"
  sleep 8
  run "ROS_DOMAIN_ID=36 timeout 15 ros2 node list --no-daemon --spin-time 3"
  note "domain 37 看不到 talker（自己那個 listener 有時要晚幾秒才被探索到，空白也正常）："
  run "ROS_DOMAIN_ID=37 timeout 15 ros2 node list --no-daemon --spin-time 3"
  note "等兩個 listener 的 15 秒 timeout 結束，數各收到幾則："
  wait "$L36_PID" "$L37_PID" 2>/dev/null
  run "echo \"domain 36 收到 \$(grep -c 'I heard' /tmp/k136_ch01_d36.log) 則；domain 37 收到 \$(grep -c 'I heard' /tmp/k136_ch01_d37.log) 則\""
  next
fi

if seg 5 "清理"; then
  note "停掉本章啟動的 demo 節點（[d] 寫法讓 pkill 不會比對到自己這行指令）："
  run "pkill -f '[d]emo_nodes'; sleep 1; pgrep -af '[d]emo_nodes' || echo '無殘留的 demo_nodes 節點'"
  run "rm -f /tmp/k136_ch01_*.log"
  next
fi

finish \
  "ROS_DISTRO=jazzy；RMW 是 ROS 2 與 DDS 之間的轉接層，預設 Fast DDS" \
  "沒有中央主機：C++ 與 Python 節點靠 DDS 探索直接互通" \
  "內省三寶：node list、topic list -t、topic info -v（看 QoS）" \
  "interface show 看訊息定義，跨語言共用同一份 .msg" \
  "ROS_DOMAIN_ID 不同就互相看不到；本演練固定 36 並限定 LOCALHOST"
