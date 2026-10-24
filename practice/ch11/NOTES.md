# K136 第 11 章快速演練：空中機器人（PX4 offboard 控制）

> 快速 demo 模式：未經 QA／審查。本機沒有 PX4 SITL、沒有飛控，改用「只建置＋假飛控」驗證 ROS 2 端的行為。

## 做了什麼

| 步驟 | 腳本 | 內容 |
| --- | --- | --- |
| 0 | `step0_explore.sh` | 讀書本 `Chapter11/px4_ctrl`（只有 `px4_ctrl.cpp`／`px4_ctrl.h`，沒有 launch 檔） |
| 1 | `step1_build.sh` | clone `px4_msgs`（`release/1.15`）到 `~/k136_ws/ch11/src`，複製 `px4_ctrl`，`colcon build --symlink-install` |
| 2 | `step2_run_alone.sh` | 完全沒有飛控時跑 `px4_ctrl` 10 秒，看它發了什麼 |
| 3 | `step3_with_fake_fcu.sh` + `fake_fcu.py` | 本演練新增的假飛控提供服務與位置，用 FIFO 餵選單指令 `arm → takeoff → move → disarm → exit`，`ros2 topic echo --once` 抓訊息 |
| 末 | `cleanup.sh` | 清殘留行程＋`timeout 15 ros2 daemon stop` |

### px4_msgs 分支選擇：`release/1.15`

- `px4_ctrl.h` 用到 `px4_msgs/srv/VehicleCommand`，服務名稱 `/fmu/vehicle_command`。
  PX4 的 uXRCE-DDS「vehicle_command 服務」是 **v1.15 才加入**的，`release/1.14` 以前的 px4_msgs 沒有 `srv/VehicleCommand.srv`。
- 書本 repo 最後 commit 是 2025-09，當時 PX4 的穩定版就是 v1.15，所以選 `release/1.15`（commit 見 `logs/step1_build.log`）。
- 實務原則：**px4_msgs 的分支必須與飛控韌體版本一致**，訊息定義不同 DDS 型別雜湊會對不上，收不到訊息。

## px4_ctrl.cpp 的 offboard 控制流程

```
main → Px4Control()（建構子）
  ├─ 建 client  /fmu/vehicle_command            (px4_msgs/srv/VehicleCommand)
  ├─ 建 pub     /fmu/in/trajectory_setpoint      (TrajectorySetpoint)
  ├─ 建 pub     fmu/in/offboard_control_mode     (OffboardControlMode，相對名稱→/fmu/in/…)
  ├─ ★ while(!wait_for_service(1s)) 一直等飛控的服務 ← 沒飛控就永遠卡在這
  └─ 建 sub     /fmu/out/vehicle_local_position  (QoS：BEST_EFFORT + TRANSIENT_LOCAL)
run()
  ├─ thread menu()
  │    ├─ thread publish_offboard_ctrl_mode()：1 Hz 發 OffboardControlMode{position=true}  ← 心跳
  │    └─ 讀 stdin 指令
  │         arm     → VehicleCommand(COMPONENT_ARM_DISARM, param1=1) 呼叫服務，等回應
  │         disarm  → 同上 param1=0
  │         takeoff → VehicleCommand(DO_SET_MODE, 1, 6)  （param1=1 自訂模式、param2=6 = PX4 OFFBOARD 主模式）
  │                   sleep 1 → 發一筆 TrajectorySetpoint{目前 x,y, z-5}（NED，z 往下為正，所以 -5 = 往上 5 m）
  │         move    → 讀「x y z」，planTrajectory() 以 v_max=0.5 m/s、dt=0.1 s 線性內插
  │                   10 Hz 逐點發 TrajectorySetpoint
  │         exit    → 離開選單（spin 仍在）
  └─ rclcpp::spin()：處理位置訂閱與服務回應 callback
```

三個重點：

1. **心跳（OffboardControlMode）**：PX4 要求 offboard 期間持續收到 OffboardControlMode（> 2 Hz），中斷就會觸發 offboard failsafe；
   而且「切進 offboard 前必須已經在收心跳／setpoint」。書上程式只發 **1 Hz**，低於 PX4 文件建議的 2 Hz，在真機/SITL 上可能被判定 offboard 訊號遺失（見下方「書上程式的問題」）。
2. **arm**：透過 `/fmu/vehicle_command` 服務送 `VEHICLE_CMD_COMPONENT_ARM_DISARM`，等 `VehicleCommandAck` 回來才繼續（`action_done_`）。
3. **setpoint**：`TrajectorySetpoint.position` 是 NED 座標；takeoff 只發「一筆」，之後就不再發，靠 PX4 保持最後一筆 setpoint。

### 書上程式的問題（只記錄、不修改原檔）

- 建構子內 `wait_for_service` 阻塞：沒有飛控／Agent 時節點一個訊息也不發，連心跳都沒有。
- 心跳 1 Hz 偏低（PX4 文件要求 ≥ 2 Hz）。
- `takeoff` 先切 OFFBOARD 才發第一筆 setpoint，PX4 可能拒絕切換（要先有 setpoint 串流）。
- `curr_x_/y_/z_` 沒初始化，還沒收到位置就 takeoff 會用到垃圾值。
- `srv_callback` 裡 `service_result_` 宣告但沒用（-Wunused 警告）；`menu` 的 `publish_offboard_ctrl_mode_t` thread 沒 join/detach，`exit` 後解構會 `std::terminate`。
- CMake 有 `find_package(Boost ...)` 但程式沒用到 Boost。

## 驗證結果

### 第 1 步：建置（`logs/step1_build.log`）

```
px4_msgs 版本：release/1.15 a1045ec
msg 數量：213（srv：VehicleCommand.srv、VtolVehicleCommand.srv…）
Finished <<< px4_msgs [6min 2s]
Finished <<< px4_ctrl [16.4s]
Summary: 2 packages finished [6min 18s]
```

px4_ctrl 有警告但無錯誤：`unused variable 'service_result_'`、`narrowing conversion ... double to float`（TrajectorySetpoint.position 是 float32[3]）。

### 第 2 步：沒有飛控，跑 10 秒（`logs/step2_run_alone.log`）

```
=== node list ===            /px4_ctrl
=== topic list ===           /fmu/in/offboard_control_mode
                             /fmu/in/trajectory_setpoint
=== echo --once /fmu/in/offboard_control_mode ===
（4 秒內沒有收到任何訊息）
[px4_ctrl]: service not available, waiting again...   ← 每秒一次，共 9 次
[px4_ctrl]: Interrupted while waiting for the service. Exiting.
terminate called after throwing an instance of 'rclcpp::exceptions::RCLError'  → core dump
```

結論：publisher 在 `wait_for_service` 之前就建立，所以主題「存在」，但**一筆 OffboardControlMode／TrajectorySetpoint 都沒發**。
被 timeout 送 SIGINT 後建構子 `return`，`main` 仍呼叫 `run()`，在已失效的 context 上建 thread／spin → `RCLError` core dump（書上程式又一個問題）。

### 第 3 步：加假飛控（`logs/step3_with_fake_fcu.log`）

心跳（arm 之前就在發，1 Hz）：

```
/fmu/in/offboard_control_mode
position: true
velocity: false
acceleration: false
attitude: false
body_rate: false
```

takeoff 那一筆 setpoint（NED，z=-5 表示往上 5 m）：

```
/fmu/in/trajectory_setpoint
position: [0.0, 0.0, -5.0]
yaw: 0.0
```

move 到 `3 0 -5`：`ros2 topic hz` 平均 7~8 Hz（含 move 前的空檔；move 期間實際 10 Hz），假飛控收到的點：

```
TrajectorySetpoint #10 position=[0.4, 0.0, -5.0]
TrajectorySetpoint #30 position=[1.4, 0.0, -5.0]
TrajectorySetpoint #60 position=[2.9, 0.0, -5.0]
```

假飛控收到的服務呼叫與統計：

```
收到 VehicleCommand：ARM
收到 VehicleCommand：DO_SET_MODE(param1=1, param2=6 → 6=OFFBOARD)
收到 VehicleCommand：DISARM
結束：OffboardControlMode 36 筆、TrajectorySetpoint 62 筆   （~36 秒 → 心跳確實 1 Hz）
```

送 `exit` 後 px4_ctrl 印出 `terminate called without an active exception`（`publish_offboard_ctrl_mode_t` thread 沒 join），證實上面列的問題。

### 清理（`logs/cleanup.log`）

見 log 最後一行「乾淨：無殘留」。

## 和書上做法的差異

| 書上 | 本演練 |
| --- | --- |
| 建 PX4-Autopilot、跑 `make px4_sitl gz_x500` 開 Gazebo 視窗 | **不建 PX4**（數 GB、> 1 小時），只建 `px4_msgs` + `px4_ctrl` |
| 跑 `MicroXRCEAgent udp4 -p 8888` 把 PX4 uORB 橋到 ROS 2 | 沒有 Agent；改寫 `fake_fcu.py` 假裝飛控端（服務＋位置） |
| 在終端機手打 `arm`、`takeoff`、`move` | 用 FIFO 從腳本餵 stdin |
| 看 Gazebo / QGroundControl 中無人機起飛 | 用 `ros2 topic echo --once`／`ros2 topic hz` 看 px4_ctrl 發出的訊息 |
| Fast DDS（預設） | Cyclone DDS + `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`（本機 WSL 實測規則） |

`fake_fcu.py` 不模擬動力學：位置直接跳到最後一筆 setpoint、所有指令一律回 ACCEPTED，只能驗證 ROS 2 介面與流程，**不能驗證飛行行為**。

## 完整 PX4 SITL 安裝步驟（只寫，不執行）

以下在 Ubuntu 24.04 + ROS 2 Jazzy + Gazebo Harmonic 環境：

```bash
# 1. 取 PX4 原始碼（版本與 px4_msgs 一致）
cd ~
git clone https://github.com/PX4/PX4-Autopilot.git --recursive -b release/1.15
# 2. 安裝工具鏈與 Gazebo（腳本會裝 gcc-arm、python 依賴、gz-harmonic；完成後需重開 shell）
bash ./PX4-Autopilot/Tools/setup/ubuntu.sh
# 3. 建置並啟動 SITL（x500 四旋翼 + Gazebo；首次建置約 20~60 分鐘）
cd ~/PX4-Autopilot
make px4_sitl gz_x500
#    無頭模式：HEADLESS=1 make px4_sitl gz_x500

# 4. 安裝並啟動 Micro XRCE-DDS Agent（PX4 uORB ⇄ ROS 2 的橋）
cd ~
git clone -b v2.4.2 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
cd Micro-XRCE-DDS-Agent && mkdir build && cd build
cmake .. && make -j$(nproc) && sudo make install && sudo ldconfig /usr/local/lib/
MicroXRCEAgent udp4 -p 8888        # PX4 SITL 啟動時會自動連 udp 8888

# 5. ROS 2 工作區：px4_msgs（同版本）+ px4_ctrl
mkdir -p ~/px4_ws/src && cd ~/px4_ws/src
git clone -b release/1.15 https://github.com/PX4/px4_msgs.git
cp -r <書本 repo>/Chapter11/px4_ctrl .
cd ~/px4_ws && colcon build --symlink-install && source install/setup.bash

# 6. 驗證橋接：應看到 /fmu/out/* 主題與 /fmu/vehicle_command 服務
ros2 topic list | grep fmu
ros2 topic echo --once /fmu/out/vehicle_status

# 7. 跑書上的節點並在選單輸入 arm → takeoff → move
ros2 run px4_ctrl px4_ctrl
```

注意事項：

- SITL 預設不需要 RC，但若要在沒有遙控器時 arm，可能需在 PX4 shell 設 `param set COM_RC_IN_MODE 4`（或 1.15 的 `COM_RCL_EXCEPT`）。
- 從 SITL 以外的機器連線時，要確認 `ROS_DOMAIN_ID` 與 PX4 的 `UXRCE_DDS_DOM_ID` 一致。
- GPU 不是必要，但 Gazebo 在 WSL 上無 GPU 會很慢；可用 `HEADLESS=1`。
