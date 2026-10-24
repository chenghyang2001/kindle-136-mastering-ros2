#!/bin/bash
B=~/ros2_books/Mastering-ROS-2-for-Robotics-Programming/Chapter05
cat $B/diffbot_gazebo/urdf/gz/diffbot.gazebo.xacro
grep -n -i -E "gazebo|plugin|include" $B/diffbot_gazebo/urdf/gz/diffbot.xacro
grep -n -E "plugin|parameters|<topic" $B/rrbot_gazebo/urdf/*.xacro
cat $B/diffbot_gazebo/CMakeLists.txt $B/rrbot_gazebo/CMakeLists.txt | grep -v "^#"
