# K136 第 7 章快速演練：BehaviorTree.CPP

> 快速 demo 模式，未經 QA／審查。環境：Windows 11 + WSL Ubuntu 24.04 + ROS 2 Jazzy，
> `ros-jazzy-behaviortree-cpp` 4.10.0（已預裝），RMW 用 CycloneDDS，`ROS_DOMAIN_ID=36`、探索範圍 LOCALHOST。

## 做了什麼

| 步驟 | 腳本 | 內容 | 紀錄 |
| --- | --- | --- | --- |
| 0 | `step0_explore.sh` | 讀書本 Chapter07 原始碼、確認 BT.CPP 套件 | `logs/step0_explore.log` |
| 1 | `step1_build.sh` | 複製 `first_bts`、`bt_action_server` 到 `~/k136_ws/ch07/src`，`colcon build --symlink-install` | `logs/step1_build.log` |
| 2 | `step2_first_bts.sh` | `sequence_tree.launch.py`（5 秒）、`number_checker.launch.py`（約 15 秒）＋ echo `/generated_number` | `logs/step2_first_bts.log` |
| 3 | `step3_bt_action.sh` | 先在沒有 server 時跑 bt_action，再啟動 `reach_location_server` 跑 `bt_action.launch.py` 60 秒 | `logs/step3_bt_action.log` |
| 4 | `step4_modified.sh` | 安裝兩棵修改版樹（`trees/`），跑 number_checker 比較＋ bt_action Fallback 版 70 秒 | `logs/step4_modified.log` |
| 5 | `step5_nc_compare.sh` | 重做 number_checker 原版 vs Sequence 版（修正 step4 的殘留行程問題） | `logs/step5_nc_compare.log` |
| 末 | `cleanup.sh` | 清殘留行程＋`timeout 15 ros2 daemon stop` | `logs/cleanup.log` |

建置：2 個套件約 24 秒完成，無錯誤。

## 樹的結構（文字樹）

### 1. sequence.xml（`sequence_tree`）

```
Sequence
├── HelloNode1  msg="Hello from Node1"
└── HelloNode2  msg="Hello from Node2"
```

### 2. number_checker.xml（`number_checker`，原版）

```
RosIntegration（main tree）
└── Sequence
    ├── SubTree "Subtree"（_autoremap → 共用黑板鍵 {generated_number}）
    │   └── Fallback
    │       ├── CheckNumber1  check_value=30  → {generated_number}
    │       └── Fallback
    │           ├── CheckNumber2  check_value=50
    │           └── ForceSuccess
    │               └── CheckNumber3  check_value=80
    └── PublishResult  topic=/generated_number  value={generated_number}
```

### 3. bt_action.xml（`bt_action`，原版）

```
Sequence
├── WaitForServer  server_name=reach_location
└── CallAction     server_name=reach_location  x=10 y=4 timeout=15
```

### 修改版 A：number_checker_seq.xml（Fallback → Sequence，拿掉 ForceSuccess）

```
RosIntegration
└── Sequence
    ├── SubTree "Subtree"
    │   └── Sequence            ← 本演練改（原為兩層 Fallback）
    │       ├── CheckNumber1  check_value=30
    │       ├── CheckNumber2  check_value=50
    │       └── CheckNumber3  check_value=80   ← 拿掉 ForceSuccess
    └── PublishResult
```

### 修改版 B：bt_action_fallback.xml（加一層 Fallback）

```
Sequence
├── WaitForServer  server_name=reach_location
└── Fallback                                   ← 本演練加
    ├── CallAction  x=30 y=30 timeout=5         （速度上限 2/秒，5 秒最多到 10 → 必失敗）
    └── CallAction  x=3  y=3  timeout=10        （幾乎必成功）
```

## 驗證結果

### sequence_tree：XML 的子節點順序 = 輸出順序

每 0.5 秒 tick 一次；`HelloNode` 是 StatefulActionNode，第一次 tick 只跑 `onStart()` 回 RUNNING，
下一次 tick 才在 `onRunning()` 印字並 SUCCESS，所以兩行輸出交替出現：

```
[sequence_tree-1] Hello from Node1
[sequence_tree-1] Hello from Node2
[sequence_tree-1] Hello from Node1
[sequence_tree-1] Hello from Node2
```

### number_checker：Fallback 一路往下試

```
Generated number: 68 - Threshold: 30 - Failure!   ← CheckNumber1 失敗 → Fallback 試下一個
Generated number: 74 - Threshold: 50 - Failure!   ← CheckNumber2 失敗
Generated number: 39 - Threshold: 80 - Success!   ← CheckNumber3 成功 → 子樹成功 → 發布 39
Generated number: 26 - Threshold: 30 - Success!   ← 第一個就成功，後面不再試
...
Generated number: 80 - Threshold: 80 - Failure!   ← 三個都失敗，但 ForceSuccess 把它變 SUCCESS → 發布 -1
```

`ros2 topic echo /generated_number --once` 收到 `data: 12`。

### bt_action（原版）：SUCCESS 流程

- 沒有 server 時：`[Node WaitForServer]: Failure` 每 0.5 秒一次，Sequence 失敗、CallAction 從未執行。
- 有 server 時（60 秒）：server 收到 5 次 goal、5 次 `Goal succeeded`；BT 端 5 次 `CallAction: Success`。
  每次 goal 約 8～13 秒（隨機速度 0.1～2/秒），之間 BT 端印約 20 行 `Waiting server execution`（RUNNING）。

```
[bt_action-1] [Node WaitForServer]: Success
[bt_action-1] [Node CallAction]: Success
... server: Received goal request for location (10.000000, 4.000000) with timeout 15.000000
... server: Current position: (11.125010, 11.125010)
... server: Goal succeeded
```

原版參數下（x=10、timeout=15）平均速度約 1.05/秒，大多會成功；60 秒內沒抽到 FAILURE。
FAILURE 流程改由修改版 B 穩定重現。

### 修改前後比較

**number_checker（30 秒，step5）**

| 版本 | CheckNumber 判斷 | `/generated_number` 收到 | 其中 -1 |
| --- | --- | --- | --- |
| 原版（Fallback＋ForceSuccess，OR） | Success 14／Failure 20 | **13 筆** | 2 |
| 修改版 A（Sequence，AND） | Success 15／Failure 24 | **1 筆**（值 11） | 0 |

修改版 A 只有「30、50、80 三關全過」才發布，30 秒內只發生 1 次（理論約 11%／輪）；
子樹失敗時根 Sequence 直接中止，`PublishResult` 不會執行，所以也不會再有 -1。

**bt_action（70 秒，step4）**

| 版本 | server Goal succeeded | server Goal failed | 流程 |
| --- | --- | --- | --- |
| 原版 | 5（60 秒） | 0 | WaitForServer → CallAction 成功 → 重來 |
| 修改版 B | 6 | 6 | WaitForServer → 第一個 CallAction FAILURE → Fallback 改試第二個 → SUCCESS → 重來 |

```
[Node WaitForServer]: Success
[Node CallAction]: Failure      ← (30,30) timeout 5 → server: Goal failed（abort）
[Node CallAction]: Success      ← (3,3) timeout 10 → server: Goal succeeded
```

## 和書上做法的差異

1. **執行方式**：書上直接在終端機開多個視窗 `ros2 launch`／`ros2 run`；本演練全部寫成 `.sh`，
   用 `timeout` 或背景＋PID 控制，保證會結束。
2. **`bt_action.launch.py` 只啟動行為樹**，不含 action server；server 由腳本先用 `ros2 run` 背景啟動。
3. **沒有用 Groot2** 看樹（圖形介面），改在本筆記用文字樹畫出結構。
4. **修改版樹檔**放在練習資料夾 `trees/`，複製到 `~/k136_ws/ch07/src/.../trees/` 後重建安裝；書本 repo 原檔不動。
   修改版用 `ros2 run ... --ros-args -p tree_xml_file:=...` 指定樹檔，不另寫 launch。
5. **DDS／daemon**：照前幾章經驗用 CycloneDDS、`--no-daemon`；`ros2 action list` 不支援 `--no-daemon`，
   用 timeout 包住仍逾時（daemon 卡住），不影響行為樹本身的探索。

## 踩到的坑

- **`ros2 run` 會包一層 Python 再開子行程**：`ros2 run ... &` 後 `kill $!` 只殺到外層，
  C++ 節點可能還活著繼續發布。step4 的 number_checker 比較因此被原版殘留節點污染
  （Sequence 版卻收到 18 筆、含 33、46、79 這種不可能通過的值）。
  step5 改成直接執行 `install/first_bts/lib/first_bts/number_checker`，殺完確認行程數為 0，結果才正確。
  （step4 的 bt_action 段用 `timeout ros2 run`，server 也用 `ros2 run`；BT 端統計與 server 端一致，未見污染。）
- 書本程式碼的小瑕疵（未修，照書跑）：`number_checker.cpp` 留著除錯字串 `QUI!.`；
  `bt_action.cpp` 的 `CallAction` 建了名稱固定為 `action_client_node` 的第二個 node，所以會出現
  `Publisher already registered for node name` 警告；`bt_action_server/package.xml` 沒宣告 `behaviortree_cpp` 依賴
  （因為已裝在系統裡，建置不受影響）。
