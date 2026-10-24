# K136 第 9 章快速演練：MoveIt 2 機械手臂（Panda）

> 快速 demo 模式：沒有經過 QA／審查。只用 mock 硬體（ros2_control `mock_components/GenericSystem`），沒開 RViz／Gazebo。

## 做了什麼

| 步驟 | 腳本 | 內容 |
| --- | --- | --- |
| 0 | `step0_explore.sh` | 看書本 `Chapter09` 結構，確認已裝 MoveIt 2.12.4／ros2_control 4.48 |
| 1 | `step1_build.sh` | 複製 `panda_description`、`panda_moveit_config`、`panda_moveit_control` 到 `~/k136_ws/ch09/src`，修正工作區複製檔（見「差異」），`colcon build --symlink-install`（3 個套件約 18 秒，只有 deprecation 警告） |
| 2 | `step2_mock_planning.sh` | 背景跑無頭 demo（`demo_headless.launch.py`：static TF＋robot_state_publisher＋move_group＋ros2_control_node＋spawner），依序跑三支規劃程式 |
| 3 | `step3_obstacles_fresh.sh` | 重開 demo，讓手臂回到 ready 姿態，單獨跑 `planning_with_obstacles`，執行中查 planning scene |
| 末 | `cleanup.sh` | 清掉殘留行程＋`timeout 15 ros2 daemon stop` |

執行紀錄在 `logs/`。`logs/run1_*` 是第一次失敗的紀錄（起始姿態超出關節限制，見下方），留著當對照。

## 驗證結果

### mock 硬體＋控制器

```
Loaded hardware 'FakeSystem' from plugin 'mock_components/GenericSystem'
Successful 'activate' of hardware 'FakeSystem'
name='joint_state_broadcaster' state='active'
name='arm_controller'          state='active'
/joint_states 初始：[0.0, -0.78, 0.0, -2.35, 0.0, 1.57, 0.78]
demo log 裡 rviz 字樣行數：0（RViz 沒啟動）
```

### 三支規劃程式

| 程式 | 規劃 | 規劃耗時 | 執行 | 說明 |
| --- | --- | --- | --- | --- |
| `joint_space_planning` | ✅ 2/2 次成功 | 2.4 ms、22.6 ms | ✅ 兩段各約 1.8 s，`Goal reached, success!` | 程式自己結束，牆鐘 7.5 s |
| `cartesian_space_planning` | ✅ `Computed Cartesian path with 78 points (followed 100%)` | 1 s 內 | ✅ `Execute request success!`，約 11.3 s | 程式最後 `rclcpp::spin` 不會自己結束，由 `timeout 60` 收掉（結束碼 124 是預期） |
| `planning_with_obstacles`（接在 cartesian 後跑） | ❌ `GOAL_STATE_INVALID` | — | — | 起點已被 cartesian 移動過，目標「末端 +0.3 m x」讓夾著的圓柱撞進桌子 |
| `planning_with_obstacles`（step3，從 ready 姿態重跑） | ✅ RRTConnect，`Motion plan was computed successfully` | 24.7 ms | ✅ 約 10.2 s，`Completed trajectory execution with status SUCCEEDED` | 啟動到完成 15.2 s；planning scene 查得到 `table`（世界物件）與 `grasp`（附著在 `hand`） |

關節空間規劃後手臂回到 ready 姿態；cartesian 之後是 `[-0.20, -1.41, 0.05, -2.55, 0.06, 1.15, 0.61]`；避障之後是 `[0.00, 0.17, 0.00, -1.44, 0.00, 1.61, 0.78]`。

## MoveIt 2 設定套件內容（`panda_moveit_config`）

由 MoveIt Setup Assistant 產生（`.setup_assistant` 記錄來源 URDF＝`panda_description/urdf/panda.urdf.xacro`）。

| 檔案 | 作用 | 本書內容重點 |
| --- | --- | --- |
| `config/panda.srdf` | 語意描述（URDF 沒有的資訊） | 規劃群組 `arm`＝joint1～7＋joint_base；virtual joint `virtual`（fixed）；39 組 `disable_collisions`（Adjacent／Never／Default，省掉不可能相撞的 link 對檢查）。沒定義 end effector 和命名姿態 |
| `config/kinematics.yaml` | IK 解算器 | `arm` 用 `kdl_kinematics_plugin/KDLKinematicsPlugin`，search resolution 0.005、timeout 0.005 s |
| `config/joint_limits.yaml` | 覆寫 URDF 的速度／加速度限制 | 7 軸 max_velocity 2.62～3.14 rad/s、max_acceleration 2.62；預設 scaling 0.1（程式裡 `setMaxVelocityScalingFactor(1.0)` 會蓋過） |
| `config/pilz_cartesian_limits.yaml` | Pilz 工業規劃器的笛卡兒限制 | 平移 1.0 m/s、旋轉 1.57 rad/s |
| `config/moveit_controllers.yaml` | MoveIt 端怎麼送軌跡 | `MoveItSimpleControllerManager` → `arm_controller`（FollowJointTrajectory，`follow_joint_trajectory` action） |
| `config/ros2_controllers.yaml` | ros2_control 端控制器 | 100 Hz；`arm_controller`＝JointTrajectoryController（position 命令、position＋velocity 狀態）、`joint_state_broadcaster` |
| `config/panda.ros2_control.xacro`＋`panda.urdf.xacro` | 把 mock 硬體接上 URDF | `mock_components/GenericSystem`，初值讀 `initial_positions.yaml` |
| `config/sensors_3d.yaml` | 3D 感測器（octomap） | 點雲 `/depth_camera/points`、深度影像。本機沒裝 `moveit_ros_perception` 外掛，move_group 會印兩行 ERROR 但不影響規劃 |
| `launch/*.launch.py` | Setup Assistant 標準 launch | `demo`、`move_group`、`rsp`、`spawn_controllers`、`static_virtual_joint_tfs`、`moveit_rviz`、`warehouse_db`、`setup_assistant` |

move_group 實際載入 3 條規劃管線：OMPL（預設，`arm` 用 RRTConnect）、Pilz Industrial Motion Planner、STOMP。

## 和書上做法的差異

1. **不開 RViz**：書上用 `demo.launch.py`（會開 RViz）。這裡寫了 `demo_headless.launch.py`，先 `SetLaunchConfiguration("use_rviz", "false")` 再交給同一個 `generate_demo_launch`，其他照書。
2. **沒跑 Gazebo 版**（`panda_gazebo*.launch.py`）：URDF 帶 D435 彩色／深度相機感測器，WSL 沒 GPU，太重。依指示只做 mock 版。
3. **工作區複製檔的修改**（書本 repo 原檔沒動，全部標「本演練改」）：
   - `panda_arm.xacro` 無條件寫入 Gazebo 專用的 `ros2_control`（`2DofPosition`／`gz_ros2_control/GazeboSimSystem`）。mock 環境載不到這個外掛，**整組硬體初始化失敗、沒有 `/joint_states`**。改法：用新的 xacro 參數 `gz_control` 包起來；`panda_description` 預設 true（Gazebo 版不變），`panda_moveit_config/config/panda.urdf.xacro` 在 include 前宣告 false。
   - `initial_positions.yaml` 原本全 0，但 Panda joint4 合法範圍約 [-3.07, -0.07]。move_group 的 `CheckStartStateBounds` 回 `Start state out of bounds`，**每次規劃都失敗**（`logs/run1_*`）。改成和 Gazebo 版相同的 ready 姿態（joint2=-0.78、joint4=-2.35、joint6=1.57、joint7=0.78）。
   - 三支 `panda_moveit_control` launch 寫死 `use_sim_time: True`（給 Gazebo 用）。mock 沒有 `/clock`，改成 False。
4. **planning_with_obstacles 要從 ready 姿態跑**：接在 cartesian 後面跑會 `GOAL_STATE_INVALID`（目標是相對目前末端位置算的）。書上每支程式都是重開模擬再跑，step3 照這樣做就成功。
5. **觀察到的書本小問題**（沒修，不影響結果）：
   - SRDF virtual joint 寫成 `parent_frame="link0" child_link="world"`，和 URDF 的 world→link0 方向相反。`static_virtual_joint_tfs` 發出 link0→world，cartesian 程式第一次查 TF 時出現 `tf tree is invalid because it contains a loop`，重試一次後就查到了。
   - `computeCartesianPath` 用了舊版含 `jump_threshold` 的多載（deprecated 警告）；`cartesian_space_planning` 收到 SIGINT 時 `terminate called without an active exception`（規劃 thread 沒 join），exit code -6。
6. 環境照前幾章踩坑經驗設定：CycloneDDS、`ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`、lo multicast、查詢加 `--no-daemon`、`list_controllers` 改用 service call、背景用 `setsid`＋整個行程群組一起 kill。

## 清理

`cleanup.sh` 輸出：`沒有殘留的 ROS／Gazebo 行程` → `乾淨：無殘留`，`ros2 daemon stop` 用 timeout 15 包住（daemon 本來就沒在跑）。
