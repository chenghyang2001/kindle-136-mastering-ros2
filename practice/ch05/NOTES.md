# K136 第 5 章快速演練：在擬真環境模擬機器人（Gazebo Harmonic + ros_gz）

> 快速 demo 模式，未經 QA／審查。環境：Windows Claude Code → WSL Ubuntu-24.04、ROS 2 Jazzy、Gazebo Harmonic（gz sim 8）、CycloneDDS、`ROS_DOMAIN_ID=36`、LOCALHOST 探索。

## 做了什麼

| 腳本 | 內容 | log |
| --- | --- | --- |
| `step0_explore.sh`／`step0b_peek.sh` | 看 Chapter05 三個套件的 launch、xacro、bridge yaml、已裝套件 | `logs/step0*.log` |
| `step1_build.sh` | 複製 `rrbot_gazebo`、`diffbot_gazebo`、`rosbot_description`（＋第 4 章的 `rrbot_description`）到 `~/k136_ws/ch05/src`，改成無畫面版後 `colcon build --symlink-install`（4 個套件，約 5 秒） | `logs/step1_build.log` |
| `step2_diffbot.sh` | server 模式跑 `diffbot_gz.launch.py`，發 `cmd_vel` 讓車子前進 10 秒，比對前後 `/odom` | `logs/step2_diffbot.log`、`logs/diffbot_launch.log`、`logs/odom_*.txt` |
| `step3_rrbot.sh` | server 模式跑 `rrbot_gazebo.launch.py`，列出 ros_gz_bridge 建的橋接、gz／ROS 兩邊的 topic，送一個手臂軌跡 | `logs/step3_rrbot.log`、`logs/rrbot_launch.log` |
| `cleanup.sh` | 清掉殘留的 ROS／Gazebo 行程，`timeout 15 ros2 daemon stop` | `logs/cleanup.log` |

## 驗證結果

### diffbot：cmd_vel → 車子前進，odom 有變

```
Entity creation successful.
=== 前進前 odom ===      x: -1.578e-11   y: -2.3e-26
=== 發 cmd_vel linear.x=0.5，10 Hz，10 秒 ===   publishing #87 ...
=== 前進後 odom ===      x: 4.9199       y: -2.5e-07
/odom average rate: 26.2 Hz
```

用 0.5 m/s 開大約 10 秒，走了 4.92 m，y 幾乎沒動，表示是直線前進。

### rrbot：ros_gz_bridge 建立的橋接

```
Creating GZ->ROS Bridge: [/clock (gz.msgs.Clock) -> /clock (rosgraph_msgs/msg/Clock)]
Creating GZ->ROS Bridge: [/scan (gz.msgs.LaserScan) -> /diff_drive/scan (sensor_msgs/msg/LaserScan)]
Creating GZ->ROS Bridge: [camera/camera_info (gz.msgs.CameraInfo) -> camera/depth/camera_info (sensor_msgs/msg/CameraInfo)]
Creating GZ->ROS Bridge: [camera/points (gz.msgs.PointCloudPacked) -> camera/depth/color/points (sensor_msgs/msg/PointCloud2)]
```

`ros2 node info /ros_gz_bridge` 列出的 Publishers 剛好就是這 4 個 ROS topic。`/camera/color/image_raw`、`/camera/depth/image_rect_raw` 不是 parameter_bridge 建的，是另一個節點 `ros_gz_image/image_bridge`（加上 remap）建的。controller 方面：

```
Configured and activated joint_state_broadcaster
Configured and activated arm_controller
send_goal FollowJointTrajectory [0.5, -0.5] → Goal successfully reached!  SUCCEEDED
/joint_states position: [0.5000, -0.5000]
```

## ros_gz_bridge 設定檔怎麼對應 Gazebo 與 ROS topic

`parameter_bridge` 透過參數 `config_file` 讀入一份 YAML 清單，每一項就是一條橋：

```yaml
- ros_topic_name: "/diff_drive/scan"         # ROS 2 那邊的 topic 名稱
  gz_topic_name: "/scan"                     # Gazebo（gz-transport）那邊的 topic 名稱
  ros_type_name: "sensor_msgs/msg/LaserScan" # ROS 訊息型別
  gz_type_name: "gz.msgs.LaserScan"          # Gazebo 訊息型別（兩邊必須是 bridge 支援的配對）
  direction: GZ_TO_ROS                       # GZ_TO_ROS／ROS_TO_GZ／BIDIRECTIONAL
  # lazy: true                               # 有訂閱者時才真的建立連線，省資源
```

- **名稱可以不同**：gz 的 `/scan` 在 ROS 端改叫 `/diff_drive/scan`，等於順便做了 remap。
- **gz topic 名稱從哪來**：xacro 裡 `<gazebo>` 區塊的 `<sensor><topic>scan</topic>`（光達）、`<topic>camera</topic>`（RGBD 相機會衍生 `camera/image`、`camera/depth_image`、`camera/camera_info`、`camera/points`）、DiffDrive plugin 的 `<topic>/cmd_vel</topic>`、`<odom_topic>`、`<tf_topic>`，以及 Gazebo 世界本身的 `/clock`。用 `gz topic -l` 可以看到 Gazebo 端實際有哪些 topic（`logs/step3_rrbot.log`）。
- **方向**：感測器、clock、tf、joint_states 是 `GZ_TO_ROS`（模擬器產生資料給 ROS）；diffbot 的 `/cmd_vel` 是 `ROS_TO_GZ`（ROS 下指令給 Gazebo 的 DiffDrive plugin）。
- **型別要配對**：例如 `tf2_msgs/msg/TFMessage ↔ gz.msgs.Pose_V`、`sensor_msgs/msg/JointState ↔ gz.msgs.Model`、`nav_msgs/msg/Odometry ↔ gz.msgs.Odometry`、`PointCloud2 ↔ gz.msgs.PointCloudPacked`。
- **影像另外橋**：影像 topic 走 `ros_gz_image image_bridge`（支援 image_transport，所以 ROS 端多了 `/compressed`、`/theora`、`/zstd` 等子 topic）。
- 三份 diffbot yaml 的差別：`ros_gz_bridge_gazebo.yaml`（純 gz plugin 版，多了 `/tf`、`/joint_states`、`/cmd_vel`）、`ros_gz_bridge_control.yaml`（ros2_control 版，tf／joint_states 由 controller 自己發，所以不橋）。rrbot 用 ros2_control，`joint_states` 由 `joint_state_broadcaster` 發，bridge 只橋 clock 與感測器。

## 和書上做法的差異（都只改 `~/k136_ws/ch05/src` 的複製檔，書本 repo 原檔不動）

1. **不開畫面**：兩個 launch 的 `gz_args` 從 `'<world> -r'` 改成 `'<world> -s -r'`（server 模式）；`rviz`、`rqt_robot_steering`、`delayed_rqt_traj_controller` 註解掉（標「本演練改」）。書上是用 RViz／rqt_robot_steering 拖滑桿開車，這裡改用 `ros2 topic pub -r 10 /cmd_vel` 與 `ros2 action send_goal`。
2. **補 `/odom` 橋接**：`diffbot_gz.launch.py` 用的 `ros_gz_bridge_gazebo.yaml` 沒有橋 DiffDrive plugin 的 odom，在複製檔末端加一條 `/odom (gz.msgs.Odometry → nav_msgs/msg/Odometry)` 才能用 `ros2 topic echo /odom` 比對位置。
3. **多複製第 4 章的 `rrbot_description`**：`rrbot.xacro` 會 `$(find rrbot_description)`，只複製 Chapter05 三個套件時 launch 直接 `PackageNotFoundError`。
4. **`ros2 control load_controller` 換成 `ros2 run controller_manager spawner`**：書上的指令會經過 ros2 daemon，本機 daemon 會卡死，第一次跑時 joint_state_broadcaster 卡了 50 秒還沒載入。改用 spawner（直接當節點跟 controller_manager 講話）後 2～3 秒就啟用。
5. `ros2 control list_controllers` 不支援 `--no-daemon`（log 裡有 `unrecognized arguments`），改看 spawner 的 log 與實際送軌跡來確認 controller 狀態。
6. 沒有 GPU：Sensors plugin（ogre2）在 WSL 用軟體算繪也能起來，相機／光達 topic 都有出現，但沒有檢查影像內容。
7. 沒有跑 `diffbot_gz_ros2_control.launch.py` 與 `rosbot_description/gazebo.launch.py`（本章任務沒要求，只有建置）。

## 清理

`cleanup.sh`：沒有殘留行程，`ros2 daemon stop` 本來就沒在跑，最後檢查「乾淨：無殘留」。
