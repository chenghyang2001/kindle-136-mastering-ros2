# K136 第 8 章快速演練：Nav2 導航

> 快速 demo 模式（未經 QA／審查）。ROS 2 Jazzy 在 WSL `Ubuntu-24.04`，工作區 `~/k136_ws/ch08`，書本 repo 原檔未動。

## 做了什麼

| 腳本 | 內容 | 紀錄 |
| --- | --- | --- |
| `step0_explore.sh`／`step0b_files.sh` | 讀 Chapter08 結構、launch、bridge 設定、`nav2_params.yaml`、client 原始碼；確認 navigation2／nav2_bringup／ros_gz／behaviortree_cpp 都已安裝（不用 apt 補裝） | `logs/step0_*.log` |
| `step1_build.sh` | 複製 `rosbot_description`、`rosbot_nav2_bringup`、`nav2_client`、`nav2_bt_client` → `colcon build --symlink-install` | `logs/step1_build.log` |
| `step2_nav.sh` | Gazebo server 模式＋`nav2.launch.py`（hospital 地圖、不開 RViz）→ 查 lifecycle → `ros2 action send_goal` 近距離目標 → 書附 `navigation_client` 跑 40 秒 | `logs/step2_nav.log`、`gazebo.log`、`nav2.log`、`send_goal.log`、`nav2_client.log` |
| `cleanup.sh` | 清殘留行程＋`timeout 15 ros2 daemon stop` | `logs/cleanup.log` |

## 驗證結果（全部成功，沒有退回「只建置」方案）

**建置**：`Summary: 4 packages finished [21.7s]`（nav2_bt_client 依賴的 `tb_worlds` 不存在，但只是 package.xml 的宣告，colcon 不影響建置）。

**Gazebo**（server 模式，第一次檢查就就緒）：

```
[ros_gz_sim]: Entity creation successful.
/odom pose: x≈0, y≈0（機器人在 odom 原點）   /scan range_max: 10.0
```

目標點先用 `hospital.pgm` 驗證是空地：`goal (1.5,0.0) → pixel (65,119) value=254 (free)`。

**Nav2 啟動只花 10 秒**，兩個 lifecycle_manager 都回報 `Managed nodes are active`；逐一 `get_state`：

```
map_server / amcl / controller_server / smoother_server / planner_server / behavior_server /
velocity_smoother / collision_monitor / bt_navigator / waypoint_follower / docking_server → 全部 label='active'
```

（Jazzy 的 navigation_launch 另外還有 `route_server`，也有 activate）

**TF**：`map → base_link` 平移 0、旋轉 0（map→odom 由 launch 裡的 static_transform_publisher 給）。

**送目標 (1.5, 0.0)**：

```
Goal accepted with ID: e7247542a4f14eb69630bf62ba06e489
distance_remaining: 1.4947 → 1.4197 → 1.2947 → ... → 0.2447
navigation_time: 4.72 s   number_of_recoveries: 0
Result: error_code: 0
Goal finished with status: SUCCEEDED
到點後 /odom: x=1.276, y=-0.020   （xy_goal_tolerance 0.25 內）
```

**書附 nav2_client**（互動式，餵 `1` → 先去 medical_shop (26.36, -6.18)）：

```
Goal accepted by server
Distance remaining: 29.58 → ... → 19.01（40 秒內走了約 10 m）
```

40 秒到就被 `timeout` 中斷（全程 26 m＋取藥 15 秒＋送 room1＋回原點，太長不跑完），中斷時印出 `Navigation failed` 是被 SIGINT 打斷的結果，不是導航失敗。

## Nav2 架構整理

```
         NavigateToPose action（ros2 action send_goal / nav2_client）
                         │
                  ┌──────▼───────┐  行為樹 navigate_to_pose_w_replanning_and_recovery.xml
                  │ bt_navigator │  （每秒重新規劃 → 跟隨路徑 → 失敗時 recovery：清 costmap/spin/backup/wait）
                  └──┬────────┬──┘
   ComputePathToPose │        │ FollowPath
          ┌──────────▼──┐  ┌──▼────────────────┐
          │planner_server│  │ controller_server │── cmd_vel_nav
          │ NavFn (全域) │  │ DWB (區域)         │
          └──────┬───────┘  └──────┬────────────┘     velocity_smoother → cmd_vel_smoothed
         global_costmap       local_costmap            collision_monitor → cmd_vel (TwistStamped)
   (static+obstacle+voxel     (obstacle+voxel                       │ ros_gz_bridge
    +inflation, map frame)     +inflation, odom 3x3 m 滾動視窗)        ▼  Gazebo DiffDrive
                                                     behavior_server：spin / backup / drive_on_heading / wait
   map_server（hospital.yaml）＋ amcl → 定位         lifecycle_manager：依序 configure→activate 所有節點
```

### `nav2_params.yaml` 重點解讀

| 區塊 | 關鍵參數 | 意義 |
| --- | --- | --- |
| `amcl` | `min/max_particles 500/2000`、`laser_model_type: likelihood_field`、`base_frame_id: base_footprint` | 粒子濾波定位；本演練沒給 `/initialpose`，所以 AMCL 一直警告「Please set the initial pose」（36 次），map→odom 實際由 static TF 頂替 |
| `bt_navigator` | `default_nav_to_pose_bt_xml: navigate_to_pose_w_replanning_and_recovery.xml`、`robot_base_frame: base_link` | 用行為樹編排「規劃→控制→恢復」；第 7 章的 BT 概念在這裡落地 |
| `planner_server` | `NavfnPlanner`、`use_astar: false`（Dijkstra）、`tolerance: 0.5`、`allow_unknown: true` | 全域路徑，目標點 0.5 m 內找不到可用格就失敗 |
| `controller_server` | `controller_frequency: 10`、DWB：`max_vel_x 0.3`、`max_vel_theta 1.0`、`sim_time 1.5`、7 個 critics | 區域控制器以 10 Hz 取樣速度、模擬 1.5 秒軌跡打分；`goal_checker xy/yaw tolerance 0.25`；`progress_checker` 10 秒內沒移動 0.1 m 判失敗 |
| `local_costmap` | `global_frame: odom`、`rolling_window`、`3x3 m`、`robot_radius 0.15`、`inflation_radius 0.5` | 只看光達即時障礙；沒有 static_layer |
| `global_costmap` | `global_frame: map`、`plugins: static+obstacle+voxel+inflation` | 地圖＋光達合成；`track_unknown_space: true` |
| `behavior_server` | spin／backup／drive_on_heading／wait／assisted_teleop | 行為樹失敗時呼叫的恢復動作 |
| `velocity_smoother`、`collision_monitor` | `max_velocity [0.5,0,2.5]`；`PolygonStop` 半徑 0.2 m 停車、`PolygonSlow` 減速 0.3 | 速度平滑＋最後一道碰撞防護，輸出才是 `/cmd_vel` |
| 全部 | `enable_stamped_cmd_vel: true` | Jazzy 改用 `TwistStamped`，所以 bridge 設定的 `/cmd_vel` 是 `geometry_msgs/msg/TwistStamped → gz.msgs.Twist` |

## 和書上做法的差異

1. **不開 GUI**（本演練改，只改工作區複本）：`gazebo.launch.py` 的 `gz_args` 從 `" -r"` 改成 `" -s -r"`（server 模式）；`nav2.launch.py` 註解掉 `ld.add_action(rviz_launch_cmd)`。書上是用 RViz 的「2D Goal Pose」點目標、在 Gazebo 視窗看車子跑；本演練改用 `ros2 action send_goal --feedback` 與 `/odom` 數值驗證。
2. **GZ_SIM_RESOURCE_PATH**：書附 `gazebo.launch.py` 把設定資源路徑的兩行註解掉了（`set_env_vars_resources*`），而且 `setup.py` 的 `models/*.*` glob 不會安裝 `models/hospital` 子資料夾。腳本自行 export `~/k136_ws/ch08/src/rosbot_description/models` 等路徑。
3. **沒用 Docker**：書附 `docker_nav2`／`docker_compose_nav2` 沒用，直接用 WSL 原生 Jazzy。
4. **初始位姿**：沒在 RViz 設 2D Pose Estimate，AMCL 不發佈 map→odom；`nav2.launch.py` 本身就有 identity 的 `map→odom` static TF，所以導航照樣能跑（但這等於沒真正用 AMCL 定位）。
5. **nav2_client 只跑 40 秒**：書上完整跑「medical_shop → room → 回原點」送藥流程；這裡只確認它能連上 action server、收到 feedback。`nav2_bt_client` 只建置、沒執行（launch 檔會呼叫 Groot2 GUI，且依賴不存在的 `tb_worlds`）。
6. **DDS／探索**：依前面章節經驗用 CycloneDDS、`ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`、`lo` 開 multicast，所有查詢加 `--no-daemon` 或 `timeout`；背景 launch 用 `setsid` 開行程群組、結束時 `kill -- -PGID`。

## 踩到的坑

- `wsl.exe ... -- bash -c "nohup ... &"`：wsl.exe 一結束，背景行程跟著被收掉 → 改用 Claude Code 的背景執行功能整支跑。
- 本機 `cmd | tee log | head -400`：`head` 提早關管線會把 `tee` 也殺掉，log 只寫一半 → 輸出直接導到檔案再看。

## 已知未處理的風險

- 沒有驗證 AMCL 真正定位（需要發 `/initialpose`）。
- 目標點只選 1.5 m 外的近距離空地，沒測繞障礙／recovery 行為（`number_of_recoveries: 0`）。
