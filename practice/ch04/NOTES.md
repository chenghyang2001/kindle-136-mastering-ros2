# K136 第 4 章：機器人 3D 建模（URDF／xacro）快速演練

> 快速 demo 模式，未經 QA／審查。環境：Windows 上的 Claude Code → WSL2 Ubuntu 24.04 + ROS 2 Jazzy，工作區 `~/k136_ws/ch04`。

## 做了什麼

| 步驟 | 腳本 | 內容 | 紀錄 |
| --- | --- | --- | --- |
| 0 | `step0_explore.sh` | 列出三個套件檔案、依賴、確認工具（check_urdf／urdf_to_graphviz／xacro／dot／pdftoppm 都已安裝） | `logs/step0_explore.log` |
| 1 | `step1_build.sh` | 複製 `urdf_tutorial`、`rrbot_description`、`rosbot_description` 到工作區，`colcon build --symlink-install` | `logs/step1_build.log` |
| 2 | `step2_check_urdf.sh` | `check_urdf` 檢查 simple_rrbot.urdf；rrbot／rosbot xacro→URDF 再檢查；額外測 `prefix:=left_`；`urdf_to_graphviz` 產 PDF → `pdftoppm` 轉 PNG | `logs/step2_check_urdf.log` |
| 3 | `step3_tf.sh rrbot\|rosbot` | 背景跑 `robot_state_publisher` + `joint_state_publisher`（非 GUI），查 node list、`/robot_description`、`/joint_states`、`tf2_echo`、`/tf_static` | `logs/step3_tf_rrbot.log`、`logs/step3_tf_rosbot.log` |
| 末 | `cleanup.sh` | 清殘留行程 + `timeout 15 ros2 daemon stop` | `logs/cleanup.log` |

產物在 `urdf_out/`：`simple_rrbot_tree.png`、`rrbot_tree.png`、`rosbot_tree.png`（link 樹），以及展開後的 `.urdf` 和 `.gv`。

## 驗證結果

**建置**：3 個套件 4.5 秒建完。

**check_urdf**（三個都 `Successfully Parsed XML`）：

```text
simple_rrbot : world → single_rrbot_link1 → single_rrbot_link2 → single_rrbot_link3
rrbot (xacro): world → base_link → link1 → link2 → tool_link
rrbot prefix:=left_ : world → left_base_link → left_link1 → left_link2 → left_tool_link
rosbot(xacro): base_link → {left_wheel_1, lidar_1, right_wheel_1}
```

**tf2_echo world → link2**（rrbot，關節角都是 0）：

```text
- Translation: [0.000, 0.200, 2.850]
- Rotation: in Quaternion (xyzw) [0.000, 0.000, 0.000, 1.000]
```

和手算一致：joint1 origin `(0, 0.1, 1.95)` + joint2 origin `(0, 0.1, 0.9)` = `(0, 0.2, 2.85)`。

**tf2_echo base_link → left_wheel_1**（rosbot）：`Translation: [0.000, 0.100, 0.050]`，等於 `left_wheel_joint` 的 origin。

**/robot_description** 有收到完整 URDF 字串（`data: <?xml version="1.0" ?> ... <robot name="simple_rrbot">`）；**/joint_states** 只列可動關節（rrbot：`joint1, joint2`；rosbot：`right_wheel_joint, left_wheel_joint`），fixed joint 走 `/tf_static`（例如 `link2 → tool_link`、`base_link → lidar_1`）。

rosbot 有一行警告：`The root link base_link has an inertia specified in the URDF, but KDL does not support a root link with an inertia`——不影響 TF，正規做法是加一個沒有 inertial 的 `base_footprint` 當 root。

## URDF／xacro 重點

**link**（剛體）三個子元素：

- `<visual>`：外觀（box／cylinder／sphere／mesh + material），RViz 畫的就是它
- `<collision>`：碰撞形狀，常用比 visual 簡單的幾何（simple_rrbot 的 link1 故意讓 collision 高 1、visual 高 2，可看出兩者獨立）
- `<inertial>`：質量、質心 origin、慣性矩陣，模擬器（Gazebo）才會用到

**joint**（連接兩個 link）：

- `parent` / `child` 決定樹狀結構；URDF 必須是一棵樹（單一 root、不能有迴圈）
- `origin`：child 座標系相對 parent 的位移與旋轉——TF 就是由它算出來
- `type`：`fixed`（不動，發到 `/tf_static`）、`continuous`（無限旋轉，如輪子）、`revolute`（有上下限，需 `<limit lower upper>`）、`prismatic`（滑動）、`floating`、`planar`
- `axis`：旋轉／滑動軸；`<limit effort velocity>`、`<dynamics damping>` 給控制與模擬用

**資料流**：URDF → `robot_state_publisher` 發 `/robot_description` 與 fixed joint 的 `/tf_static`；`joint_state_publisher` 發 `/joint_states`（可動關節角度）→ `robot_state_publisher` 結合後發 `/tf`。

**xacro**（XML 巨集，最後展開成純 URDF）：

- `xacro:property`：常數（`width`、`height1`），可在 `${}` 裡算式運算，例如慣性 `${mass / 12.0 * (width*width + height1*height1)}`
- `xacro:macro name="rrbot" params="parent prefix *origin"`：可重複使用的區塊；`*origin` 是區塊參數，用 `xacro:insert_block` 塞入
- `xacro:arg` + `$(arg prefix)`：命令列參數，`prefix:=left_` 就能把整支手臂改名，方便同一模型放兩支
- `xacro:include` + `$(find pkg)`：拆檔（材質、ros2_control、gazebo 設定分開放），rosbot 把 `materials.xacro`、`rosbot.ros2control`、`rosbot.gazebo` 拆開 include
- urdf_tutorial 的 `08-macroed.urdf.xacro` 示範 `default_inertial` 與帶 `reflect` 參數的 `wheel` macro（左右對稱）

## 和書上做法的差異

1. **環境**：書上用 Docker（`Chapter04/docker_urdf`），這裡用 WSL2 原生 ROS 2 Jazzy，DDS 改 Cyclone DDS（`RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`）並限 LOCALHOST 探索（前幾章實測 Fast DDS 在這台 WSL 很慢）。
2. **不開 RViz、不開 joint_state_publisher_gui**：書上用 `ros2 launch rrbot_description rrbot.launch.py`／`rosbot_description display.launch.py`，會開 GUI。本演練改成 `ros2 run` 只起 `robot_state_publisher`（用 `-p robot_description:="$(cat xxx.urdf)"` 帶入已展開的 URDF）＋ 非 GUI 的 `joint_state_publisher`，改用 `tf2_echo` 與 `topic echo` 驗證。launch 檔本身沒改。
3. **關節角固定 0**：沒有 GUI 滑桿，所以 TF 只驗證了零位；要看轉動效果可改發 `/joint_states`（沒做）。
4. **link 樹圖**：書上 repo 附 `rrbot.pdf`；這裡自己用 `urdf_to_graphviz` 對三個模型重產，再用 `pdftoppm -r 80` 轉 PNG。
5. **Gazebo**（`rosbot_description/launch/gazebo.launch.py`）屬下一章範圍，本章任務未要求，沒跑。
6. 額外做了 `prefix:=left_` 的 xacro 參數測試，示範 macro 重用。
