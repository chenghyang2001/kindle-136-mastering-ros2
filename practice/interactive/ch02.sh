#!/bin/bash
# 《Mastering ROS 2》第 2 章互動導覽：書本 Docker 檔、本機安裝、pkg create、colcon build、ros2 run
# 用法：bash ch02.sh [起始段落]
CH=2; TOTAL=8
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# 腳本可能從任何目錄被呼叫，節點原始碼位置要用腳本所在處推算成絕對路徑
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODES="$(cd "$SCRIPT_DIR/../ch02/nodes" 2>/dev/null && pwd)"
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter02/ros2_jazzy_docker
WS=~/k136_ws/ch02

cleanup() { pkill -f "[h]ello_timer" 2>/dev/null; }
trap cleanup EXIT

# 從第 4 段以後直接開始時，工作區可能還沒建，先提醒而不是讓後面一串指令報錯
need_pkgs() {
  if [ ! -d "$WS/src/k136_hello_cpp" ] || [ ! -d "$WS/src/k136_hello_py" ]; then
    echo -e "${R}找不到 $WS/src 下的兩個套件，請先從第 3 段開始：bash $(basename "$0") 3${N}"
    return 1
  fi
}
need_build() {
  if [ ! -f "$WS/install/setup.bash" ]; then
    echo -e "${R}找不到 $WS/install/setup.bash，請先從第 5 段 colcon build：bash $(basename "$0") 5${N}"
    return 1
  fi
  source "$WS/install/setup.bash"
}

if seg 1 "書本的 Docker 檔在做什麼（只摘重點，不建 image）"; then
  note "BOOK=$BOOK"
  note "三個 Dockerfile 都以官方 osrf/ros:jazzy-desktop-full 為底，不必自己裝 ROS："
  run '(cd "$BOOK" && grep -n "^FROM" docker_basics/Dockerfile docker_basics/Dockerfile.basic docker_gui/Dockerfile.master_ros2)'
  note "create_container.sh：掛 X11 socket＋DISPLAY 讓 RViz/Gazebo 顯示；--network host 讓 DDS 與主機互通；有 NVIDIA 才加 --gpus all"
  run 'grep -n -E "X11-unix|DISPLAY|--network|--privileged|--gpus" "$BOOK"/docker_gui/create_container.sh'
  note "ros_entrypoint.sh：容器每次啟動先 source ROS 環境，再執行你給的指令："
  run 'grep -v -E "^(#|$)" "$BOOK"/docker_gui/ros_entrypoint.sh'
  note "docker-compose.yml：兩個容器分別跑 talker／listener，示範多容器互通："
  run 'grep -v "^$" "$BOOK"/docker_compose/docker-compose.yml'
  next
fi

if seg 2 "本機安裝對照：不用 Docker，ROS 2 直接裝在 WSL"; then
  note "書本預設 desktop-full；本機裝的是 ros-jazzy-desktop（沒有模擬器套件）＋ ros-dev-tools（colcon、rosdep）"
  run 'dpkg -l | grep -E "ros2-apt-source|ros-jazzy-desktop |ros-jazzy-ros-base|ros-dev-tools" | cut -c1-80'
  note "apt 來源由 ros2-apt-source 套件自動設定（新式 .sources 檔）："
  run 'ls /etc/apt/sources.list.d/ | grep -i ros'
  note "WSL 裡可能找得到 Docker Desktop 的 docker 指令，但本演練不用它："
  run 'command -v docker || echo "（沒有 docker 指令）"'
  next
fi

if seg 3 "ros2 pkg create 建 C++ 與 Python 套件"; then
  note "工作區 WS=$WS；重跑時先刪舊套件，結果才可重現"
  run 'mkdir -p "$WS/src" && cd "$WS/src" && rm -rf k136_hello_cpp k136_hello_py'
  note "--node-name 會順便產生一支節點範本，並自動寫好 CMakeLists／setup.py 的安裝設定："
  run 'ros2 pkg create --build-type ament_cmake --license Apache-2.0 --dependencies rclcpp --node-name hello_timer_cpp k136_hello_cpp | tail -3'
  run 'ros2 pkg create --build-type ament_python --license Apache-2.0 --dependencies rclpy --node-name hello_timer_py k136_hello_py | tail -3'
  note "用練習資料夾寫好的 timer 節點覆蓋範本（NODES=$NODES）："
  run 'cp "$NODES/hello_timer_cpp.cpp" k136_hello_cpp/src/ && cp "$NODES/hello_timer_py.py" k136_hello_py/k136_hello_py/ && echo 已覆蓋兩支節點'
  next
fi

if seg 4 "看產生的檔案結構與自動加的設定"; then
  if need_pkgs; then
    run 'cd "$WS/src" && find . -type f -not -path "*/test/*" | sort'
    note "C++：pkg create 自動加了 add_executable、ament_target_dependencies、install(TARGETS)"
    run 'grep -n -E "add_executable|ament_target_dependencies|install\(TARGETS" -A1 k136_hello_cpp/CMakeLists.txt'
    note "Python：entry_points 的 console_scripts 決定 ros2 run 後面的執行檔名稱"
    run 'grep -n -A3 "console_scripts" k136_hello_py/setup.py'
  fi
  next
fi

if seg 5 "colcon build --symlink-install"; then
  note "--symlink-install：Python 檔用符號連結裝進 install/，改 .py 不必重 build（C++ 仍要重 build）"
  if need_pkgs; then
    run 'cd "$WS" && colcon build --symlink-install'
  fi
  next
fi

if seg 6 "確認套件與執行檔，各跑 5 秒"; then
  if need_build; then
    note "新 build 的套件要 source 工作區的 install/setup.bash，ros2 才找得到："
    run 'cd "$WS" && source install/setup.bash && colcon list'
    run 'ros2 pkg executables k136_hello_cpp; ros2 pkg executables k136_hello_py'
    note "timeout 5 到時回傳 124，是預期的結束方式："
    run 'timeout 5 ros2 run k136_hello_cpp hello_timer_cpp'
    run 'timeout 5 ros2 run k136_hello_py hello_timer_py'
  fi
  next
fi

if seg 7 "兩個節點同時跑：node list 與 node info"; then
  if need_build; then
    echo -e "${G}\$ timeout 30 ros2 run k136_hello_cpp hello_timer_cpp &${N}"
    timeout 30 ros2 run k136_hello_cpp hello_timer_cpp > /tmp/k136_ch02_cpp.log 2>&1 &
    echo -e "${G}\$ timeout 30 ros2 run k136_hello_py hello_timer_py &${N}"
    timeout 30 ros2 run k136_hello_py hello_timer_py > /tmp/k136_ch02_py.log 2>&1 &
    echo
    note "Python 節點啟動要 3～5 秒，等 8 秒再查："
    sleep 8
    run 'timeout 15 ros2 node list --no-daemon --spin-time 3'
    note "沒寫任何 topic，節點仍自帶 /rosout、/parameter_events 和一組參數服務："
    run 'timeout 15 ros2 node info /hello_timer_cpp --no-daemon --spin-time 3'
    run 'tail -2 /tmp/k136_ch02_cpp.log; tail -2 /tmp/k136_ch02_py.log'
  fi
  next
fi

if seg 8 "清理"; then
  note "停掉本章的 hello_timer 節點（不動 ros2 daemon）："
  run "pkill -f '[h]ello_timer'; sleep 1; pgrep -af '[h]ello_timer' || echo '無殘留的 hello_timer 節點'"
  run 'rm -f /tmp/k136_ch02_*.log'
  next
fi

finish \
  "書本用 osrf/ros:jazzy-desktop-full 容器；GUI 靠 X11＋DISPLAY，DDS 靠 --network host" \
  "本機直接在 WSL 裝 ros-jazzy-desktop＋ros-dev-tools，不用 Docker" \
  "ros2 pkg create --node-name 會自動寫好 CMakeLists／setup.py 的安裝設定" \
  "colcon build --symlink-install 後要 source install/setup.bash" \
  "ros2 pkg executables 確認執行檔；節點預設就有 /rosout 與參數服務"
