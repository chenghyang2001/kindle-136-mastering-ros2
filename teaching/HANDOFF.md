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
