# K136 第 12 章快速演練：DIY 移動機器人

> 快速 demo 模式，未經 QA／審查。WSL Ubuntu-24.04 + ROS 2 Jazzy，工作區 `~/k136_ws/ch12`，無任何硬體。

## 做了什麼

| 步驟 | 腳本 | 內容 |
| --- | --- | --- |
| 0 | `step0_explore.sh`、`step0b_details.sh` | 讀書本 `Chapter12`：`mobile_robot_model`（URDF + 兩個只有 robot_state_publisher 的 launch）、`ldlidar_sl_ros2`（LD14P 驅動）、`rf2o_laser_odometry` |
| 1 | `step1_build.sh` | 複製三個套件到 `~/k136_ws/ch12/src`，補裝 `tf2_tools`／`graphviz`／`poppler-utils`，`colcon build --symlink-install` |
| 2 | `step2_tf_tree.sh` | 跑書上的 `display.launch.py`（本來就沒開 RViz，不用改），`tf2_echo` + `view_frames` 產 PDF，`pdftoppm` 轉 PNG |
| 3 | `fake_scan.py`、`step3_fake_scan_rf2o.sh` | 假 LiDAR 節點取代 `ldlidar_sl_ros2_node`，餵給書上的 `rf2o_laser_odometry.launch.py`，記錄 `/odom` |
| 3c | `step3c_fov270.sh` | 對照實驗：假 scan 改成前方 270°（查 `/odom` 方向問題） |
| 3b/3d | `step3b_inspect_rf2o.sh`、`step3d_inspect_ranges.sh` | 讀 rf2o 原始碼的角度與 ranges 處理 |
| 末 | `cleanup.sh` | 清殘留行程 + `timeout 15 ros2 daemon stop` |

### 假 LiDAR（`fake_scan.py`）

- 6 m × 4 m 矩形房間（牆在 x=±3、y=±2），10 Hz，frame `base_laser`（和書上 `ld20.launch.py` 一致）。
- 預設 360 束、360°（對應 LD14P），雜訊 σ=3 mm；`FAKE_FOV_DEG` 環境變數可改視角。
- 先靜止 5 秒，再以 0.05 m/s 沿 +x 平移 40 秒（共 2.0 m），每秒印出真值位移。

## 驗證結果

### 建置

```
Finished <<< mobile_robot_model [3.93s]
Finished <<< ldlidar_sl_ros2 [15.6s]
Finished <<< rf2o_laser_odometry [36.1s]
Summary: 3 packages finished [36.3s]
```

### TF 樹（`logs/tf/frames.png`、`frames.pdf`）

所有關節都是 fixed，`base_footprint` 底下掛 5 個子 frame：

```
"base_footprint" -> "Raspberry"
"base_footprint" -> "base_laser"
"base_footprint" -> "omniwheel"
"base_footprint" -> "wheel_left"
"base_footprint" -> "wheel_right"
```

`tf2_echo base_footprint base_laser`：`Translation: [0.070, 0.004, 0.013]`，和 URDF 的 `base_link_to_lidar` 一致。
（URDF 開頭 `base_footprint → base_link` 那段被註解掉了，所以樹裡沒有 `base_link`；書上是用 `ld20.launch.py` 的 static TF 補 `base_footprint → base_link`。）

### 假 /scan → rf2o → /odom

```
/scan average rate: 10.002     /odom average rate: 9.965
node list: /fake_scan /rf2o_laser_odometry /robot_state_publisher ...
```

| 實驗 | 真值位移 | rf2o `/odom` 終值 | 誤差（大小） | y／yaw 漂移 |
| --- | --- | --- | --- | --- |
| 360°（`logs/step3_*`） | x **+2.000** m | x **-2.178** m | 約 +9% | y -0.03 m、yaw 0.9° |
| 270°（`logs/step3_fov270_*`） | x **+2.000** m | x **-2.140** m | 約 +7% | y -0.15 m、yaw 6.2° |

`/odom` x 取樣（360°）：`-0.28 → -0.45 → -0.79 → … → -1.94 → -2.10 → -2.174`（停止後保持不動）。

**結論**：rf2o 確實只靠雷射掃描估出「等速移動、停下後不動」，移動量大小相近；但 **x 方向和真值相反**。

#### 方向相反的排查（快速模式，試 3 次後停）

1. 懷疑 360° 頭尾相接 → 改 270° 前方掃描，仍然反向，排除。
2. 讀 rf2o 原始碼：角度用 `tita = -fovh/2 + u·fovh/(N-1)`（假設掃描以正前方為中心、逆時針），`ranges` 直接照順序讀，和假 scan 的格式一致。
3. 假 scan 的幾何：往 +x 走時，正前方（角度 0）距離 `3 - x` 確實在變短，模擬本身沒錯。

未解決。可能原因（未驗證）：這個 ROS 2 移植版的位姿更新符號慣例，或假 scan 是完全理想的矩形房間（只有 4 面牆，特徵少）。要在真機或 Gazebo 的 `gpu_lidar` 上比對才能確定。如果真機也反向，可以在 `ld20.launch.py` 用 `laser_scan_dir`，或把雷射 TF 轉 180°（rpy `0 0 π`）來修正。

## 和書上做法的差異

| 書上 | 本演練 |
| --- | --- |
| 樹莓派 4/5 跑 Ubuntu + ROS 2，裝在車上 | WSL Ubuntu 24.04 / Jazzy，沒有任何車體 |
| LDROBOT LD14P LiDAR（`/dev/ttyUSB0`、230400 baud）+ udev rules | 只建置 `ldlidar_sl_ros2`，**不執行**；以 `fake_scan.py` 發假 `/scan` |
| 馬達驅動板 + 編碼器直流馬達 + 微控制器跑 micro-ROS，接收 `/cmd_vel`、回傳輪速 | **整段略過**（見下） |
| RViz 看機器人模型與雷射點雲 | 不開圖形視窗：`tf2_echo`、`view_frames` → PDF/PNG、`topic hz/echo` |
| Fast DDS | Cyclone DDS + `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`（本機實測規則） |

### 書上的硬體清單（本演練全部沒有）

- **主控**：Raspberry Pi（URDF 裡的 `Raspberry` link 就是它的位置）。
- **感測**：LDROBOT LD14P 2D LiDAR（USB 轉序列）。
- **底盤**：兩個驅動輪（`wheel_left`／`wheel_right`）+ 一個萬向輪（`omniwheel`）的差速底盤。
- **動力**：直流馬達 + 編碼器、馬達驅動板、電池（型號依書上清單，本機沒有書本內文可對照）。
- **低階控制**：微控制器跑 micro-ROS client，透過序列埠連到樹莓派上的 micro-ROS agent。

### 為什麼略過 micro-ROS 部分

1. 需要實體微控制器燒錄韌體並用 USB 序列連線，WSL 裡沒有這塊板子，也沒有馬達可驅動。
2. micro-ROS agent 可以在 WSL 跑起來，但沒有 client 連進來，只能看到「等待連線」，驗證不到任何東西。
3. 本章能在無硬體下驗證的重點是「URDF/TF 樹」和「只靠雷射估里程計（rf2o）」，這兩段都做了。
4. 第 11 章已經做過同類「XRCE-DDS agent + 無硬體」的情況，結論相同。

## 其他觀察

- rf2o 節點在 node list 會出現兩次 `/rf2o_laser_odometry`（節點內部又建了一個同名節點），會有 `share an exact name` 警告，不影響 `/odom`。
- `ros2 topic hz` 不支援 `--no-daemon`（第一輪 360° 實驗的 hz 因此沒量到，270° 那輪已修正）。
- 這次清理時沒有殘留行程（`logs/cleanup.log`：乾淨：無殘留）。
