# K136 演練總結與結論（2026-10-25 收工）

《Mastering ROS 2 for Robotics Programming》第四版，在 hp2（DESKTOP-6LST1BR，Windows 11 + WSL2 Ubuntu 24.04 + ROS 2 Jazzy）完成。

## 1. 做完了什麼

| 項目 | 結果 |
| --- | --- |
| 雙視窗快速演練第 1～16 章 | ✅ 全部完成（2026-10-24 18:04 → 10-25 04:58，扣掉筆電睡眠約 3 小時） |
| 完整錄影（私人） | <https://youtu.be/ks0i1ZNnw8s>（3:04:17，含章節） |
| 精華版（私人） | <https://youtu.be/GASd9vHkP-c>（6:08，含章節） |
| 演練語音 16 段 | <http://187.127.109.145/kindle-136-drill-player.html> |
| 提示詞頁 16 章 | <http://187.127.109.145/kindle-prompts.html?n=136> |
| 書目總表 K136 那一列 | 四個連結已上線：<https://chenghyang2001.github.io/mermaid-viewer/books.html> |
| 程式碼 | 官方範例 fork：<https://github.com/chenghyang2001/Mastering-ROS-2-for-Robotics-Programming>；本 repo `practice/chNN/`（腳本、NOTES、log、`ws_src` 套件副本） |
| 換電腦說明 | [NEW-PC-DRILL.md](NEW-PC-DRILL.md)（已寄 Gmail）；hp1 已照著重跑中 |
| 第 2 章 Docker 補做 | ✅ 書上兩個 compose 範例 talker／listener 互通，見 `practice/ch02-docker/NOTES.md` |

## 2. Docker 和 WSL 的比較

三種做法：

| | A. WSL 直接裝（16 章演練用的） | B. Docker Desktop 容器（已實測） | C. WSL 裡自己裝 Docker Engine（書上做法） |
| --- | --- | --- | --- |
| ROS 2 裝在哪 | Ubuntu 本身 | 容器裡，跑在 Docker 自己的虛擬機 | 容器裡，跑在 Ubuntu 上 |
| 安裝量 | 約 6 GB，裝一次一直用 | image 6.35 GB（這台下載約 50 分鐘） | 同 B |
| 圖形視窗 | WSLg 直接顯示，已驗證 | 要另外設定顯示轉送 | 要設定 |
| 和本機 ROS 程式互通 | 直接互通 | ❌ 實測不通（Docker 虛擬機 192.168.65.x 和 WSL 192.168.1.103 不同網段） | ✅ 可以 |
| 環境乾淨／可丟棄 | 不好還原 | ✅ 刪容器就回原樣 | ✅ |
| 換電腦重現 | 要重跑安裝 | ✅ 同一個 image 最一致 | ✅ |
| 多個 ROS 版本並存 | 一台 Ubuntu 一個版本 | ✅ | ✅ |

### 什麼情況用哪一種

1. 跟書演練、日常學習、要看 RViz／Gazebo → **A**。
2. 書上專門教 Docker 的章節、只需要容器之間互通 → **B**。
3. 容器要和本機 ROS 程式互相對話 → C（書上設定）。
4. 試別的 ROS 版本、怕弄壞環境、要給別人一樣的環境 → B 或 C。
5. 換電腦重跑演練 → 照 NEW-PC-DRILL.md 用 A；只想快速驗證範例能不能跑、而且網路夠快 → B。

一句話：WSL 直接裝是長期的工作環境，Docker 是隨用隨丟的乾淨環境。

## 3. 決定

- **主力環境：A（WSL 直接裝 ROS 2）**。
- **B（Docker Desktop）保留可用**：已開啟和 Ubuntu-24.04 的 WSL 整合（Ubuntu 裡可直接下 `docker`），image `osrf/ros:jazzy-desktop-full` 留在本機；另外開了 host networking 選項（實測對互通沒幫助）。設定檔改之前的備份在 `%APPDATA%\Docker\settings-store.json.bak-k136`。
- **C 不做**（使用者 2026-10-25 決定：不會再試、不會再裝）。
- Docker 相關測試到此結束，不再繼續。

## 4. 這次學到的教訓

| 教訓 | 之後怎麼做 |
| --- | --- |
| 筆電半夜睡眠，演練停 8 小時、錄影多出 6 小時靜止畫面 | 夜間任務開跑前先啟動防睡眠程式；上傳前依 log 剪掉睡眠段 |
| YouTube Studio 的 Chrome 開在螢幕 2，擋住教練視窗 | 錄影期間 Chrome 一律放主螢幕 |
| 多個 Chrome 連線時停下來問使用者 | 鐵律：直接關掉所有 Chrome、自己開一個（使用者授權） |
| `docker` 沒回應就判斷「沒裝 Docker」 | 先看 Windows 有沒有 Docker Desktop、是不是沒啟動 |
| WSL 的 ros2 daemon 卡住、Fast DDS 探索慢 | 查詢加 `--no-daemon`；改用 `rmw_cyclonedds_cpp` |
| 未解：第 12 章 rf2o 估出的 x 方向相反 | 記在 `practice/ch12/NOTES.md` |
