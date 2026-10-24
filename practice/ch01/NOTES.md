# K136 第 1 章：ROS 2 簡介 — 快速演練筆記

> 快速 demo 模式：只用指令走一遍觀念，未經 QA／審查。環境：Windows 11 + WSL Ubuntu-24.04 + ROS 2 Jazzy。
> 本章不寫程式、不需建置；已建立 `~/k136_ws/ch01/src`（空的，保持各章結構一致）。

## 做了什麼

| 腳本 | 內容 | 紀錄 |
| --- | --- | --- |
| `step1_basics.sh` | `printenv ROS_DISTRO`、`ros2 pkg list \| wc -l`、背景跑 C++ `talker` + Python `listener`（timeout 15），期間跑 `node list`、`topic list -t`、`topic info /chatter -v`、`interface show std_msgs/msg/String` | `logs/step1_basics.log` |
| `step2_domain.sh` | `RMW_IMPLEMENTATION=rmw_fastrtps_cpp`；talker 在 domain 36，listener 各一個在 domain 36／37 | `logs/step2_domain.log` |
| `diag.sh` | 找出 `ros2 daemon` 卡住的診斷腳本 | `logs/diag.log` |
| `cleanup.sh` | 停殘留行程 + `ros2 daemon stop`，最後檢查沒有殘留 | `logs/cleanup.log` |

## 驗證結果

- `ROS_DISTRO` = `jazzy`；已安裝套件 **479** 個；`RMW_IMPLEMENTATION` 預設沒設定（Jazzy 預設 Fast DDS，`rmw_fastrtps_cpp`）。
- **跨語言互通**：C++ talker 發 `Hello World: N`，Python listener 收到 **14 則** `I heard: [Hello World: N]`。
- `ros2 topic list -t`：`/chatter [std_msgs/msg/String]`、`/parameter_events`、`/rosout`。
- `ros2 topic info /chatter -v`：Publisher 1（talker）、Subscription 1（listener），QoS 都是：

  ```
  Reliability: RELIABLE
  Durability: VOLATILE
  Liveliness: AUTOMATIC
  Deadline / Lifespan: Infinite
  ```

- `std_msgs/msg/String` 只有一個欄位 `string data`（介面註解說 Foxy 起不建議使用，改用自訂訊息或 `example_msgs`）。
- **Domain 隔離**（Fast DDS）：

  | listener | 收到 |
  | --- | --- |
  | `ROS_DOMAIN_ID=36`（和 talker 同 domain） | 16 則 |
  | `ROS_DOMAIN_ID=37` | 0 則，`ros2 topic info /chatter` 回 `Unknown topic` |

  結果 PASS：不同 domain 互相看不到。
- 清理：`乾淨：無殘留`。

## 第 1 章 ROS 2 架構整理

| 層 | 是什麼 | 本機對應 |
| --- | --- | --- |
| 使用者程式 | 節點（node）、topic／service／action | `demo_nodes_cpp talker`、`demo_nodes_py listener` |
| Client library | 各語言的 API：`rclcpp`（C++）、`rclpy`（Python） | talker 用 rclcpp、listener 用 rclpy |
| rcl | 用 C 寫的共用核心：節點、參數、時間、日誌等邏輯，各語言 client library 都包它 | `rcl` 套件 |
| rmw | 中介層抽象介面，把 rcl 和具體 DDS 實作隔開，可用 `RMW_IMPLEMENTATION` 切換 | `rmw_fastrtps_cpp`（預設） |
| DDS／中介軟體 | 實際負責探索、序列化、傳輸、QoS（Fast DDS、Cyclone DDS、Connext；Jazzy 另有 Zenoh） | eProsima Fast DDS |

因為 C++ 與 Python 最後都走同一個 rcl → rmw → DDS，兩者能直接互通，這就是步驟 1 驗證的事。

## ROS 1 與 ROS 2 差異

| 項目 | ROS 1 | ROS 2 |
| --- | --- | --- |
| 探索機制 | 集中式 `roscore`（ROS Master），掛了就全斷 | 分散式 DDS 自動探索，不需要 master |
| 通訊 | 自製 TCPROS／UDPROS | DDS／RTPS 標準，可換實作（rmw） |
| QoS | 幾乎沒有（只有 queue size） | 完整 QoS：reliability、durability、history、deadline、liveliness… |
| 隔離網路 | 靠不同 `ROS_MASTER_URI` | `ROS_DOMAIN_ID`、`ROS_AUTOMATIC_DISCOVERY_RANGE` |
| Client library | roscpp、rospy 各自實作，行為不一致 | 共用 rcl 核心，rclcpp／rclpy 只是薄封裝 |
| 即時性／嵌入式 | 不適合 | 設計時就考慮即時與 micro-ROS |
| 安全 | 無 | SROS2（DDS-Security） |
| 平台 | 主要 Linux | Linux、Windows、macOS |
| 建置工具 | catkin | ament + colcon |
| 節點生命週期 | 無 | Managed（lifecycle）節點 |
| launch | XML | Python／XML／YAML |
| Python | Noetic 前是 Python 2 | Python 3 |

## 和書上做法的差異

1. **改在 WSL 跑**：Windows 的 Claude Code 把指令寫成 `.sh`，再用 `wsl.exe -d Ubuntu-24.04 --cd ... -- bash ./xxx.sh` 執行。
2. **`ros2 daemon` 在這台 WSL 會卡死**（`ros2 doctor`、`ros2 daemon status`、`ros2 daemon stop` 都不會結束）。所以查詢都加 `--no-daemon`，`ros2 doctor` 改成用 `ros2 pkg list | grep rmw_` 看 RMW，`cleanup.sh` 的 `ros2 daemon stop` 加 `timeout 15`（實際也是逾時，但 daemon 本來就沒在跑，清理檢查結果是乾淨的）。
3. **加了 `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`**：診斷時在 domain 36 看到一組不是 WSL 開的 `/talker`、`/listener`，WSL 的 `ps` 也找不到這些行程，應該是同一個區網上別台機器也在用 domain 36。這反而直接示範了「同 domain 跨機器互相看得到」，但為了結果穩定，演練腳本都限定只探索本機。
4. **等待時間拉長**：Python listener 要 3～4 秒才啟動。第一次步驟 2 用 `timeout 8`／`sleep 4`，結果兩個 listener 都收到 0 則（FAIL）；改成 talker `timeout 40`、listener `timeout 20`、`sleep 10` 後就 PASS。
5. `ros2 node list --no-daemon` 常常只列出 `/talker`，看不到 Python 的 `/listener`（但 `topic info -v` 有看到它的訂閱，也確實收到訊息）。原因是 `--no-daemon` 探索時間很短，抓到的節點不一定齊全。
6. 不開任何 GUI（本章本來就用不到 rqt_graph 之類的工具）。
