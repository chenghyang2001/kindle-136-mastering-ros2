"""本演練改：書本 panda_moveit_config/launch/demo.launch.py 的無頭版。

書本版會開 RViz；這裡先把 use_rviz 設成 false 再交給 generate_demo_launch，
其餘（static TF、robot_state_publisher、move_group、ros2_control mock 硬體、
controller spawner）完全照書本設定套件。
"""
from launch import LaunchDescription
from launch.actions import SetLaunchConfiguration
from moveit_configs_utils import MoveItConfigsBuilder
from moveit_configs_utils.launches import generate_demo_launch


def generate_launch_description():
    moveit_config = MoveItConfigsBuilder(
        "panda", package_name="panda_moveit_config"
    ).to_moveit_configs()
    demo = generate_demo_launch(moveit_config)
    # DeclareLaunchArgument 不會覆蓋已設定的值，所以先設 false 就能關掉 RViz
    return LaunchDescription(
        [SetLaunchConfiguration("use_rviz", "false"), *demo.entities]
    )
