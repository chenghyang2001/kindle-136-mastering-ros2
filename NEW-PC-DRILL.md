# 在另一台電腦重跑 K136 快速演練

2026-10-25 整理。第一次演練在 hp2（DESKTOP-6LST1BR）跑完，16 章都成功；這份說明換到另一台 Windows 電腦時，怎麼取得程式碼、怎麼用 Claude Code CLI 做雙視窗互動演練。

## 1. 程式碼都在哪裡（全部在你的 GitHub）

| 內容 | 位置 |
| --- | --- |
| 書本官方範例（Packt 原版，已 fork） | <https://github.com/chenghyang2001/Mastering-ROS-2-for-Robotics-Programming> |
| 演練教材：課表、教練提示詞、進度表 | <https://github.com/chenghyang2001/kindle-136-mastering-ros2> 的 `teaching/` |
| 每章練習結果：腳本 `.sh`、`NOTES.md`、執行 log | 同上 `practice/chNN/` |
| 每章改過的 ROS 套件副本（例如關掉 GUI 的 launch 檔） | 同上 `practice/chNN/ws_src/` |
| 第 11 章另外要抓的 px4_msgs（太大沒放進 repo） | `git clone -b release/1.15 https://github.com/PX4/px4_msgs.git` |

已上線的成果（不用重做也能看）：完整錄影 <https://youtu.be/ks0i1ZNnw8s>、精華版 <https://youtu.be/GASd9vHkP-c>、
演練語音 <http://187.127.109.145/kindle-136-drill-player.html>、提示詞 <http://187.127.109.145/kindle-prompts.html?n=136>。

## 2. 新電腦要先準備的東西

| 項目 | 需求 | 備註 |
| --- | --- | --- |
| 作業系統 | Windows 11（WSL 2.x、WSLg） | BIOS 要開虛擬化 |
| 記憶體／磁碟 | 建議 32 GB／空出 30 GB | WSL 分 16 GB；ROS 套件約 6 GB |
| 螢幕 | 兩個最好（螢幕 2 放教練＋練習） | 單螢幕也能跑，錄影改錄主螢幕 |
| Claude Code CLI | 已登入；`~/.claude` 已同步（要有 kindle-drill skill 與 `~/.claude/scripts/drill-*.ps1`） | 換機先 `cd ~/.claude && git pull` |
| 工具 | git、gh（已登入 chenghyang2001）、ffmpeg、Windows Terminal | `winget install Git.Git GitHub.cli Gyan.FFmpeg` |
| Python | 真的 Python，不是 Store 假捷徑 | Git Bash 打 `python --version` 要有版本號 |

## 3. 兩種跑法

### A. 雙視窗互動演練（Claude Code CLI，推薦）

在新電腦開 Windows Terminal（Git Bash），`cd ~/workspace` 後啟動 `claude`，把第 5 節的提示詞整段貼進去。
Claude 會自己裝 WSL＋ROS 2、clone repo、開「K136 教練」（螢幕 2 左半）與「K136 練習-chNN」（右半）兩個視窗，教練一章一章把提示詞送給練習視窗，全程錄影。
這次有 hp2 的結果當參考答案，預估 2～3 小時跑完 16 章（第一次在 hp2 實際約 3 小時，不含睡眠）。

### B. 不用 Claude，自己照腳本跑

裝好 WSL＋ROS 2（第 4 節）後，在 Ubuntu 裡：

```bash
cd /mnt/c/Users/<你的 Windows 帳號>/workspace/kindle-136-mastering-ros2/practice/ch03
mkdir -p ~/k136_ws/ch03/src && cp -r ws_src/* ~/k136_ws/ch03/src/
ls step*.sh        # 依 step0、step1… 順序執行，最後跑 cleanup.sh；debug_*.sh 是當時除錯用，可略過
bash step1_build.sh
```

每章做了什麼、預期輸出，看該章的 `NOTES.md`。

## 4. 安裝 WSL2 + ROS 2 Jazzy（手動版，提示詞會叫 Claude 代做）

```powershell
wsl --install -d Ubuntu-24.04          # 系統管理員 PowerShell；裝完設定使用者帳號
```

`%USERPROFILE%\.wslconfig`：

```ini
[wsl2]
memory=16GB
processors=8
networkingMode=mirrored
```

Ubuntu 裡：

```bash
sudo apt update && sudo apt install -y software-properties-common curl
sudo add-apt-repository -y universe
ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F tag_name | awk -F\" '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb"
sudo dpkg -i /tmp/ros2-apt-source.deb && sudo apt update
sudo apt install -y ros-jazzy-desktop ros-dev-tools python3-rosdep \
  ros-jazzy-ros-gz ros-jazzy-gz-ros2-control ros-jazzy-ros2-control ros-jazzy-ros2-controllers \
  ros-jazzy-xacro ros-jazzy-joint-state-publisher-gui ros-jazzy-navigation2 ros-jazzy-nav2-bringup \
  ros-jazzy-moveit ros-jazzy-moveit-py ros-jazzy-behaviortree-cpp ros-jazzy-pcl-ros ros-jazzy-usb-cam \
  ros-jazzy-vision-opencv ros-jazzy-image-tools ros-jazzy-slam-toolbox ros-jazzy-turtlebot3-simulations \
  ros-jazzy-rmw-cyclonedds-cpp graphviz
echo 'source /opt/ros/jazzy/setup.bash' >> ~/.bashrc
mkdir -p ~/ros2_books && git clone https://github.com/chenghyang2001/Mastering-ROS-2-for-Robotics-Programming.git ~/ros2_books/Mastering-ROS-2-for-Robotics-Programming
```

## 5. 新電腦快速演練提示詞（整段貼給 Claude Code CLI）

```text
我要在這台電腦重跑 K136《Mastering ROS 2 for Robotics Programming》第四版的雙視窗快速演練。上次在 hp2 已經跑完 16 章，所有結果都在 GitHub。整個過程不要問我任何問題，選擇一律用你的建議，做完再回報。

一、環境（缺什麼就自己補，裝完要實際跑一次確認）
1. 先讀 https://github.com/chenghyang2001/kindle-136-mastering-ros2 的 NEW-PC-DRILL.md（第 2、4 節）。
2. 檢查 claude、git、gh（帳號 chenghyang2001）、ffmpeg、Windows Terminal、真的 Python（不是 Store 假捷徑）；cd ~/.claude && git pull。
3. 沒有 WSL 的 Ubuntu-24.04 就安裝，.wslconfig 設 memory=16GB、networkingMode=mirrored；Ubuntu 預設使用者設好、sudo 免密碼。
4. 在 Ubuntu 裝 ROS 2 Jazzy desktop 和第 4 節列的全部套件（Gazebo、ros2_control、Nav2、MoveIt 2、BehaviorTree.CPP、PCL、cyclonedds），~/.bashrc source setup.bash；跑 talker／listener 確認互通。
5. clone 兩個 repo：Windows 端 ~/workspace/kindle-136-mastering-ros2；WSL 端 ~/ros2_books/Mastering-ROS-2-for-Robotics-Programming（用 chenghyang2001 的 fork）。

二、開跑前（hp2 踩過的坑，照做）
6. 先用 Start-Process -WindowStyle Hidden 啟動防睡眠程式（kernel32 SetThreadExecutionState 0x80000003，每 30 秒一次，8 小時上限）。hp2 曾在半夜睡眠 8 小時。
7. 不要在螢幕 2 開 Chrome 或其他視窗，會擋住錄影。
8. bash ~/.claude/scripts/drill-preflight.sh 136，❌ 全部補完。

三、演練
9. 用 kindle-drill skill：/kindle-drill start 136（教練左、練習右、看門狗、錄影）。drill.json、DRILL-PROMPT.md、LESSON-PLAN.md 都已在 repo，不用重新 setup。
10. 告訴教練：每章送提示詞時，把 teaching/HANDOFF.md 該章「和書上做法的差異」與 practice/chNN/NOTES.md 的重點一起附上當參考答案；練習視窗可以直接重用 practice/chNN 的 .sh 和 ws_src（複製到 ~/k136_ws/chNN/src），目的是在這台電腦重現同樣結果，不用從零摸索。
11. 已知坑：WSL 的 ros2 daemon 會卡，查詢一律加 --no-daemon；Fast DDS 跨行程探索很慢，改 RMW_IMPLEMENTATION=rmw_cyclonedds_cpp；區網若有別台機器用同一個 domain，加 ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST；圖形視窗一律不開（Gazebo 用 -s 模式），長跑指令都要 timeout。
12. 錄影上限 4 小時，超過就接著錄 part2。

四、收尾
13. /kindle-drill stop；比對全域 settings.json 沒被改。
14. 在 teaching/HANDOFF.md 新增一段「第二台電腦結果（電腦名稱、日期）」，逐章記錄耗時和與 hp2 結果的差異；commit＋push。
15. 錄影 mp4 留在本機，不要上傳 YouTube，等我決定。最後用 5 行以內告訴我結果。
```

## 6. hp2 這次踩過的坑（給 Claude 和自己看）

| 坑 | 解法 |
| --- | --- |
| 筆電半夜睡眠，演練停 8 小時；錄影 mp4 會把睡眠時段算成 9 小時 | 開跑前先開防睡眠程式；上傳前用 log 時間剪掉睡眠段 |
| YouTube Studio 的 Chrome 視窗跑到螢幕 2，擋住教練視窗 | Chrome 一律放主螢幕 |
| `ros2 daemon` 在 WSL 卡死 | 查詢加 `--no-daemon`，`ros2 daemon stop` 包 `timeout 15` |
| Fast DDS 跨行程探索極慢 | 改 `rmw_cyclonedds_cpp` |
| Git Bash 的 `python` 是 Store 假捷徑 | 把 `%LOCALAPPDATA%\Python\pythoncore-3.14-64` 加到使用者 PATH 最前面 |
| `rosdep update` 抓 raw.githubusercontent 偶爾失敗 | 重跑一次就好 |
| 第 13 章書本測試期望值寫錯 | 見 `practice/ch13/NOTES.md` |
| 第 12 章 rf2o 估出的 x 方向相反（未解） | 見 `practice/ch12/NOTES.md` |
