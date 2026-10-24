# K136 演練交接

## 原機器結果

本書第一次演練（DESKTOP-6LST1BR，2026-10-24 晚上無人值守）。書本範例全部在 WSL2 Ubuntu-24.04 + ROS 2 Jazzy 跑；圖形視窗一律不開，改用指令驗證；需要硬體（webcam、樹莓派、LiDAR、PX4、NVIDIA GPU）或 OpenAI 金鑰的部分改模擬。

## 快速模式進度表

| 章 | 完成日 | 實際耗時 | 和書上做法的差異 |
| --- | --- | --- | --- |
| 01 | 2026-10-24 | 約 10 分鐘（18:06–18:16） | ros2 daemon 在 WSL 卡死，查詢改加 --no-daemon；區網有別台機器用 domain 36，加 ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST；Python listener 啟動慢，等待時間拉長 |
| 02 | 2026-10-24 | 約 4 分鐘（18:18–18:22） | 沒有 Docker，Dockerfile 只讀不建；本機是 ros2-apt-source＋desktop（書上腳本讓你選 desktop-full／ros-base）；查詢加 --no-daemon |
| 03 | 2026-10-24 | 約 15 分鐘（18:22–18:37） | Fast DDS 在 WSL 跨行程探索極慢，改 rmw_cyclonedds_cpp＋lo 開 multicast；書上程式 timer 每次重設參數，param set 只生效一拍 |
