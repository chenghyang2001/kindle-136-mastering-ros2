# K136 演練交接

## 原機器結果

本書第一次演練（DESKTOP-6LST1BR，2026-10-24 晚上無人值守）。書本範例全部在 WSL2 Ubuntu-24.04 + ROS 2 Jazzy 跑；圖形視窗一律不開，改用指令驗證；需要硬體（webcam、樹莓派、LiDAR、PX4、NVIDIA GPU）或 OpenAI 金鑰的部分改模擬。

## 快速模式進度表

| 章 | 完成日 | 實際耗時 | 和書上做法的差異 |
| --- | --- | --- | --- |
| 01 | 2026-10-24 | 約 10 分鐘（18:06–18:16） | ros2 daemon 在 WSL 卡死，查詢改加 --no-daemon；區網有別台機器用 domain 36，加 ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST；Python listener 啟動慢，等待時間拉長 |
| 02 | 2026-10-24 | 約 4 分鐘（18:18–18:22） | 沒有 Docker，Dockerfile 只讀不建；本機是 ros2-apt-source＋desktop（書上腳本讓你選 desktop-full／ros-base）；查詢加 --no-daemon |
| 03 | 2026-10-24 | 約 15 分鐘（18:22–18:37） | Fast DDS 在 WSL 跨行程探索極慢，改 rmw_cyclonedds_cpp＋lo 開 multicast；書上程式 timer 每次重設參數，param set 只生效一拍 |
| 04 | 2026-10-24 | 約 4 分鐘（18:38–18:42） | 不開 RViz／joint_state_publisher_gui，改用 tf2_echo 與 topic echo /robot_description 驗證；graphviz PDF 轉 PNG |
| 05 | 2026-10-24 | 約 10 分鐘（18:42–18:52） | Gazebo 改 server 模式、關 RViz／rqt；補 /odom 橋接；多複製 ch04 rrbot_description；load_controller 經 daemon 卡住改用 spawner；以 topic pub 取代 rqt_robot_steering |
| 06 | 2026-10-24 | 約 12 分鐘（18:53–19:05） | Gazebo server 模式；spawner＋service call 取代 ros2 control CLI；書上 set_value 傳 float 在 Jazzy 執行期被拒，改 double；需手動發 /sine_param；未橋接 /clock 改用 wall time 計算 |
| 07 | 2026-10-24 | 約 12 分鐘（19:05–19:17） | ros2 action list 無 --no-daemon 改看 log；ros2 run 子行程殘留污染比較，改直接執行二進位檔重做；額外改 number_checker 為 Sequence、bt_action 加 Fallback 比較 |
| 08 | 2026-10-24 | 約 6 分鐘（19:18–19:24） | Gazebo server 模式、關 RViz，改用 action send_goal 驗證（SUCCEEDED）；自行 export GZ_SIM_RESOURCE_PATH；未設初始位姿（靠 static map→odom）；nav2_client 只跑 40 秒；nav2_bt_client 需 Groot2 只建置 |
| 09 | 2026-10-24 | 約 23 分鐘（19:25–19:48） | 只做 mock 版、不開 RViz（demo_headless）；URDF 寫死 GazeboSimSystem 讓 mock 失敗，加 xacro 參數關掉；initial_positions 全 0 超出 joint4 限制改 ready 姿態；use_sim_time 改 False；Gazebo 版未跑 |
| 10 | 2026-10-24 | 約 7 分鐘（19:48–19:55） | 無 webcam／RealSense：cam2image burger 假相機＋自寫合成點雲；不開 rqt/RViz 改用 topic hz；書上 pcl_processing 無分割，於驗證節點補 RANSAC；透視轉換原碼未實作 |
| 11 | 2026-10-24 | 約 12 分鐘（19:56–20:08） | 無 PX4 SITL：px4_msgs release/1.15＋px4_ctrl 只建置；無飛控時節點卡在等 vehicle_command 服務；自寫 fake_fcu.py 冒充飛控驗證 offboard 流程；SITL 安裝只寫步驟 |
| 12 | 2026-10-24 | 約 9 分鐘（20:08–20:17） | 無樹莓派／LiDAR，micro-ROS 略過；不開 RViz 改 view_frames 產 TF 樹；自寫假 /scan 餵 rf2o，移動量接近真值但 x 方向相反（試 3 次未解，記在 NOTES） |
| 13 | 2026-10-24 | 約 6 分鐘（20:18–20:25） | 書本 HandlesOverflowAngles 期望值與函式範圍 [-π,π) 不一致，工作區副本改 -M_PI；CI yml 只寫不 push；發現 colcon test 失敗仍回 0，需靠 colcon test-result |
| 14 | 2026-10-24 | 約 28 分鐘（20:26–20:54，pip 網路不穩） | 不用 OpenAI 金鑰：先寫不依賴 langchain 的最小假 agent 當備案，再用書上 agent＋langchain 0.3 假 LLM 對照，兩版 turtlesim 都有移動；turtlesim 用 offscreen；openai.env 只放範本 |
| 15 | 2026-10-25 | 實際約 10 分鐘（20:55 開始，筆電睡眠到 04:49，04:52 完成） | 無 NVIDIA GPU：Isaac Lab＋PPO 改 gymnasium CartPole 表格式 Q-learning（末 100 回合平均 466 步）；docker 腳本只讀不執行；第一次 pip 裝出壞的 gymnasium，重裝後正常 |
| 16 | 2026-10-25 | 約 5 分鐘（04:53–04:58） | 不開 RViz／rqt：用 pluginlib 清單、plugin XML 與 .so 符號確認外掛已註冊；Gazebo server 模式驗證外掛限速 0.5→0.2 並轉發 cmd_vel，模型移動約 1.1 m；書上 cmd_vel 是 rqt 面板外掛 |

## 補做：第 2 章 Docker（2026-10-25）

第一次演練時誤判沒有 Docker（其實是 Docker Desktop 沒啟動）。補做書上 `docker_compose` 兩個範例：容器之間 talker／listener 互通 ✅；Docker Desktop 下容器 ↔ WSL 本機的 ROS 2 不通（Docker 虛擬機和 WSL 不同網段）。詳見 `practice/ch02-docker/NOTES.md`。

## 第二台電腦結果（hp1，2026-10-25）

在 hp1 重跑，直接重用 hp2 的 practice/chNN 腳本與 ws_src；這台的腳本、NOTES、log 留在本機 k136-chNN-practice。

| 章 | 耗時 | 與 hp2 結果的差異 |
| --- | --- | --- |
| 01 | 約 2 分鐘（07:23–07:25） | 沿用 hp2 三個腳本未改；套件數 482（hp2 479）；listener 14 則、domain 36／37 為 16／0，與 hp2 相同；node list --no-daemon 這次沒列出節點（探索時間短） |
| 02 | 約 3 分鐘（07:27–07:30） | 沿用 hp2 四個腳本，加 cyclonedds；建置 Python 3.28 s／C++ 11.0 s（hp2 2.35／9.84 s，機器差異）；colcon list、pkg executables、tick 輸出與 hp2 相同；ws_src 只差 maintainer 名稱（peter） |
| 03 | 約 5 分鐘（07:31–07:36） | 沿用 hp2 step0–6＋cleanup 未改；建置 42.9 s（hp2 54.1 s）；topic／param（只生效一拍）／service／action 結果與 hp2 相同；ros2 action list 一樣卡到 timeout |
| 04 | 約 5 分鐘（07:37–07:42） | 關鍵數字與 hp2 完全相同（check_urdf、link 樹、tf2_echo 值）；這台缺 pdftoppm，腳本加自動裝 poppler-utils；step3_tf.sh 收尾 kill 已結束行程被 set -e 判失敗，改為忽略（hp2 log 停在同處，可能也是 exit 1） |
| 05 | 約 5 分鐘（07:43–07:48） | 沿用 hp2 六個腳本未改；diffbot 10 秒前進 5.04 m（hp2 4.92 m）、/odom 24.5 Hz（hp2 26.2 Hz）；rrbot 4 條橋接、手臂軌跡 SUCCEEDED 與 hp2 相同；建置 10.4 s（hp2 約 5 s） |
| 06 | 約 7 分鐘（07:48–07:55） | 關鍵數字與 hp2 一致：sine_controller 啟用 ok、base_joint 0.82–1.78 rad 0.5 Hz、滑動關節因離心力卡上限 0.3；背景建置會被 wsl.exe 收掉，改前景（23 s）；多加 step2b 只動滑動關節的測試 |
| 07 | 約 13 分鐘（07:56–08:09） | 各樹行為與 hp2 一致；改樹 B 成功 5 次（hp2 6 次，70 秒截止時第 6 輪未完）；number_checker 筆數隨機波動；同樣重現 ros2 run 殘留節點污染，以 step5 直接執行二進位檔為準；WSL /tmp 在兩次 wsl.exe 間被清空，改把輸出另存 logs/ |
| 08 | 約 5 分鐘（08:10–08:15） | 沿用 hp2 五個腳本未改；11 個 lifecycle 節點 active，目標 (1.5,0) 4.6 秒 SUCCEEDED，與 hp2 相同；nav2_client 40 秒剩餘距離 29.58→20.03 m（hp2 降到 19.01 m，模擬稍慢） |
| 09 | 約 11 分鐘（08:17–08:28） | mock 版結果與 hp2 一致：joint_space 2/2、cartesian 79 點 100%（hp2 78 點）、planning_with_obstacles 接續跑同樣 GOAL_STATE_INVALID、重開後成功；step2 超過 120 秒改背景重跑；補 step4 查控制器（list_controllers 不支援 --no-daemon） |
| 10 | 約 6 分鐘（08:29–08:35） | 點雲數字與 hp2 完全相同（42401→4897 點、RANSAC 平面 z=0.6）；7 個影像 topic 約 10 Hz、透視轉換寬度 0 同 hp2；建置 2 分 22 秒（hp2 1 分 54 秒）；兩個 .py 改 LF |
| 11 | 約 13 分鐘（08:37–08:50） | px4_msgs 改從本機 ~/ros2_books/px4_msgs 複製（同 release/1.15，213 msg）；建置 8 分 25 秒（hp2 6 分 18 秒）；無飛控同樣卡在等服務；fake_fcu 流程 ARM→OFFBOARD→DISARM 與 hp2 相同，心跳 35 筆（hp2 36）；topic hz 10.00 Hz（hp2 量測含空檔 7.75–8.06） |
| 12 | 約 8 分鐘（08:50–08:58） | TF 樹（base_footprint 下 5 個子 frame、雷射位置）與 hp2 相同；rf2o 360° 估 −2.188 m（hp2 −2.178）、270° 估 −2.144 m，同樣 x 方向相反未解；建置 49.1 s（hp2 36.3 s） |
| 13 | 約 4 分鐘（08:59–09:03） | 關鍵數字與 hp2 相同：原樣 7 tests 2 failures（540° 期望值 +π 與 [-π,π) 不符）、修正後 7 tests 0 failures、故意改壞看得到 Which is 訊息；CI yml 語法通過未 push；新資料夾缺 src/，複製腳本加 mkdir -p src |
| 14 | 約 5 分鐘（09:04–09:09） | 數字與 hp2 完全相同：A／B 兩條路線 turtle x 5.5444→6.2500、MOVED_OK，cmd_vel 0.2／0.5；langchain 0.3.30 一次裝好（hp2 pip 斷線重試多次） |
