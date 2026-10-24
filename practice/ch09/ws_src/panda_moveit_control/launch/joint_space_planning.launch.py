from launch import LaunchDescription
from launch_ros.actions import Node
from moveit_configs_utils import MoveItConfigsBuilder
import launch_ros.actions

def generate_launch_description():
    moveit_config = MoveItConfigsBuilder("panda").to_moveit_configs()
    launch_ros.actions.SetParameter(name='use_sim_time', value=True)
    tutorial_node = Node(
        package="panda_moveit_control",
        executable="joint_space_planning",
        output="screen",
        parameters=[
            {"use_sim_time": False},  # 本演練改：mock 硬體無 /clock
            moveit_config.robot_description,
            moveit_config.robot_description_semantic,
            moveit_config.robot_description_kinematics,
        ],

    )

    return LaunchDescription([tutorial_node])