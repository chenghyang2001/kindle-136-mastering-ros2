# Kindle 136《Mastering ROS 2 for Robotics Programming》第四版 演練包

- 書：Lentin Joseph、Jonathan Cacace，Packt，2025（ROS 2 Jazzy）
- 官方範例：<https://github.com/PacktPublishing/Mastering-ROS-2-for-Robotics-Programming>
- 簡報：<https://github.com/chenghyang2001/kindle-136-slides>
- 環境：Windows 11 + WSL2 Ubuntu 24.04 + ROS 2 Jazzy（Gazebo Harmonic、ros2_control、Nav2、MoveIt 2）

用 kindle-drill 雙視窗快速模式（左教練、右練習）逐章演練第 1～16 章並全程錄影。

| 檔案 | 用途 |
| --- | --- |
| `teaching/LESSON-PLAN.md` | 每章要練習視窗做的事＋共通限制 |
| `teaching/drill.json` | 章節 → 練習資料夾 |
| `teaching/DRILL-PROMPT.md` | 教練開場提示詞 |
| `teaching/HANDOFF.md` | 快速模式進度表（每章結果與和書上的差異） |
| `practice/chNN/` | 各章練習資料夾留存（腳本、NOTES.md、logs、ws_src 套件副本） |

## 換一台電腦重跑

看 [NEW-PC-DRILL.md](NEW-PC-DRILL.md)：程式碼位置（官方範例已 fork 到 [chenghyang2001/Mastering-ROS-2-for-Robotics-Programming](https://github.com/chenghyang2001/Mastering-ROS-2-for-Robotics-Programming)）、新電腦需求、WSL＋ROS 2 安裝、給 Claude Code CLI 的快速演練提示詞。
各章改過的 ROS 套件副本在 `practice/chNN/ws_src/`。

## 總結與結論

看 [CONCLUSIONS.md](CONCLUSIONS.md)：成果連結、Docker 與 WSL 的比較、決定與教訓。
