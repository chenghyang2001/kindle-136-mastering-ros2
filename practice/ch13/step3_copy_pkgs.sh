#!/bin/bash
# 把工作區（已修正 540 度期望值）的兩個套件複製回練習資料夾 src/，讓 CI 範本有東西可建
set -eo pipefail
rm -rf src/first_gtest src/to_lowercase
cp -r ~/k136_ws/ch13/src/first_gtest ~/k136_ws/ch13/src/to_lowercase src/
find src -type f
