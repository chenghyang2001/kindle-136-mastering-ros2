# K136 第 14 章：LLM 介接 ROS 2（快速演練筆記）

> 快速 demo 模式：只求看懂流程，未經 QA／審查。ROS 2 Jazzy 跑在 WSL（Ubuntu-24.04），工作區 `~/k136_ws/ch14`。
> **沒有用 OpenAI 金鑰**：LLM 換成假的，其餘（工具定義、cmd_vel、pose）都是真的在跑。

## 結論

烏龜真的動了。兩條路都通，結果一模一樣：

| 路線 | 怎麼決定呼叫哪個工具 | 結果 |
| --- | --- | --- |
| A. 備案：最小假 agent（`src_patch/minimal_agent.py`） | 純 Python 關鍵字規則，不依賴 langchain | x 5.544 → 5.746 → 6.250，`MOVED_OK` |
| B. 書上 agent + langchain 假 LLM（`src_patch/fake_llm.py`） | `create_openai_tools_agent` + `AgentExecutor`，LLM 換成規則式假模型 | x 5.544 → 5.746 → 6.250，`MOVED_OK` |

## 走了哪條路、為什麼

1. 原本計畫只走 B。但 WSL 網路很不穩，pip 一直斷線：
   - 第一次 venv 建失敗：系統沒裝 `python3.12-venv`（沒有 ensurepip）→ `sudo apt-get install -y python3.12-venv`。
   - 第二次用寬鬆範圍 `langchain>=0.3,<1.0` 安裝，pip 卡了 10 分鐘，一個套件都沒裝進去（斷線＋解析）。
   - 第三次改鎖 0.3 系列小版本（`langchain~=0.3.27` 等）、拿掉 `-q` 看進度，下載仍反覆斷線續傳。
2. 教練指示「不要空等」→ 先寫 **A 備案**（純 rclpy，系統 python 就能跑），先證明 turtlesim 會動。
3. A 跑完後 pip 也裝好了（`langchain 0.3.30 / langchain-core 0.3.86 / langchain-openai 0.3.35`），補跑 **B** 做對照。

## 做了什麼

| 步驟 | 腳本 | 紀錄 |
| --- | --- | --- |
| 看 Chapter14 結構、turtlesim agent 原始碼 | `step0_explore.sh`、`step0b_explore.sh` | `logs/step0*.log` |
| 建 `~/k136_venv`（`--system-site-packages`），裝 langchain 0.3 系列 | `step1_venv.sh` | `logs/step1_venv.log` |
| 複製 `ros2_basic_agent` → 加假 LLM、改 agent、換 openai.env 範本 → `colcon build --symlink-install` | `step2_build.sh` | `logs/step2_build.log` |
| turtlesim（`QT_QPA_PLATFORM=offscreen`）+ agent，發 3 個 prompt，讀 pose、錄 cmd_vel | `step3_run_agent.sh minimal`／`langchain` | `logs/step3_run_*.log`、`logs/run_*/` |
| 章末清理 + `timeout 15 ros2 daemon stop` | `cleanup.sh` | `logs/cleanup.log` |

## 驗證結果

送出的三個 prompt（`ros2 topic pub --once -w 1 /prompt std_msgs/msg/String`）：
`Move the turtle forward 2 units`、`往前走 5 單位`、`where is the turtle?`

B（langchain）路線的 agent log，可以看到 AgentExecutor 真的走完「模型決定 → 呼叫工具 → 把結果回給模型 → 最終答案」：

```
[ros2_ai_agent]: LLM backend: RuleBasedFakeToolLLM
> Entering new AgentExecutor chain...
Invoking: `move_forward` with `{'distance': 2.0}`
Moved forward 2.0 units  Done. Tool result: Moved forward 2.0 units
> Finished chain.
...
Invoking: `get_pose` with `{}`
x: 6.25, y: 5.54, theta: 0.00 degrees
```

`/turtle1/pose` 與 `/turtle1/cmd_vel`：

```
x: 5.5444 -> 5.7460 -> 6.2500  (dx1=+0.2016, dx2=+0.5040)
MOVED_OK
cmd_vel linear.x: 0.2, 0.5
```

移動量很小是書上工具本身的設計：`move_forward(distance)` 只發**一次** `linear.x = distance * 0.1`，
turtlesim 收到速度後約 1 秒沒新指令就停，所以「前進 2」實際只走 ≈0.2。這是書上程式的行為，本演練沒改。

清理：`NO_LEFTOVER`（WSL 裡沒有殘留的 turtlesim／agent／ros2 行程）。

## 和書上做法的差異

| 書上 | 本演練 | 原因 |
| --- | --- | --- |
| `ChatOpenAI(model="gpt-4o-mini")` | 沒金鑰時用 `RuleBasedFakeToolLLM`（關鍵字 → `tool_calls`） | 不可用 OpenAI 金鑰 |
| Docker 映像（`docker_llm/`）裝套件 | WSL 的 `~/k136_venv`，把 venv site-packages 接到 `PYTHONPATH` | agent 執行檔 shebang 是系統 python3 |
| `pip install langchain`（不鎖版本） | 鎖 `langchain~=0.3.27` | 書上用的 `AgentExecutor`、`create_openai_tools_agent` 在 langchain 1.x 已移除 |
| `ros2 launch ... start_turtlesim_agent.py`（會開 turtlesim 視窗） | 直接執行兩個節點，`QT_QPA_PLATFORM=offscreen`，`setsid` 開行程群組，結束整組 kill | 不開圖形視窗、不留殘留行程 |
| 用 RViz／看畫面確認烏龜動了 | 讀 `/turtle1/pose` 前後比較、錄 `/turtle1/cmd_vel` | 無人看管 |
| — | 另寫不依賴 langchain 的最小 agent（備案 A） | pip 斷線時先證明流程 |

修改只在工作區複製檔（`~/k136_ws/ch14/src/ros2_basic_agent`），書本 repo 原檔沒動。
修改處都標「本演練改」，由 `src_patch/patch_agent.py` 套用。

## 真的要接 OpenAI 時要改哪裡

1. 填 `config/openai.env`（本資料夾只放範本，**沒有金鑰**；不要 commit 真的金鑰）：

   ```
   OPENAI_API_KEY=sk-...
   OPENAI_API_TYPE=openai
   ```

   重跑 `step2_build.sh`，它會把範本複製到工作區 `config/openai.env`，colcon 裝到
   `install/ros2_basic_agent/share/ros2_basic_agent/config/openai.env`，agent 用 `load_dotenv()` 讀它。
   （symlink-install 下也可以直接改工作區那份。）
2. 啟動 agent 前不要 `export LLM_BACKEND=fake`；改成 `export LLM_BACKEND=openai`，或留預設 `auto`（有金鑰就自動用 `ChatOpenAI`）。
3. `step3_run_agent.sh` 裡的 `unset OPENAI_API_KEY`、`export LLM_BACKEND=fake` 兩行要拿掉。
4. 模型名稱在 agent 原始碼 `ChatOpenAI(model="gpt-4o-mini", temperature=0)`，想換模型改這裡。
5. 真模型會自己判斷參數，不用關鍵字規則；`fake_llm.py` 可以留著當離線測試用。

## 已知沒處理的風險

- 假 LLM 只認 forward／往前、rotate／轉、pose／位置 這幾種關鍵字，其他句子只會回「我只會這三個工具」。
- 只驗證了 turtlesim agent；nav2、moveit2、basic_tools 三支 agent 沒跑（需要對應模擬環境，且都依賴 OpenAI）。
- `package.xml` 宣告了 `moveit-py`、`nav2_msgs` 依賴，colcon 建置 ament_python 時不檢查，所以沒裝也建得過。
