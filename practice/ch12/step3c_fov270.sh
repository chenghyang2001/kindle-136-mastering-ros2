#!/bin/bash
# 對照實驗：假 scan 改成前方 270 度，看 rf2o 的 /odom 方向是否正確
set -eo pipefail
export FAKE_FOV_DEG=270 TAG=_fov270
bash ./step3_fake_scan_rf2o.sh
