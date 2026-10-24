#!/bin/bash
set -eo pipefail
B=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter12
grep -n "<link\|<joint\|parent\|child\|origin" $B/mobile_robot_model/urdf/mobile_robot.urdf
cat $B/ldlidar_sl_ros2/launch/ld20.launch.py
grep -n "declare_parameter\|lookupTransform\|frame_id\|waitFor\|RCLCPP_" $B/rf2o_laser_odometry/src/CLaserOdometry2DNode.cpp | head -60
cat $B/mobile_robot_model/CMakeLists.txt
