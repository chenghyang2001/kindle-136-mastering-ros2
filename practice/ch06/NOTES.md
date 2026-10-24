# K136 第 6 章演練筆記：ros2_control 與自訂控制器（快速模式）

環境：Windows 11 → WSL Ubuntu-24.04、ROS 2 Jazzy、Gazebo Harmonic（gz sim 8，server 模式）、CycloneDDS、`ROS_DOMAIN_ID=36` + LOCALHOST 探索。
WSL 工作區：`~/k136_ws/ch06`（書本 repo 的 `Chapter06/two_joints_robot`、`sine_ctrl` 複製進來，原檔沒改）。

## 做了什麼

| 腳本 | 內容 | 紀錄 |
| --- | --- | --- |
| `step0_explore.sh` | 看兩個套件的 launch／URDF／yaml／cpp | `logs/step0_explore.log` |
| `step1_build.sh` | 複製套件、在工作區副本做「本演練改」、`colcon build --symlink-install` | `logs/step1_build.log` |
| `step2_sine.sh` | 背景跑 `start_simu.launch.py`（timeout 150），查控制器與硬體介面，把 `position_control` 換成 `sine_controller`，發布 `/sine_param`，錄 `/joint_states` 8 秒 | `logs/step2_sine.log`、`logs/step2_launch.log`、`logs/joint_states*.csv` |
| `step3_prismatic_diag.sh` | 診斷滑動關節卡在上限：閒置時、用 `position_control` 送指令時各錄一段 | `logs/step3_*.log`、`logs/diag_*.csv` |
| `record_joint_states.py` | 訂閱 `/joint_states` N 秒，存 CSV，印每個關節的最小／最大值 | — |
| `cleanup.sh` | 停掉殘留行程、`ros2 daemon stop`，最後檢查 | `logs/cleanup.log` |

## 驗證結果

**控制器（切換前）**，用 `ros2 service call /controller_manager/list_controllers` 查：

```
position_control         active    forward_command_controller/ForwardCommandController
joint_state_broadcaster  active    joint_state_broadcaster/JointStateBroadcaster
velocity_control         inactive  forward_command_controller/ForwardCommandController
sine_controller          inactive  sine_controller/SineController
```

**硬體介面**（`list_hardware_interfaces`）：command 介面有 `base_joint/{position,velocity}`、`link1_link2/{position,velocity}`，其中兩個 position 被 `position_control` 佔用（`is_claimed=True`）。state 介面有每個關節的 position／velocity／effort，全部是 `double`。

**切換**：`switch_controller` 一次停 `position_control`、啟動 `sine_controller` → `ok=True, 'Successfully switched controllers!'`，之後 `sine_controller` 變 `active`。兩者都要寫 `*/position`，所以不能同時 active，一定要一停一啟。

**plugin 名稱**：`sine_controller.xml` 裡是 `sine_controller/SineController`（`type="sine_controller::SineController"`，base class 是 `controller_interface::ControllerInterface`），跟 `controller.yaml` 的 `type:` 一致。

**正弦運動**（`/sine_param` = `[振幅0, 頻率0, 振幅1, 頻率1]`）：

| 測試 | `/sine_param` | base_joint（rad） | link1_link2（m） |
| --- | --- | --- | --- |
| 兩軸都動 | `[0.5, 0.5, 0.2, 0.5]` | min 0.8208 / max 1.7792，中心 1.30，半振幅 0.479；穿越中心 8 次／8 秒 → **0.500 Hz** | 卡在 0.3000（上限） |
| 只動滑動關節 | `[0.0, 0.0, 0.2, 0.5]` | 固定 1.3000 | min -0.1896 / max 0.1896，半振幅 0.190 |

取樣（每 0.5 秒一筆）可以看到 base_joint 照 1.047 → 1.707 → 1.553 → 0.893 → 1.047 重複，週期 2 秒。中心就是 URDF 設的 `initial_value 1.3`，因為控制器在 `on_activate` 把當時的位置記成正弦的中心。

**滑動關節卡在上限的原因**：`step3` 確認模擬端沒問題，閒置時是 0.0，用 `position_control` 送 `-0.2` 也確實到 -0.2。加了一行 log 後，`on_activate` 讀到的初始值也正確（`init0=1.3 init1=0.0`）。只動滑動關節時它也照正弦擺動。所以原因是 base_joint 旋轉產生的離心力把 link2 甩到 +0.3 的極限，屬於這個模型的動力學耦合（gz_ros2_control 的 `position_proportional_gain` 只有 0.1），不是控制器的錯。

**清理**：`cleanup.sh` → 「乾淨：無殘留」，最後執行了 `timeout 15 ros2 daemon stop || true`。

## controller plugin 的生命週期（以 SineController 為例）

ros2_control 的控制器是 lifecycle node，由 controller_manager 透過 pluginlib 載入（`PLUGINLIB_EXPORT_CLASS` + `sine_controller.xml` + CMake 的 `pluginlib_export_plugin_description_file`）。

| 階段 | 觸發 | SineController 做的事 |
| --- | --- | --- |
| `on_init` | load（spawner 載入時） | 什麼都不做，直接回 SUCCESS（通常在這裡宣告參數） |
| `command_interface_configuration` / `state_interface_configuration` | configure／activate 前由 controller_manager 詢問 | 用 `INDIVIDUAL` 列出要的介面：寫 `base_joint/position`、`link1_link2/position`；讀兩個關節的 position＋velocity |
| `on_configure` | unconfigured → inactive（`spawner --inactive` 停在這裡） | 建 `/sine_param` 訂閱、用 `get_update_rate()` 算 `dt_`、振幅和頻率歸零、準備介面名稱表 |
| `on_activate` | inactive → active（`switch_controller`） | 這時介面才「借」給控制器：用 `get_ordered_interfaces` 排序 state 介面，記下目前位置當正弦中心，`t_ = 0` |
| `update(time, period)` | active 期間每個控制週期（100 Hz）在 real-time 迴圈呼叫 | `t_ += dt`，`目標 = 初始 + A·sin(2πf·t)`，寫進 command 介面 |
| `on_deactivate` | active → inactive | 回 SUCCESS；介面還回去，讓別的控制器（例如 position_control）可以接手 |

重點：

- `/sine_param` 的 callback 不在 real-time 迴圈裡，只改成員變數，`update()` 下一個週期才會讀到。正式寫法應該用 `realtime_tools::RealtimeBuffer`，書上直接共用變數。
- `update()` 丟出例外或回 ERROR，controller_manager 會強制 deactivate 這個控制器（本次第一次執行就遇到，見下）。

## 和書上做法的差異

1. **Gazebo 改 server 模式**：工作區副本的 launch，`gz_args` 從 `' -r -v 4 empty.sdf'` 改成 `' -s -r -v 4 empty.sdf'`（本演練改），不開 GUI。
2. **`ros2 control load_controller` 換成 `ros2 run controller_manager spawner`**（`--inactive` 對應原本的 `--set-state inactive`），因為本機 daemon 會卡死。查詢和切換改用 `ros2 service call /controller_manager/{list_controllers,list_hardware_interfaces,switch_controller}`。
3. **sine_controller.cpp 修正（Jazzy 相容）**：書上把 `float` 傳給 `command_interfaces_[i].set_value()`。Jazzy 的 `set_value` 是樣板，執行期會檢查型別，丟出 `Invalid data type : 'float' access for interface : base_joint/position expected : 'double'`，控制器啟動後第一個 update 就被停用。工作區副本改成 `(void)...set_value(static_cast<double>(...))`。另外加了一行 `[k136]` 診斷 log。`get_value()` 的 deprecated 警告沒處理（Jazzy 還能用，Kilted 會移除）。
4. **書上沒寫要送 `/sine_param`**：控制器在 `on_configure` 把振幅歸零，不發布參數的話 active 了也不會動。本演練用 `ros2 topic pub` 送 2 Hz、持續 4 秒。
5. **launch 沒有橋接 `/clock`**：`/joint_states` 的 `header.stamp` 全是 0（log 會一直出現「No clock received」）。錄製程式改用接收時的 wall time 算時間軸，沒有額外加 bridge。
6. 沒跑 `display.launch.py`（需要 joint_state_publisher_gui 和 RViz）。
7. 書上的 launch 重複定義了 `load_velocity_controller` 兩次（只 add 一次），沒影響，維持原樣。
