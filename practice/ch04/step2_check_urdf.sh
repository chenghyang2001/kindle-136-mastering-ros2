#!/bin/bash
# check_urdf 檢查 simple_rrbot.urdf；xacro 轉 URDF 再檢查；urdf_to_graphviz 產生 link 樹 PDF→PNG
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter04
WS=~/k136_ws/ch04
source "$WS/install/setup.bash"
OUT="$PWD/urdf_out"   # 練習資料夾（Windows 端可見）
mkdir -p "$OUT"
GEN=$WS/generated
mkdir -p "$GEN"

echo "===== 1. check_urdf simple_rrbot.urdf ====="
cp "$BOOK/simple_rrbot.urdf" "$GEN/simple_rrbot.urdf"
check_urdf "$GEN/simple_rrbot.urdf"

echo "===== 2. xacro → URDF：rrbot ====="
xacro "$(ros2 pkg prefix rrbot_description)/share/rrbot_description/urdf/rrbot.urdf.xacro" > "$GEN/rrbot.urdf"
check_urdf "$GEN/rrbot.urdf"

echo "===== 2b. xacro 參數 prefix:=left_ 測試 macro 重用 ====="
xacro "$(ros2 pkg prefix rrbot_description)/share/rrbot_description/urdf/rrbot.urdf.xacro" prefix:=left_ > "$GEN/rrbot_left.urdf"
check_urdf "$GEN/rrbot_left.urdf" | head -8

echo "===== 3. xacro → URDF：rosbot ====="
xacro "$(ros2 pkg prefix rosbot_description)/share/rosbot_description/urdf/rosbot.xacro" > "$GEN/rosbot.urdf"
check_urdf "$GEN/rosbot.urdf"

echo "===== 4. urdf_to_graphviz ====="
cd "$GEN"
for r in simple_rrbot rrbot rosbot; do
  urdf_to_graphviz "$r.urdf" "$r" 2>&1 | tail -2
  ls -la "$r.gv" "$r.pdf"
  pdftoppm -png -r 80 -singlefile "$r.pdf" "$OUT/${r}_tree"
  cp "$r.urdf" "$r.gv" "$OUT/"
done
ls -la "$OUT"
