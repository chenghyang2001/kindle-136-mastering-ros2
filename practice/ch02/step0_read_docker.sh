#!/bin/bash
# 讀書本 Chapter02 的 Docker 相關檔案（只讀，不建 image）
set -eo pipefail
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter02
cd "$BOOK/ros2_jazzy_docker"
for f in docker_basics/Dockerfile docker_basics/Dockerfile.basic docker_gui/Dockerfile.master_ros2 \
         docker_gui/build_image.sh docker_gui/create_container.sh docker_gui/ros_entrypoint.sh \
         docker_compose/docker-compose.yml; do
  echo "===== $f"
  cat "$f"
  echo
done
echo "===== 本機安裝狀態"
dpkg -l | grep -E "ros2-apt-source|ros-jazzy-desktop|ros-jazzy-ros-base|ros-dev-tools" || true
ls /etc/apt/sources.list.d/ | grep -i ros || true
echo "docker 指令位置：$(command -v docker || echo 無)"
