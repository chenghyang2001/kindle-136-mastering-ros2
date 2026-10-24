# K136 第 2 章：開始寫 ROS 2 程式 — 快速演練筆記

> 快速 demo 模式：只求看懂流程，未經 QA／審查。環境：Windows 11 + WSL Ubuntu-24.04 + ROS 2 Jazzy。
> WSL 工作區：`~/k136_ws/ch02`。書本 repo（WSL）：`~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter02`（原檔未動）。

## 做了什麼

| 腳本 | 內容 | 紀錄 |
| --- | --- | --- |
| `step0_read_docker.sh` | 讀 `ros2_jazzy_docker/` 下的 Dockerfile／腳本／compose 檔，並列出本機 ROS 安裝套件 | `logs/step0_read_docker.log` |
| `step1_create_build.sh` | `ros2 pkg create` 建 `k136_hello_cpp`（ament_cmake）與 `k136_hello_py`（ament_python），用 `nodes/` 裡的節點覆蓋範本，`colcon build --symlink-install` | `logs/step1_create_build.log` |
| `step2_run_verify.sh` | `colcon list`、`ros2 pkg executables`、`ros2 run` 各跑 5 秒（timeout）、兩節點同時跑時 `node list --no-daemon`／`node info` | `logs/step2_run_verify.log` |
| `cleanup.sh` | 停殘留行程 + `timeout 15 ros2 daemon stop`，最後確認無殘留 | `logs/cleanup.log` |

節點原始碼：`nodes/hello_timer_cpp.cpp`、`nodes/hello_timer_py.py`（都是每 1 秒用 timer 印一行 log）。

## `ros2_install_jazzy.sh` 做了哪些步驟

1. 檢查 Ubuntu 版本，不是 `noble`（24.04）就結束。
2. 設 locale 為 `en_US.UTF-8`；裝 `software-properties-common`，啟用 `universe` 套件庫。
3. 刪掉舊式的 `/etc/apt/sources.list.d/ros2.list` 與 `ros-archive-keyring.gpg`（若存在）。
4. 用 GitHub API 查 `ros-infrastructure/ros-apt-source` 最新版本，下載並安裝 `ros2-apt-source_<版本>.noble_all.deb`（自動設定 apt 來源與金鑰）。
5. `apt update` + `apt -y upgrade`（整台系統升級）。
6. `read -p` 互動詢問：1 = `ros-jazzy-desktop-full`（預設），2 = `ros-jazzy-ros-base`；再裝 `ros-dev-tools`（colcon、rosdep 等）。
7. 把 `source /opt/ros/jazzy/setup.bash` 附加到 `~/.bashrc`，最後印 `ROS_DISTRO` 驗證。

（另有 `ros2_uninstall_jazzy.sh` 做反向移除，本演練未執行。）

### 和本機實際安裝的差異

| 項目 | 書本腳本 | 本機（dpkg 實測） |
| --- | --- | --- |
| apt 來源 | `ros2-apt-source`（最新版 deb） | 同樣用 `ros2-apt-source 1.3.0~noble`，來源檔是 `/etc/apt/sources.list.d/ros2.sources` |
| 安裝套件 | 預設 `ros-jazzy-desktop-full`（含 Gazebo 等模擬器） | `ros-jazzy-desktop`（0.11.0，**沒有** desktop-full 的模擬器套件），加 `ros-dev-tools 1.0.3` |
| 互動 | `read -p` 等使用者輸入，無人值守會卡住 | 直接 `apt install`，不互動 |
| 系統升級 | 會跑 `apt -y upgrade` | 未整台升級 |
| `.bashrc` | 每跑一次就附加一行（重跑會重複） | 本演練腳本各自 `source /opt/ros/jazzy/setup.bash`，不依賴 `.bashrc` |

## `ros2_jazzy_docker` 用途（只讀，未建 image）

- `docker_basics/Dockerfile`：以 `osrf/ros:jazzy-desktop-full` 為底，升級套件並裝 `python3-pip`，啟動進 bash — 最簡單的「現成 ROS 2 環境」。
- `docker_basics/Dockerfile.basic`：同上，再建一個非 root 使用者 `robot`（UID/GID 1000、免密碼 sudo），避免在容器裡用 root 建檔。
- `docker_gui/Dockerfile.master_ros2` + `build_image.sh`／`create_container.sh`：可傳入使用者名稱與工作區名稱建 image；容器用 `--network host`、掛 X11 socket／Xauth 讓 RViz、Gazebo 等 GUI 可顯示，偵測到 NVIDIA GPU 時加 `--gpus all`，並把主機的 `~/<ws>/src` 掛進容器，主機改碼、容器內建置。
- `docker_compose/docker-compose.yml`：兩個服務分別跑 `demo_nodes_cpp` 的 talker／listener，示範多容器互通。
- 本機差異：照要求不使用 Docker、不建 image（WSL 內雖找得到 Docker Desktop 的 `docker` 指令，但未使用）；ROS 2 直接裝在 WSL。

## 驗證結果

`ros2 pkg create` 加 `--node-name` 時，會自動在 `CMakeLists.txt` 加 `add_executable`／`ament_target_dependencies`／`install(TARGETS ...)`，在 `setup.py` 加 `console_scripts` entry point，所以只需替換節點原始碼。

```
Finished <<< k136_hello_py [2.35s]
Finished <<< k136_hello_cpp [9.84s]
Summary: 2 packages finished [10.1s]
```

```
$ colcon list
k136_hello_cpp src/k136_hello_cpp (ros.ament_cmake)
k136_hello_py src/k136_hello_py (ros.ament_python)
$ ros2 pkg executables k136_hello_cpp ; ros2 pkg executables k136_hello_py
k136_hello_cpp hello_timer_cpp
k136_hello_py hello_timer_py
```

```
$ timeout 5 ros2 run k136_hello_cpp hello_timer_cpp
[INFO] [...] [hello_timer_cpp]: C++ 節點 tick 1
...
[INFO] [...] [hello_timer_cpp]: C++ 節點 tick 4
[INFO] [...] [rclcpp]: signal_handler(SIGINT/SIGTERM)
$ timeout 5 ros2 run k136_hello_py hello_timer_py
[INFO] [...] [hello_timer_py]: Python 節點 tick 1
...
[INFO] [...] [hello_timer_py]: Python 節點 tick 4
```

兩個節點同時跑時，`ros2 node list --no-daemon` 列出 `/hello_timer_py`、`/hello_timer_cpp`；`node info /hello_timer_cpp` 顯示預設的 `/rosout`、`/parameter_events` 與 7 個參數服務。清理後無殘留行程。

## 和書上做法的差異

- 書本用安裝腳本或 Docker 準備環境；本機已用 `ros2-apt-source` 裝好 `ros-jazzy-desktop`，未重跑安裝腳本、未用 Docker。
- 節點是本演練自寫的最小 timer 節點（套件名 `k136_hello_cpp`／`k136_hello_py`），不是書上範例套件。
- 所有指令透過 Windows 的 Claude Code 呼叫 `wsl.exe` 執行 `.sh`；節點一律用 `timeout` 包住；ros2 查詢加 `--no-daemon`；加了 `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` 避開區網上同 domain 的其他機器。
- Python 節點捕捉 `KeyboardInterrupt`／`ExternalShutdownException` 並用 `rclpy.try_shutdown()`，timeout 結束時不印 traceback。
