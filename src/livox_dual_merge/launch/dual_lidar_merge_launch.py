#!/usr/bin/env python3
"""
双雷达方案：两个独立驱动 + 合并节点
- 驱动1 (内置): 182 -> /livox/lidar_1, /livox/imu_1
- 驱动2 (USB): 114 -> /livox/lidar_2, /livox/imu_2
- 合并 -> /livox/lidar, /livox/imu (FAST-LIO 使用)
"""
import os
from launch import LaunchDescription
from launch_ros.actions import Node
from ament_index_python.packages import get_package_share_directory


def generate_launch_description():
    # livox_ros_driver2 config 路径
    livox_share = get_package_share_directory('livox_ros_driver2')
    config_182 = os.path.join(livox_share, 'config', 'MID360_config.json')
    config_114 = os.path.join(livox_share, 'config', 'MID360_usb_config.json')

    params_common = {
        'xfer_format': 1,
        'multi_topic': 0,
        'data_src': 0,
        'publish_freq': 10.0,
        'output_data_type': 0,
        'frame_id': 'livox_frame',
        'lvx_file_path': '/home/livox/livox_test.lvx',
        'cmdline_input_bd_code': 'livox0000000001',
    }

    driver_1 = Node(
        package='livox_ros_driver2',
        executable='livox_ros_driver2_node',
        name='livox_lidar_1',
        output='screen',
        parameters=[{**params_common, 'user_config_path': config_182}],
        remappings=[
            ('/livox/lidar', '/livox/lidar_1'),
            ('/livox/imu', '/livox/imu_1'),
        ],
    )

    driver_2 = Node(
        package='livox_ros_driver2',
        executable='livox_ros_driver2_node',
        name='livox_lidar_2',
        output='screen',
        parameters=[{**params_common, 'user_config_path': config_114}],
        remappings=[
            ('/livox/lidar', '/livox/lidar_2'),
            ('/livox/imu', '/livox/imu_2'),
        ],
    )

    merge_node = Node(
        package='livox_dual_merge',
        executable='merge_node',
        name='livox_dual_merge',
        output='screen',
    )

    return LaunchDescription([driver_1, driver_2, merge_node])
