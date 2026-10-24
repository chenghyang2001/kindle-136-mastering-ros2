#!/bin/bash
set -eo pipefail
S=~/k136_ws/ch12/src/rf2o_laser_odometry/src
grep -n "fovh\|angle_min\|angle_max\|tita\|laser_pose_on_robot\|inverse\|kai_loc" $S/*.cpp | head -40
