# K136 第 13 章：測試與 CI/CD（快速演練筆記）

> 快速 demo 模式：只求看懂流程，未經 QA／審查。ROS 2 Jazzy 跑在 WSL（Ubuntu-24.04），工作區 `~/k136_ws/ch13`。

## 做了什麼

| 步驟 | 腳本 | 紀錄 |
| --- | --- | --- |
| 複製 `first_gtest`、`to_lowercase`，`colcon build --symlink-install`，`colcon test` + `colcon test-result --verbose` | `step1_build_test.sh` | `logs/step1_build_test.log` |
| 故意改壞 `to_lowercase` 測試 → 看失敗訊息 → 改回；修正書本 `first_test` 的錯誤期望值 → 全綠 | `step2_break_and_fix.sh` | `logs/step2_break_and_fix.log` |
| 把（已修正的）兩個套件複製到本資料夾 `src/`，讓 CI 範本有東西可建 | `step3_copy_pkgs.sh` | `logs/step3_copy_pkgs.log` |
| 寫 `.github/workflows/ros2-ci.yml`，用 `python3 -c "import yaml"` 檢查語法 | `step4_check_yaml.sh` | `logs/step4_check_yaml.log` |
| 章末清理 + `timeout 15 ros2 daemon stop` | `cleanup.sh` | `logs/cleanup.log` |

## 驗證結果

### 1. 原封不動跑書本程式碼：`first_test` 一開始就失敗

```
[ RUN      ] AngleConversionTest.HandlesOverflowAngles
first_test.cpp:37: Failure
The difference between degreesToRadians(540) and 3.14159265358979323846 is 6.2831853071795862
    degreesToRadians(540) evaluates to -3.1415926535897931,
Summary: 7 tests, 0 errors, 2 failures, 0 skipped
```

原因：`degreesToRadians()` 把角度正規化到 **[-π, π)**（`while (radians >= M_PI)`），
所以 540° = 3π → π → -π。同一份測試裡 `180 → -M_PI` 也是這樣寫的，只有 540° 那行期望 `+M_PI`，前後不一致。
這是書本測試本身的 bug，不是環境問題。（`colcon test-result` 的「2 failures」是同一個失敗在 CTest XML 和 gtest XML 各算一次。）

`to_lowercase_test`（會真的建 node、收發 `/input`→`/output` topic）一次就過：`[  OK  ] package_name.UpperToLower (1821 ms)`。

### 2. 故意改壞再改回

把 `ASSERT_EQ(value, "tolower")` 改成 `"ToLower"`：

```
to_lowercase_test.cpp:36: Failure
Expected equality of these values:
  value
    Which is: "tolower"
  "ToLower"
[  FAILED  ] package_name.UpperToLower (1418 ms)
>>> test-result 回報有失敗（rc 非 0）
```

改回後：`Summary: 2 tests, 0 errors, 0 failures, 0 skipped`。

重點：**`colcon test` 遇測試失敗仍回 0，`colcon test-result` 才會回非 0**——CI 要靠後者（或 action-ros-ci）讓 job 變紅。

### 3. 修正 540° 期望值後全部重跑

```
Summary: 7 tests, 0 errors, 0 failures, 0 skipped
ALL_GREEN
```

### 4. YAML 語法檢查

```
PyYAML 6.0.1
triggers: ['push', 'pull_request', 'workflow_dispatch']
job build-and-test: runs-on=ubuntu-24.04, needs=None
   - ros-tooling/setup-ros@v0.7
   - ros-tooling/action-ros-ci@v0.4
job package: runs-on=ubuntu-24.04, needs=build-and-test
YAML_OK
```

小坑：PyYAML 用 YAML 1.1，會把 `on:` 解析成布林 `True`，檢查腳本要用 `doc.get(True)` 取觸發條件；GitHub 自己的解析器不受影響。

### 5. 清理

```
沒有殘留的 ROS／Gazebo 行程
=== 清理後檢查 ===
乾淨：無殘留
```

## CI 與 CD 在 ROS 2 專案的做法

**CI（持續整合）**：每次 push／PR 自動在乾淨環境證明「這份程式碼能建、測試會過」。

1. `actions/checkout` 取出程式碼。
2. `ros-tooling/setup-ros`：在 runner 上裝好指定發行版（這裡是 Jazzy，對應 `ubuntu-24.04`）、colcon、rosdep。
3. `ros-tooling/action-ros-ci`：自動建工作區 → `rosdep install` 補依賴 → `colcon build` → `colcon test` → `colcon test-result`，失敗就讓 job 失敗。`package-name` 指定要建／測的套件。
4. 上傳 `test_results/`（gtest XML）當 artifact，方便看失敗細節。
5. 要支援多版本就把 `ros_distro` 放進 matrix（例如 humble + jazzy，各配對應的 Ubuntu）。
6. 測試除了 gtest，還可以開 `ament_lint_auto`（cpplint、uncrustify、copyright…）；書本 CMakeLists 把 lint 註解掉了，本演練沿用。

**CD（持續交付／部署）**：CI 通過後把成果變成可安裝、可部署的東西。

- 本範本的 `package` job 只在 `v*` tag 觸發、`needs: build-and-test`，做 Release 建置並把 `install/` 打包成 tar.gz artifact（示範用）。
- 實務上常見的 ROS 2 CD 做法：
  - **Debian 套件**：`bloom-generate rosdebian` 產 `.deb`，放進自家 apt repo；或正式發佈到 ROS buildfarm（`bloom-release`）。
  - **Docker 映像**：以 `ros:jazzy-ros-base` 為底建映像，推到 GHCR／Docker Hub，機器人端 `docker pull` 更新。
  - **機器人端部署**：用 Ansible／OTA 工具把映像或 `.deb` 推到實機，搭配 systemd 啟動 launch 檔。
  - 機密（registry token、SSH key）放 GitHub Secrets，不寫進 yml。

## 和書上做法的差異

- **工作區副本有改動（書本 repo 原檔不動）**：
  - `first_gtest/test/first_test.cpp` 第 37 行：540° 期望值 `M_PI` → `-M_PI`，註記「本演練改」。原因見上。
  - `to_lowercase_test.cpp` 只是暫時改壞再還原，最後與書本相同。
- **CI 範本只寫檔、沒 push**，所以沒有在 GitHub Actions 上實際跑過；只驗證到 YAML 語法與結構。`upload-artifact` 的路徑 `ros_ws/build/*/test_results/` 是依 action-ros-ci 預設工作區名稱推測，實跑時可能需要調整。
- 本機測試用 Cyclone DDS（`RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`）＋ `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`＋ `ROS_DOMAIN_ID=36`；CI 範本只保留 LOCALHOST（runner 預設不一定裝 Cyclone DDS）。
- `colcon test` 用 `timeout 110` 包住，避免 `to_lowercase_test` 的 `while(!ready)` 在收不到訊息時無限等待——這也是書本測試的一個弱點：最好改成有上限的等待（例如 `spin_until_future_complete` 加逾時），否則 CI 上一旦 DDS 探索失敗，job 會卡到 GitHub 的 6 小時上限。
- 沒有圖形視窗、沒有硬體需求，本章不需模擬替代。
