from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, GroupAction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare
import os

def generate_launch_description():
    # Get the config directory
    config_dir = os.path.join(os.path.expanduser('~'), 'nav_ws', 'configs', 'unitree_l2_complete')
    
    # Declare launch arguments
    use_sim_time_arg = DeclareLaunchArgument('use_sim_time', default_value='false')
    map_file_arg = DeclareLaunchArgument('map', default_value='')
    
    # Unitree Lidar L2 driver
    unitree_lidar_node = Node(
        package='unitree_lidar_ros2',
        executable='unitree_lidar_ros2_node',
        name='unitree_lidar_ros2_node',
        output='screen',
        parameters=[{
            'initialize_type': 1,
            'work_mode': 0,
            'use_system_timestamp': True,
            'range_min': 0.5,
            'range_max': 100.0,
            'cloud_scan_num': 18,
            'serial_port': '/dev/ttyACM0',
            'baudrate': 4608000,
            'lidar_port': 6101,
            'lidar_ip': '192.168.1.62',
            'local_port': 6201,
            'local_ip': '192.168.1.2',
            'cloud_frame': 'unilidar_lidar',
            'cloud_topic': 'unilidar/cloud',
            'imu_frame': 'unilidar_imu',
            'imu_topic': 'unilidar/imu',
        }]
    )
    
    # Static TF publishers
    tf_odom_camera = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        arguments=['0', '0', '0', '0', '0', '0', 'odom', 'camera_init'],
        name='tf_odom_camera'
    )
    
    tf_aft_base = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        arguments=['0', '0', '0', '0', '0', '0', 'aft_mapped', 'base_link'],
        name='tf_aft_base'
    )
    
    tf_base_imu = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        arguments=['0', '0', '0', '0', '0', '0', 'base_link', 'unilidar_imu_initial'],
        name='tf_base_imu'
    )
    
    tf_base_footprint = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        arguments=['0', '0', '0', '0', '0', '0', 'base_link', 'base_footprint'],
        name='tf_base_footprint'
    )
    
    # Point-LIO
    point_lio_node = Node(
        package='point_lio',
        executable='pointlio_mapping',
        name='laserMapping',
        output='screen',
        parameters=[
            os.path.join(config_dir, 'point_lio_config.yaml'),
            {
                'use_imu_as_input': False,
                'prop_at_freq_of_imu': True,
                'check_satu': True,
                'init_map_size': 10,
                'point_filter_num': 3,
                'space_down_sample': True,
                'filter_size_surf': 0.5,
                'filter_size_map': 0.5,
                'cube_side_length': 1000.0,
                'runtime_pos_log_enable': False,
            }
        ],
        prefix='bash -c "export LD_PRELOAD=/lib/x86_64-linux-gnu/libusb-1.0.so.0; exec $0 $@" --'
    )
    
    # Pointcloud to LaserScan
    pointcloud_to_laserscan_node = Node(
        package='pointcloud_to_laserscan',
        executable='pointcloud_to_laserscan_node',
        name='pointcloud_to_laserscan',
        parameters=[os.path.join(config_dir, 'pointcloud_to_laserscan_params.yaml')],
        remappings=[
            ('cloud_in', '/unilidar/cloud'),
            ('scan', '/scan')
        ]
    )
    
    # Nav2
    nav2_bringup_node = Node(
        package='nav2_bringup',
        executable='bringup_launch.py',
        name='nav2_bringup',
        output='screen',
        parameters=[
            os.path.join(config_dir, 'nav2_params.yaml'),
            {
                'use_sim_time': LaunchConfiguration('use_sim_time'),
                'map': LaunchConfiguration('map'),
            }
        ]
    )
    
    return LaunchDescription([
        use_sim_time_arg,
        map_file_arg,
        unitree_lidar_node,
        tf_odom_camera,
        tf_aft_base,
        tf_base_imu,
        tf_base_footprint,
        point_lio_node,
        pointcloud_to_laserscan_node,
        nav2_bringup_node,
    ])
