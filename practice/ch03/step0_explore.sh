#!/bin/bash
# 瀏覽書本 Chapter03 結構（只讀）
set -eo pipefail
BOOK=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter03
cd "$BOOK"
find . -type f | grep -v '/\.' | sort
for f in $(find . -name '*.launch.py' -o -name '*.msg' -o -name '*.srv' -o -name '*.action' -o -name 'CMakeLists.txt' -o -name 'package.xml' -o -name '*.yaml' | sort); do
  echo "===== $f"; cat "$f"; echo
done
