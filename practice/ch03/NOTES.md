# K136 第 3 章 快速演練：實作 ROS 2 觀念

> 快速 demo 模式：只求跑通、看懂流程，未經 QA／審查。

## 做了什麼

| 步驟 | 腳本 | 內容 | log |
| --- | --- | --- | --- |
| 0 | `step0_explore.sh` | 瀏覽書本 `Chapter03`（只讀） | `logs/step0_explore.log` |
| 1 | `step1_build.sh` | 複製 `master_ros2_interface`、`master_ros2_pkg` 到 `~/k136_ws/ch03/src`，`colcon build --symlink-install` | `logs/step1_build.log` |
| 2 | `step2_interfaces.sh` | `ros2 interface show` 看自訂 msg／srv／action | `logs/step2_interfaces.log` |
| 3 | `step3_pub_sub.sh` | `pub_sub.launch.py`（timeout 15）＋ node list／topic info -v／topic echo --once | `logs/step3_pub_sub.log` |
| 4 | `step4_params.sh` | `pub_params_sub.launch.py`（timeout 15）＋ param list／get／set | `logs/step4_params.log` |
| 5 | `step5_service.sh` | `server_client.launch.py`（timeout 15）＋手動 `ros2 service call` | `logs/step5_service.log` |
| 6 | `step6_action.sh` | `action_server_client.launch.py`（timeout 15）＋手動 `ros2 action send_goal --feedback` | `logs/step6_action.log` |
| 末 | `cleanup.sh` | 停殘留行程＋`timeout 15 ros2 daemon stop` | `logs/cleanup.log` |
| 除錯 | `debug_*.sh` | 查 service 連不上的原因（見下方「踩坑」） | `logs/debug_*.log` |

## 驗證結果

**建置**：2 個套件 54 秒建完，7 個執行檔（只有 `action_server.cpp` 未使用參數的警告）。

```
Summary: 2 packages finished [54.1s]
action_client action_server publisher_node publisher_node_params simple_client simple_server subscriber_node
```

**自訂介面**（`ros2 interface show`）：

```
CustomMsg:       string data / int32 number
ConcatStrings:   string str1, string str2 --- string concatenated_str
MyCustomAction:  int32 goal_value --- int32 result_value --- float32 progress
```

**Topic（pub_sub）**：兩個 topic 每秒一筆，QoS 為 RELIABLE + TRANSIENT_LOCAL。

```
[publisher_node]: Publishing custom message: data='Custom Hello', number=42
[subscriber_node]: Received custom message: data='Custom Hello', number=42
ros2 topic echo --once /custom_topic → data: Custom Hello / number: 42
```

**Parameter（pub_params_sub）**：`param set` 成功，新值**只出現一拍**就被改回來。

```
param list → custom_number, custom_string, qos_overrides..., use_sim_time
param get custom_string → Hello String
param set custom_string "Set from CLI" → Set parameter successful
param set custom_number 99             → Set parameter successful
[publisher_node]: Publishing custom message: data='Set from CLI', number=42
[publisher_node]: Publishing custom message: data='Hello String', number=42   ← 被程式碼改回
[publisher_node]: Publishing custom message: data='Hello String', number=99
[publisher_node]: Publishing custom message: data='Hello String', number=42   ← 被程式碼改回
```

原因：`publisher_node_params.cpp` 每次 timer 回呼結尾都呼叫 `set_parameter("custom_string","Hello String")`、`set_parameter("custom_number",42)`，所以外部設定只撐一個週期。第一拍是宣告時的預設值 `Hello World`。

**Service**：

```
launch：[simple_client]: Result: concatenated_str='Hello, World!'
手動：ros2 service call /concat_strings ... "{str1: 'K136 ', str2: 'Chapter03'}"
      → concatenated_str='K136 Chapter03'
```

**Action**：

```
launch：Received goal request with value 10 → Feedback: 1.00 … 10.00（每 0.5 秒）→ Result: 10
手動：ros2 action send_goal --feedback /my_custom_action ... "{goal_value: 4}"
      → progress 1.0~4.0 → result_value: 4 → Goal finished with status: SUCCEEDED
```

**清理**：`乾淨：無殘留`。

## 四種通訊的程式結構重點

| 觀念 | 建立方式（rclcpp） | 重點 |
| --- | --- | --- |
| Topic | `create_publisher<T>(topic, qos)`＋`create_wall_timer` 定時 `publish()`；`create_subscription<T>(topic, qos, callback)` | 非同步、一對多。兩邊 QoS 要相容；本例用 `KeepLast(10).reliable().transient_local()`，晚加入的訂閱者也能補收最近 10 筆 |
| Parameter | `declare_parameter<T>(name, 預設值)`；`get_parameter(name, 變數)`；`set_parameter(rclcpp::Parameter(...))` | 每個節點自帶 `list/get/set_parameters` 等 service，CLI 就是透過它們改值；要先 declare 才能設。要對外部修改做出反應應該用 `add_on_set_parameters_callback`，不要在 timer 裡覆寫 |
| Service | server：`create_service<Srv>(name, callback(req, res))`；client：`create_client<Srv>` → `wait_for_service` → `async_send_request` → `spin_until_future_complete` | 同步的一問一答，適合短時間的計算。本例 client 送一次就結束（launch 顯示 `process has finished cleanly`） |
| Action | server：`rclcpp_action::create_server`，給 `handle_goal`／`handle_cancel`／`handle_accepted` 三個回呼，在另開的執行緒跑 `execute()` 送 feedback、最後 `succeed(result)`；client：`create_client` → `async_send_goal`，用 `SendGoalOptions` 掛 feedback／result 回呼 | 長時間任務，有進度回報、可取消。底層是 3 個 service（送目標、取消、取結果）加 2 個 topic（feedback、status）。`execute` 要另開執行緒，否則會卡住 executor |

其他觀察：

- launch 檔用 `name='publisher_node'` 覆寫了程式裡的節點名 `publisher_node_params`，所以 CLI 要對 `/publisher_node` 下參數指令。
- 自訂介面套件要用 `rosidl_generate_interfaces` 並在 `package.xml` 加 `<member_of_group>rosidl_interface_packages</member_of_group>`；C++ 標頭是 snake_case（`my_custom_action.hpp`）。

## 和書上做法的差異

1. **環境**：書上用 Docker 容器，這裡用 WSL2 Ubuntu 24.04 + ROS 2 Jazzy 原生安裝；工作區是 `~/k136_ws/ch03`（書本 repo 原檔不動）。
2. **launch 都包 `timeout 15`**，手動呼叫時另外單獨啟 server（背景＋記 PID＋kill）。
3. **RMW 改用 Cyclone DDS**（本演練改，書上用預設的 Fast DDS）：
   - 每支腳本加 `export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`，並裝了 `ros-jazzy-rmw-cyclonedds-cpp`。
   - 每支腳本開頭補 `sudo ip link set lo multicast on`（WSL 的 lo 預設沒開 multicast；WSL 重啟就失效，所以每次都檢查）。
4. 依前面章節的坑，所有腳本都加 `ROS_DOMAIN_ID=36`＋`ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`，查詢指令加 `--no-daemon` 或 `timeout`。

## 踩坑（本機實測）

| 現象 | 嘗試 | 結果 |
| --- | --- | --- |
| 預設 Fast DDS：pub/sub 要等約 6～9 秒才連上（訂閱者一次補收 8 筆舊訊息）；`server_client` 的 client 拿不到回應；`ros2 service call` 45 秒都等不到服務；`ros2 service list` 看不到 server 節點 | ① 清 `/dev/shm/fastrtps_*` 舊檔 | 無效 |
| 同上 | ② `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` | 時好時壞（`debug_service2.log` 成功一次，正式重跑又失敗） |
| 同上 | ③ 打開 lo multicast | 單獨開仍失敗 |
| 同上 | ④ 改 `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` | **成功**：service call 1 秒回應，pub/sub 同一毫秒收到 |

- `ros2 action list` **不支援 `--no-daemon`**（`unrecognized arguments`）；不加的話會走 daemon，在這台 WSL 會卡住直到 `timeout 20` 才結束、沒有輸出。`send_goal` 不受影響。
- `--no-daemon` 的探索時間很短，節點剛啟動時 `param list` 可能回 `Node not found`，腳本裡查兩次。
- 後續章節建議沿用 `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`＋lo multicast 這兩行。
