# K136 第 2 章補做：用 Docker 跑 ROS 2 talker／listener

2026-10-25，DESKTOP-6LST1BR（hp2）。第一次演練時第 2 章誤判「沒有 Docker」，只讀 Dockerfile；其實這台有 Docker Desktop 4.91.0，只是沒啟動。這次補做書上 `Chapter02/ros2_jazzy_docker/docker_compose` 的範例。

## 環境設定

1. 啟動 Docker Desktop（引擎 29.8.0，WSL2 後端）。
2. 開啟 WSL 整合：`%APPDATA%\Docker\settings-store.json` 加 `EnableIntegrationWithDefaultWslDistro: true`、`IntegratedWslDistros: ["Ubuntu-24.04"]`，重啟 Docker Desktop。之後在 Ubuntu 裡直接打 `docker` 即可（使用者已在 docker 群組）。
3. 下載書上用的 image：`docker pull osrf/ros:jazzy-desktop-full`（6.35 GB，這台網速約 1 MB/s，花了約 50 分鐘）。

書上原檔複製在 `book_files/`（`docker-compose.yml`、`docker-compose1.yml`、`Dockerfile`、`Dockerfile.basic`），沒有修改。

## 測試結果

| # | 做法 | 結果 | log |
| --- | --- | --- | --- |
| 1 | `docker compose -f docker-compose.yml up`：兩個容器，預設 bridge 網路、Fast DDS | ✅ listener 每秒收到 `Hello World: N` | `logs/test1_compose_bridge.log` |
| 2 | 容器 talker（`--net=host`）↔ WSL 本機 listener，雙向 | ❌ 收不到 | `logs/test2_container_host.log` |
| 3 | 同上，再開 Docker Desktop「host networking」 | ❌ 收不到 | `logs/test3_host_networking.log` |
| 4 | 同上，兩邊 `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`（排除共享記憶體） | ❌ 收不到 | `logs/test4_udp_only.log` |
| 5 | `docker compose -f docker-compose1.yml up`：host 網路，容器內安裝 Cyclone DDS | ✅ 容器之間互通 | `logs/test5_compose_host_cyclone.log` |

## 為什麼容器和 WSL 本機的 ROS 2 不通

Docker Desktop 的容器跑在它自己的虛擬機裡。容器裡的 `--net=host` 看到的網卡是 `192.168.65.x`、`172.17.0.1`（Docker 虛擬機），
而 WSL Ubuntu 是 `192.168.1.103`（mirrored 網路）。兩邊不在同一個網段，DDS 的多播探索找不到對方。
書上是在「Ubuntu 本機裝 Docker Engine」的情境，那時 `--net=host` 就是 Ubuntu 自己的網路，容器和本機可以直接互通。

## 和書上做法的差異

- 書上在 Ubuntu 裡用 `docker_setup_scripts/setup_docker_ubuntu.sh` 裝 Docker Engine；這裡用 Windows 的 Docker Desktop＋WSL 整合。
- 容器之間互通（書上的兩個 compose 範例）結果和書上一樣；容器 ↔ 本機互通在 Docker Desktop 下做不到。
- 要做到容器 ↔ WSL 本機互通，可改成在 Ubuntu 裡裝 Docker Engine（書上的腳本），並關掉 Docker Desktop 的 WSL 整合，以免兩個 docker 互相干擾；image 可用 `docker save`／`docker load` 搬過去，不用重新下載。
