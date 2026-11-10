#!/bin/bash
# K136《Mastering ROS 2》互動導覽共用函式（外觀與行為照 K135 的 ~/ros2-demo/chNN.sh）
#
# 用法（在 chNN.sh 開頭）：
#   CH=1; TOTAL=5
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"     # 會讀 chNN.sh 的第一個參數當 START
#   cleanup() { pkill -f "[d]emo_nodes" 2>/dev/null; }  # 各章自己定義要殺哪些節點
#   trap cleanup EXIT
#
#   if seg 1 "段落標題"; then
#     note "說明為什麼"
#     run "指令"
#     next
#   fi
#   ...
#   finish "本章重點 1" "本章重點 2" ...
#
# 段落跳轉：bash chNN.sh 3  → 第 1、2 段的 seg 回傳 1（整段 if 跳過），從第 3 段開始。
# 不用 set -e：導覽中某個指令失敗只顯示 exit code，不該讓整個導覽中斷。

source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
# 區網上有其他機器也在用 domain 36，限定只探索本機
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST

C='\033[1;36m'; Y='\033[1;33m'; G='\033[1;32m'; R='\033[1;31m'; N='\033[0m'

# 主控 Claude 讀這個檔就知道練習格目前在哪一段
SEG_FILE=/tmp/k136-seg

START="${1:-1}"
if ! [[ "$START" =~ ^[0-9]+$ ]] || [ "$START" -lt 1 ]; then
  echo -e "${R}錯誤：起始段落必須是正整數，收到「$START」${N}" >&2
  echo "用法：bash $(basename "$0") [起始段落，預設 1]" >&2
  exit 1
fi

CH_TAG="$(printf 'ch%02d' "${CH:?lib.sh 需要先設定 CH}")"

title() {
  clear
  echo -e "${C}════════════════════════════════════════════${N}"
  echo -e "${C} 第 ${CH} 章演練 $1${N}"
  echo -e "${C}════════════════════════════════════════════${N}\n"
}

# 先綠字顯示指令再執行；失敗時補一行紅字 exit code，讓學習者知道不是畫面卡住
run() {
  echo -e "${G}\$ $*${N}"
  eval "$@"
  local rc=$?
  [ "$rc" -ne 0 ] && echo -e "${R}（exit $rc）${N}"
  echo
}

note() { echo -e "${Y}💡 $*${N}"; }

next() { echo; read -rp "👉 按 Enter 繼續…" _; }

# 段落入口：N < START 回傳 1 讓呼叫端跳過整段，否則清畫面顯示標題並記錄進度
seg() {
  local n="$1" label="$2"
  [ "$n" -lt "$START" ] && return 1
  echo "${CH_TAG} 段 ${n}" > "$SEG_FILE" 2>/dev/null
  title "(${n}/${TOTAL:-?}) ${label}"
  return 0
}

# 本章結尾：顯示重點、清理，互動終端機才留一個 shell（K135 的 exec bash 行為）
finish() {
  title "完成 ✅"
  local point
  for point in "$@"; do note "$point"; done
  echo "${CH_TAG} 完成" > "$SEG_FILE" 2>/dev/null
  declare -F cleanup >/dev/null && cleanup
  trap - EXIT
  # stdin 不是終端機（例如 yes "" | bash chNN.sh 測試）就直接結束，避免卡在新 shell
  if [ -t 0 ]; then exec bash; fi
}
