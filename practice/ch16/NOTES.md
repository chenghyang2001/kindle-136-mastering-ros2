# K136 第 16 章：視覺化與模擬外掛（快速演練）

> 快速 demo 模式，未經 QA／審查。ROS 2 Jazzy + Gazebo Harmonic（gz-sim8），在 WSL Ubuntu-24.04 執行，工作區 `~/k136_ws/ch16`。

## 做了什麼

| 步驟 | 腳本 | 內容 | 結果 |
| --- | --- | --- | --- |
| 1 | `step1_build.sh` | 複製 `circle_msgs`、`circle_display_plugin`、`cmd_vel`、`cmd_vel_plugin` 到工作區，`colcon build --symlink-install` | ✅ 4 個套件全部建置成功（約 1 分鐘，只有 unused parameter 警告） |
| 2 | `step2_check_plugins.sh` | 不開 RViz／rqt，用 `ros2 pkg prefix`、ament index、plugin XML、`nm` 符號確認外掛有匯出 | ✅ RViz display、rqt panel 都已註冊 |
| 3 | `step3_gazebo.sh` | Gazebo server 模式跑 `cmd_vel_plugin.launch.py`，從 ROS 發 `/cmd_vel_from_ros`，看 gz `/cmd_vel` 和里程計 | ✅ 外掛收到 ROS 指令、限速後發到 gz，模型有移動 |
| 末 | `cleanup.sh` | 清殘留行程＋`timeout 15 ros2 daemon stop` | ✅ `NO_LEFTOVER` |

執行紀錄都在 `logs/`。

## 驗證結果（關鍵輸出）

### RViz display plugin（circle_display_plugin）

```
[rviz_common] circle_display_plugin 已註冊，prefix=~/k136_ws/ch16/install/circle_display_plugin
<class type="rviz_circle_plugin::CircleDisplay" base_class_type="rviz_common::Display">
T rviz_circle_plugin::CircleDisplay::processMessage(std::shared_ptr<circle_msgs::msg::Circle_ ...>)
```

### rqt panel plugin（cmd_vel）

```
[rqt_gui] cmd_vel 已註冊，prefix=~/k136_ws/ch16/install/cmd_vel
<class name="cmd_vel/CmdVel" type="cmd_vel::CmdVel" base_class_type="rqt_gui_cpp::Plugin">
T cmd_vel::CmdVel::initPlugin(qt_gui_cpp::PluginContext&)
```

說明：ament index 的資源名稱是 `<base>__pluginlib__plugin`（例如 `rviz_common__pluginlib__plugin/circle_display_plugin`），內容是 plugin XML 的相對路徑。RViz／rqt 啟動時就是靠這份索引找到外掛。腳本一開始寫成 `__pluginclasses` 找不到檔案，修正後通過。

### Gazebo 系統外掛（cmd_vel_plugin / CmdVelPlugin）

```
gz topic -l            → /cmd_vel、/model/diff_drive/odometry
ros2 node list         → /cmd_vel_plugin（外掛內部的 rclcpp 節點）、/robot_state_publisher、/ros_gz_bridge
/cmd_vel_from_ros      → Subscription count: 1
發 ROS Twist x=0.5, z=0.3 後，gz /cmd_vel 收到：linear { x: 0.2 }  angular { z: 0.3 }   ← 外掛把 x 限到 0.2
移動前 odometry position: x≈0,     y≈0
移動後 odometry position: x≈-0.61, y≈0.94   ← 繞圈移動約 1.1 m
移動後速度: linear.x=0.19999, angular.z=0.29999
```

資料流：`ROS /cmd_vel_from_ros` →（CmdVelPlugin：rclcpp 訂閱＋限速）→ `gz /cmd_vel`（gz-transport）→ DiffDrive 系統 → 模型移動 → odometry 經 ros_gz_bridge 回到 ROS。

## RViz plugin 與 Gazebo plugin 寫法差異

| 項目 | RViz display／rqt panel（pluginlib） | Gazebo 系統外掛（gz-plugin） |
| --- | --- | --- |
| 載入機制 | ROS 的 **pluginlib / class_loader** | Gazebo 的 **gz-plugin**，和 ROS 無關 |
| 基底類別 | `rviz_common::MessageFilterDisplay<MsgT>`（display）、`rqt_gui_cpp::Plugin`（rqt） | `gz::sim::System` 加上 `ISystemConfigure`、`ISystemPreUpdate`／`ISystemPostUpdate` 等介面 |
| 註冊巨集 | `PLUGINLIB_EXPORT_CLASS(Class, Base)` | `GZ_ADD_PLUGIN(Class, gz::sim::System, Class::ISystemConfigure, ...)`（.so 裡有 `GzPluginHook` 符號） |
| 描述檔 | 必須有 plugin XML（`<library path><class type base_class_type>`） | 不需要 XML |
| CMake 匯出 | `pluginlib_export_plugin_description_file(rviz_common xxx.xml)`，產生 ament index 資源 | 不用匯出；只要 `.so` 能被找到 |
| 怎麼被找到 | 宿主（RViz／rqt）掃 ament index 列出外掛，使用者在 GUI 裡選「Add」 | SDF／URDF 的 `<gazebo><plugin filename="CmdVelPlugin" name="cmd_vel_plugin::PubCmdVel">` 指定，`.so` 所在目錄要放進 `GZ_SIM_SYSTEM_PLUGIN_PATH` |
| 執行時機 | Qt 事件迴圈；display 收到訊息時呼叫 `processMessage()`，用 Ogre 畫圖 | 模擬迴圈每一步呼叫 `PreUpdate`／`PostUpdate`，`Configure` 只在載入時跑一次 |
| 和 ROS 溝通 | 宿主本身就是 ROS 節點，外掛直接用宿主的 node 訂閱／發布 | Gazebo 不是 ROS 節點：外掛要自己 `rclcpp::init` + 建 node，在 `PostUpdate` 裡 `spin_some`；Gazebo 內部則用 `gz::transport::Node` 發 gz 訊息 |
| Qt | 要 `Q_OBJECT` + `qt5_wrap_cpp`（MOC）；rqt 還要 `qt5_wrap_ui` 編 `.ui` | 不需要 Qt |

## 和書上做法的差異

1. **不開 GUI**：沒有啟動 RViz、rqt，改用 ament index、plugin XML、`nm` 符號驗證外掛已註冊。沒有實際在 RViz 裡顯示圓形，也沒有在 rqt 按按鈕（所以 `circle_display` 的繪圖、`cmd_vel` panel 的按鈕邏輯沒被執行到）。
2. **Gazebo server 模式**：工作區複製的 `cmd_vel_plugin.launch.py` 把 `gz_args` 從 `-r -v 4 empty.sdf` 改成 `-s -r -v 2 empty.sdf`（檔內有註明「本演練改」）。書本 repo 原檔沒動。
3. **用 `ros2 topic pub` 代替 rqt panel**：書上用 `cmd_vel` rqt 外掛發速度，這裡直接在指令列發 `/cmd_vel_from_ros`。
4. **環境設定**：加了 `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`、`ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`、`GZ_IP=127.0.0.1`，以及前幾章的 daemon 迴避做法（`--no-daemon`）。
5. **launch 一定要在工作區根目錄執行**：launch 用 `os.getcwd()/build/cmd_vel_plugin` 設 `GZ_SIM_SYSTEM_PLUGIN_PATH`，換目錄就找不到 `libCmdVelPlugin.so`。書上也這樣，但沒特別提醒。

## 觀察到的小問題（沒修，照書執行）

- `pub_cmd_vel.cpp` 的角速度限制有 bug：`else if (vrot_z < -0.5) vrot_z = 0.5;` 應該是 `-0.5`，向右大轉彎會變成向左轉。
- URDF 用舊名 `libignition-gazebo-diff-drive-system.so`，Harmonic 會印 deprecated 警告並自動換成 `libgz-sim-diff-drive-system.so`，不影響執行。
- launch 的 bridge 用 `@`（雙向），odometry 會同時建立 GZ→ROS 和 ROS→GZ 兩個橋接，只需要單向 `[`。
- `robot_state_publisher` 警告 root link 有慣量（KDL 不支援），不影響本章。
