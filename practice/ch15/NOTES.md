# K136 第 15 章：深度強化學習（快速演練）

> 快速 demo 模式，未經 QA／code review。

## 做了什麼

| 步驟 | 檔案 | 結果 |
| --- | --- | --- |
| 0. 讀書本 Chapter15 | `step0_explore.sh` → `logs/step0_explore.log` | 只有 `docker_setup_scripts/setup_docker_ubuntu.sh` 一個檔案 |
| 1. 裝 gymnasium | `step1_install.sh`、`step1b_reinstall.sh` | `~/k136_venv` 內 gymnasium 1.4.0，`CartPole-v1` 可建立 |
| 2. 訓練 Q-learning | `cartpole_qlearning.py`、`step2_train.sh` → `logs/step2_train.log` | 學習曲線 `results/learning_curve.png`、數據 `results/summary.json` |
| 3. 清理 | `cleanup.sh` → `logs/cleanup.log` | `NO_LEFTOVER`，並執行 `timeout 15 ros2 daemon stop` |

本章沒有 ROS 套件，所以沒建 `~/k136_ws/ch15` 工作區，也沒啟動任何 ROS 節點或 Gazebo。

## `setup_docker_ubuntu.sh` 裝了什麼

書上用它把主機準備成可以跑 Isaac Sim／Isaac Lab 容器的環境：

1. **檢查 NVIDIA GPU**：`lspci | grep nvidia` 加上 `nvidia-smi`，兩個都過才算「有 GPU 且驅動正常」。
2. **安裝 Docker**（一定會做）：
   - 加 Docker 官方 GPG 金鑰（`/etc/apt/keyrings/docker.asc`）和 apt 套件來源
   - 安裝 `docker-ce`、`docker-ce-cli`、`containerd.io`、`docker-buildx-plugin`、`docker-compose-plugin`，另外裝 `git`、`openssh-server/client`
   - 把目前使用者加進 `docker` 群組、`chmod 666 /var/run/docker.sock`（讓不用 sudo 也能下 docker 指令；安全性較差）、重啟 docker
3. **安裝 NVIDIA Container Toolkit**（只有偵測到 GPU 才做）：加 NVIDIA 的 libnvidia-container 套件來源、裝 `nvidia-container-toolkit`，再用 `nvidia-ctk runtime configure --runtime=docker` 讓容器能用 `--gpus all` 存取 GPU。

腳本小問題（只閱讀、沒有執行）：

- 參數 `ubuntu_version`、`architecture` 讀進來卻沒用到。
- `sed -i ... nvidia-container-toolkit.list` 少了 `sudo`，一般使用者執行會失敗。
- `usermod -aG docker` 重複寫了兩次。

本機沒有 NVIDIA GPU，而且 Isaac Sim 容器要 RTX 顯卡，所以**沒執行這支腳本**（它也會改系統 apt 來源，不適合在演練中隨意跑）。

## 驗證結果

`logs/step2_train.log` 摘錄：

```
"episodes": 600,
"first_100_avg": 40.47,
"last_100_avg": 466.16,
"greedy_eval_20_avg": 499.35,
"q_table_shape": [1, 1, 8, 12, 2]
OK：平均回合長度明顯變長
```

- 前 100 回合平均只撐 40 步，最後 100 回合平均 466 步（上限 500）。
- 訓練完關掉探索、純貪婪跑 20 回合：19 回合撐滿 500 步，平均 499.35。
- 學習曲線（`results/learning_curve.png`）整體上升；中段（約 330～430 回合）有一次明顯下滑再回升，這是表格式 Q-learning 加上粗格子常見的震盪。

## 書上 RL 流程 vs 本練習

| RL 要素 | 書上（Isaac Lab） | 本練習 |
| --- | --- | --- |
| 環境 | Isaac Sim 物理模擬（GPU），可同時跑幾千個平行環境；機器人任務如 Cartpole、四足行走、機械手臂 | gymnasium `CartPole-v1`，CPU、單一環境 |
| 觀測 | 連續向量，直接餵給神經網路 | 4 維連續值（位置、速度、角度、角速度）切成格子：角度 8 格、角速度 12 格，位置與速度不分格 |
| 動作 | 連續力量／關節目標 | 離散兩個：往左推、往右推 |
| 獎勵 | 任務設定檔裡多項加權（活著、姿勢、能量懲罰…） | 每撐一步 +1，桿子倒或車出界就結束，500 步截斷 |
| 策略 | 神經網路（actor-critic） | Q-table，ε-greedy 選動作 |
| 訓練演算法 | PPO（rsl_rl／skrl 等框架），GPU 平行收集資料 | 表格式 Q-learning：`Q += α·(r + γ·maxQ' − Q)`，ε 和 α 隨回合遞減 |
| 結果 | TensorBoard 曲線、匯出策略可部署到 ROS 2 控制機器人 | `learning_curve.png` + `summary.json` |

共同的迴圈都是：**重設環境 → 觀測 → 策略選動作 → 環境回傳獎勵與下一個觀測 → 用經驗更新策略 → 重複**。

## 和書上做法的差異

- 沒有 GPU：不能跑 Isaac Sim／Isaac Lab，也不能用 Docker 的 NVIDIA runtime。改用 gymnasium CartPole 在 CPU 上走同一套 RL 概念。
- 演算法從 PPO 換成表格式 Q-learning：只適合狀態少的小問題，但不用 PyTorch，幾秒就訓練完。
- 沒接 ROS 2：書上訓練好的策略會再接到 ROS 2 控制機器人，本練習只停在訓練與評估。
- 程式修正：gymnasium 判斷終止時區分 `terminated`（倒下，沒有未來回報）和 `truncated`（時間到，仍要估未來價值），兩種情況分開處理。

## 踩到的坑

- **第一次 pip 安裝的 gymnasium 是壞的**：`__init__.py` 是空檔、`pip show` 版本顯示 None，導致 `gym.make` 不存在。推測是安裝時另一個 WSL 呼叫同時在跑而中斷了寫檔。用 `pip install --force-reinstall --no-deps gymnasium` 重裝後就正常（`step1b_reinstall.sh` 現在留下的是重裝後的驗證版本）。
- **`pip show | head` 在 `set -o pipefail` 下會讓腳本中斷**（head 先關掉管線 → Broken pipe）。腳本裡不要把會大量輸出的指令接 `head`。
