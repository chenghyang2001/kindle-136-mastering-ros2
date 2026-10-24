#!/bin/bash
set -eo pipefail
S=~/k136_ws/ch12/src/rf2o_laser_odometry/src
grep -n "ranges\|range_wf(" $S/*.cpp | head
sed -n 20,60p $S/CLaserOdometry2DNode.cpp
cd ~/ros2_books/Mastering-ROS-2-for-Robotics-Programming && git log --oneline -3 -- Chapter12/rf2o_laser_odometry || true
