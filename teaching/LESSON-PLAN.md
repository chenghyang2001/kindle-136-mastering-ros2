# K136 快速演練課表

書：《Mastering ROS 2 for Robotics Programming》第四版（Lentin Joseph、Jonathan Cacace，Packt，2025，ROS 2 Jazzy）。
官方範例：<https://github.com/PacktPublishing/Mastering-ROS-2-for-Robotics-Programming>，已 clone 在 WSL `~/ros2_books/Mastering-ROS-2-for-Robotics-Programming`（以下簡稱「書本 repo」）。

環境：DESKTOP-6LST1BR（HP EliteBook 840 G8），Windows 11 + WSL2 `Ubuntu-24.04` + ROS 2 Jazzy desktop（2026-10-24 安裝），
另裝 Gazebo Harmonic（ros-gz）、ros2_control、Nav2、MoveIt 2、BehaviorTree.CPP、PCL、slam_toolbox。

每段提示詞前面都要加：「全自動執行：不要問我任何問題、不要用選擇題，所有選擇一律採用你的推薦，直接做完並回報」。

## 共通限制（每章都適用）

- **練習視窗是 Windows 上的 Claude Code，ROS 2 在 WSL 裡跑**。做法：把要執行的指令寫成練習資料夾裡的 `.sh` 檔（用 Write 工具，LF 換行），再用
  `wsl.exe -d Ubuntu-24.04 --cd "<練習資料夾的 Windows 路徑>" -- bash ./步驟檔.sh 2>&1 | tee logs/步驟檔.log` 執行。
  不要用 `wsl.exe ... bash -c '很長的指令'`（Git Bash 傳引號會壞）。腳本開頭固定：`set -eo pipefail`、`source /opt/ros/jazzy/setup.bash`、`export ROS_DOMAIN_ID=36`。
- **WSL 工作區**：`~/k136_ws/chNN`。把書本 repo 的 `ChapterNN/<套件>` 複製到 `~/k136_ws/chNN/src/`（書本 repo 原檔不動），用 `colcon build --symlink-install` 建置，之後 `source install/setup.bash`。
- **一定會結束**：會一直跑的節點／launch 一律用 `timeout 30`～`timeout 120` 包起來，或背景啟動＋記 PID＋最後 `kill`。每次 Bash 呼叫的 timeout 不超過 120000 毫秒；建置可能超過 2 分鐘的，改用背景執行（`nohup ... > logs/build.log 2>&1 &`）再每 1 分鐘看一次 log。
- **不開圖形視窗**（整夜無人看管，視窗會跳到主螢幕且沒人關）：Gazebo 用 server 模式（`gz sim -s -r`，或 launch 參數 `gz_args:='-s -r ...'`／`headless`）、RViz、joint_state_publisher_gui、rqt 一律不啟動；launch 檔寫死 GUI 時，在工作區複製檔裡改掉並註明「本演練改」。驗證改用 `ros2 topic echo --once --no-daemon`、`ros2 topic hz`、`ros2 run tf2_ros tf2_echo`、`ros2 control list_controllers`、`ros2 action send_goal` 等指令，把輸出存進 `logs/`。
- **清理**：每個腳本結束前停掉自己啟動的行程（用記下的 PID 或 `kill %1`）。不要在 `bash -c` 裡用 `pkill -f <字串>`（會把自己也殺掉）；要清殘留就寫成獨立腳本 `cleanup.sh`。章末執行 `ros2 daemon stop`。
- **缺套件**：`sudo apt-get install -y ros-jazzy-<名稱>`（WSL 的 sudo 免密碼）。Python 套件裝在 WSL 的 `~/k136_venv`（`python3 -m venv --system-site-packages ~/k136_venv`），不要 `pip install --break-system-packages`。
- **需要硬體或金鑰的一律模擬**：webcam、深度相機、樹莓派、LiDAR、PX4 飛控、NVIDIA GPU 都沒有；OpenAI 金鑰不可設。改用假資料／模擬／只建置，`NOTES.md` 寫清楚和書上的差異。
- **絕不執行** `/logout`、`/login`、`/upgrade`、`/install-github-app`、`/statusline`、`/doctor`，不修改全域 `~/.claude/`；不設 `ANTHROPIC_API_KEY`／`OPENAI_API_KEY`；不建 GitHub repo、不 push、不部署。
- 每章產出 `NOTES.md`：做了什麼、驗證結果（貼關鍵輸出幾行）、和書上做法的差異。執行紀錄放 `logs/`。完成後 `git add`＋`commit`（繁中訊息）。

## 各章提示詞

| 章 | 主題 | 要練習視窗做的事 |
| --- | --- | --- |
| 01 | ROS 2 簡介 | 不寫程式，用指令把書上的觀念走一遍：`printenv ROS_DISTRO`、`ros2 pkg list \| wc -l`、背景跑 `demo_nodes_cpp talker`＋`demo_nodes_py listener`（timeout 15，跨語言互通），期間用 `ros2 node list`、`ros2 topic list -t`、`ros2 topic info /chatter -v`（看 QoS）、`ros2 interface show std_msgs/msg/String`；再用 `RMW_IMPLEMENTATION=rmw_fastrtps_cpp` 與 `ROS_DOMAIN_ID` 不同值示範「不同 domain 互相看不到」。`NOTES.md` 用表格整理書上第 1 章的 ROS 2 架構（DDS、RMW、rcl、client library）與 ROS 1 差異 |
| 02 | 開始寫 ROS 2 程式 | 讀書本 repo `Chapter02/ros2_install_jazzy.sh`，在 `NOTES.md` 說明它做了哪些步驟、和本機實際安裝（ros2-apt-source）的差異；`Chapter02/ros2_jazzy_docker` 只讀 Dockerfile 說明用途（本機沒裝 Docker，不建 image）。實作：在 `~/k136_ws/ch02` 用 `ros2 pkg create` 各建一個 C++（ament_cmake）與 Python（ament_python）套件，各寫一個最小節點（印 log 的 timer），`colcon build`、`ros2 run` 跑 5 秒（timeout），`colcon list`、`ros2 pkg executables` 驗證 |
| 03 | 實作 ROS 2 觀念 | 複製 `Chapter03/master_ros2_interface`、`master_ros2_pkg` 建置。依序跑四個 launch（各 timeout 15）：`pub_sub.launch.py`、`pub_params_sub.launch.py`（期間 `ros2 param list`／`param set` 改參數看輸出變化）、`server_client.launch.py`、`action_server_client.launch.py`；另用 `ros2 interface show` 看自訂 msg／srv／action，`ros2 service call`、`ros2 action send_goal --feedback` 手動呼叫一次。`NOTES.md` 整理 topic／service／action／parameter 的程式結構重點 |
| 04 | 機器人 3D 建模 | 複製 `Chapter04/urdf_tutorial`、`rrbot_description`、`rosbot_description` 建置。`check_urdf` 檢查 `simple_rrbot.urdf`；把 rrbot／rosbot 的 xacro 轉成 URDF 再 `check_urdf`；`urdf_to_graphviz` 產生 link 樹（PDF 轉 PNG 存進練習資料夾）；不開 RViz，背景跑 `robot_state_publisher`＋`joint_state_publisher`（非 GUI），用 `tf2_echo` 讀兩個 link 的轉換、`ros2 topic echo /robot_description --once` 確認模型已發布。`NOTES.md` 整理 URDF link／joint／xacro macro 重點 |
| 05 | 在擬真環境模擬機器人 | 複製 `Chapter05` 的 `rrbot_gazebo`、`diffbot_gazebo`、`rosbot_description` 建置。用 Gazebo server 模式（不開畫面）跑 `diffbot_gz.launch.py`（必要時在工作區複製檔改成 `-s -r`），等 spawn 完成後用 `ros2 topic pub -r 10` 發 `cmd_vel` 讓車子前進 10 秒，比對前後 `odom` 位置有變；再跑 `rrbot_gazebo.launch.py`，看 `ros_gz_bridge` 橋接的 topic 清單。`NOTES.md` 說明 ros_gz_bridge 設定檔怎麼對應 Gazebo 與 ROS topic |
| 06 | ros2_control | 複製 `Chapter06/two_joints_robot`、`sine_ctrl` 建置。Gazebo server 模式跑 `start_simu.launch.py`，`ros2 control list_controllers`、`list_hardware_interfaces` 看控制器狀態；載入並啟用書上的自訂 `sine_controller`（看 `sine_controller.xml` 的 plugin 名稱），讀 `/joint_states` 幾秒確認關節照正弦變化（把數值存檔、算最大最小值）。`NOTES.md` 整理 controller plugin 的生命週期（on_configure／on_activate／update） |
| 07 | BehaviorTree.CPP | 複製 `Chapter07/first_bts`、`bt_action_server` 建置。跑 `sequence_tree.launch.py`、`number_checker.launch.py`（timeout），看 tree XML 與節點輸出的對應；再跑 `bt_action.launch.py`（行為樹呼叫 reach_location action server），記錄 SUCCESS／FAILURE 流程。改一個 tree XML（例如把 Sequence 改 Fallback 或改數字門檻）重跑，比較結果。`NOTES.md` 畫出兩棵樹的結構（文字樹） |
| 08 | Nav2 導航 | 複製 `Chapter08` 的 `rosbot_description`、`rosbot_nav2_bringup`、`nav2_client`、`nav2_bt_client` 建置。Gazebo server 模式＋`nav2.launch.py`（用書附 hospital 地圖、不開 RViz）；等 lifecycle 節點都 active 後，用 `nav2_client` 或 `ros2 action send_goal /navigate_to_pose` 送一個近距離目標，記錄 feedback 與結果。若 20 分鐘內起不來，改成只驗證建置＋`nav2_params.yaml` 解讀，並在 NOTES 寫卡在哪。`NOTES.md` 整理 Nav2 架構（planner／controller／bt_navigator／costmap） |
| 09 | MoveIt 2 機械手臂 | 複製 `Chapter09` 的 `panda_description`、`panda_moveit_config`、`panda_moveit_control` 建置。不開 RViz：用 mock 硬體（ros2_control fake）跑 `move_group`＋控制器（在工作區複製檔關掉 RViz），再跑 `joint_space_planning`、`cartesian_space_planning`、`planning_with_obstacles`（timeout），記錄規劃成功與否與耗時。若 Gazebo 版太重就只用 mock 版。`NOTES.md` 整理 MoveIt 2 設定套件內容（SRDF、kinematics、controllers） |
| 10 | 感知（OpenCV／PCL） | 複製 `Chapter10/my_opencv_package`、`pcl_processing` 建置（`usb_cam_launcher` 只建置，沒有 webcam）。假相機：`ros2 run image_tools cam2image --ros-args -p burger_mode:=true`（必要時 remap 到書上訂閱的 topic），跑 `image_processing` 節點，確認輸出影像 topic 有資料（`topic hz`）；另寫一個小 Python 節點發布合成 PointCloud2（平面＋雜點），餵給 `pcl_processing`，確認濾波／分割後的點數。`NOTES.md` 說明和實體相機的差異 |
| 11 | 空中機器人 | 本機沒有 PX4 SITL（建置要數 GB、超過 1 小時），本章改做：clone `px4_msgs`（選和書相容的分支，NOTES 記錄）到 `~/k136_ws/ch11/src`，複製 `Chapter11/px4_ctrl` 一起建置；讀 `px4_ctrl.cpp` 整理 offboard 控制流程（心跳、arm、setpoint）；在沒有飛控的情況下跑節點 10 秒，用 `ros2 topic echo --once` 看它發出的 OffboardControlMode／TrajectorySetpoint。`NOTES.md` 寫完整 PX4 SITL 要怎麼裝（只寫步驟不執行） |
| 12 | DIY 移動機器人 | 複製 `Chapter12` 的 `mobile_robot_model`、`ldlidar_sl_ros2`、`rf2o_laser_odometry` 建置。`mobile_robot_model` 不開 RViz，跑 robot_state_publisher 確認 TF 樹（`tf2_tools view_frames` 產 PDF 轉 PNG）；LiDAR 驅動沒有硬體，寫一個小節點發假 `/scan`（固定牆面距離＋慢慢平移），餵給 `rf2o_laser_odometry` 看 `/odom` 有沒有估出移動。`NOTES.md` 列書上的硬體清單（樹莓派、馬達驅動、LiDAR）與 micro-ROS 部分為何略過 |
| 13 | 測試與 CI/CD | 複製 `Chapter13/first_gtest`、`to_lowercase` 建置，`colcon test`＋`colcon test-result --verbose`；故意改壞一個測試看失敗訊息，再改回。寫 `.github/workflows/ros2-ci.yml` 範本（用 `ros-tooling/setup-ros`＋`action-ros-ci`，Jazzy），只寫檔、不 push；用 `python3 -c "import yaml"` 檢查 YAML 語法。`NOTES.md` 說明 CI 和 CD 在 ROS 2 專案的做法 |
| 14 | LLM 介接 ROS 2 | 複製 `Chapter14/ros2_basic_agent`。不可用 OpenAI 金鑰：在 `~/k136_venv` 裝書上用的 langchain 套件，把 LLM 換成假 LLM（langchain 的 Fake 模型或自寫固定回應），讓 `ros2_ai_agent_turtlesim` 的工具呼叫流程能跑：turtlesim 用 `QT_QPA_PLATFORM=offscreen` 跑，agent 收到「往前走」的指令後真的發 cmd_vel，讀 `/turtle1/pose` 證明有移動。`NOTES.md` 說明真的要接 OpenAI 時要改哪裡（只寫 config/openai.env 範本，不放金鑰） |
| 15 | 深度強化學習 | 本機沒有 NVIDIA GPU，Isaac Sim／Isaac Lab 不能跑。改做：讀 `Chapter15/docker_setup_scripts`，NOTES 說明它裝了什麼；在 `~/k136_venv` 裝 `gymnasium`，寫一個 CartPole 的表格式 Q-learning（或 numpy 版 REINFORCE）小程式，訓練到平均回合長度明顯變長，把學習曲線存成 PNG。`NOTES.md` 對照書上 RL 流程（環境、獎勵、策略、訓練）和本練習 |
| 16 | 視覺化與模擬外掛 | 複製 `Chapter16` 四個套件（`circle_msgs`、`circle_display_plugin`、`cmd_vel`、`cmd_vel_plugin`）建置。不開 RViz：用 `ros2 pkg prefix`＋plugin XML 確認 RViz display／panel plugin 已註冊（pluginlib 匯出）；Gazebo server 模式跑 `cmd_vel_plugin.launch.py`，確認 Gazebo 系統外掛有發／收 `cmd_vel`，模型有移動。`NOTES.md` 整理 RViz plugin 與 Gazebo plugin 的寫法差異 |
