#!/bin/bash
# 第 2 步：故意改壞 to_lowercase 測試看失敗訊息 → 改回；
# 再修正書本 first_test 540° 的期望值（只改工作區副本，本演練改），確認全綠
set -eo pipefail
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=36
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ip link show lo | grep -q MULTICAST || sudo ip link set lo multicast on

WS=~/k136_ws/ch13
T=$WS/src/to_lowercase/test/to_lowercase_test.cpp
F=$WS/src/first_gtest/test/first_test.cpp
cd "$WS"

run_tests() {
  colcon build --symlink-install --packages-select "$1" 2>&1 | tail -3
  timeout 110 colcon test --packages-select "$1" 2>&1 | tail -3 || true
  colcon test-result --verbose --test-result-base "build/$1" 2>&1 || echo ">>> test-result 回報有失敗（rc 非 0）"
}

echo "===== A. 故意改壞：期望值 \"tolower\" 改成 \"ToLower\" ====="
cp "$T" /tmp/to_lowercase_test.cpp.bak
sed -i 's/ASSERT_EQ(value, "tolower");/ASSERT_EQ(value, "ToLower");  \/\/ 本演練改：故意改壞/' "$T"
grep -n 'ASSERT_EQ' "$T"
run_tests to_lowercase

echo "===== B. 改回原狀 ====="
cp /tmp/to_lowercase_test.cpp.bak "$T"
grep -n 'ASSERT_EQ' "$T"
run_tests to_lowercase

echo "===== C. 修正書本 first_test：540° 正規化到 [-π, π) 應為 -π ====="
sed -i 's/EXPECT_NEAR(degreesToRadians(540), M_PI, 1e-9);/EXPECT_NEAR(degreesToRadians(540), -M_PI, 1e-9);  \/\/ 本演練改：區間為 [-π, π)/' "$F"
grep -n '540' "$F"

echo "===== D. 全部重跑 ====="
colcon build --symlink-install 2>&1 | tail -2
timeout 110 colcon test 2>&1 | tail -3 || true
colcon test-result --verbose 2>&1 && echo "ALL_GREEN" || echo "STILL_FAILING"
