"""第 12 章 DIY 移動機器人模擬：gz server（房間世界）＋放入車子＋robot_state_publisher＋橋。
GUI 不在這裡開（server 模式 -s），演練時另外用 `gz sim -g` 開，才能用 gz_place.sh 擺到螢幕 3。"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.actions import Node


def generate_launch_description():
    pkg = get_package_share_directory('mobile_robot_sim')
    world = os.path.join(pkg, 'worlds', 'room.sdf')
    urdf_path = os.path.join(pkg, 'urdf', 'mobile_robot_sim.urdf')
    with open(urdf_path, encoding='utf-8') as f:
        urdf = f.read()

    gazebo = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(os.path.join(
            get_package_share_directory('ros_gz_sim'), 'launch', 'gz_sim.launch.py')),
        launch_arguments={'gz_args': f'{world} -s -r'}.items(),
    )

    rsp = Node(
        package='robot_state_publisher', executable='robot_state_publisher',
        name='robot_state_publisher', output='screen',
        parameters=[{'robot_description': urdf, 'use_sim_time': True}],
    )

    # 書上沒有這一步：真車是「開機就在地上」，模擬要先把模型放進世界
    spawn = Node(
        package='ros_gz_sim', executable='create', output='screen',
        arguments=['-topic', '/robot_description', '-name', 'mobile_robot',
                   '-x', '0', '-y', '0', '-z', '0.04'],
    )

    bridge = Node(
        package='ros_gz_bridge', executable='parameter_bridge', name='hw_bridge',
        output='screen',
        parameters=[{'config_file': os.path.join(pkg, 'config', 'bridge.yaml')}],
    )

    return LaunchDescription([gazebo, rsp, spawn, bridge])
