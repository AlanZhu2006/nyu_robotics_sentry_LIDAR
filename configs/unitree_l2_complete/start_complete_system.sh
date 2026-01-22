#!/bin/bash

# ============================================
# 完整的 Unitree Lidar L2 + Point-LIO + Nav2 系统启动脚本
# ============================================

# 捕捉 Ctrl+C 信号
trap 'echo "正在关闭所有节点..."; kill $(jobs -p) 2>/dev/null; exit' SIGINT

echo "=========================================="
echo "Unitree Lidar L2 完整系统启动"
echo "=========================================="
echo ""

# 配置目录
CONFIG_DIR="$HOME/nav_ws/configs/unitree_l2_complete"

# 检查配置目录
if [ ! -d "$CONFIG_DIR" ]; then
    echo "❌ 配置目录不存在: $CONFIG_DIR"
    exit 1
fi

echo ">>> [0/8] 清理环境..."
rm -f /dev/shm/fastrtps_*
ros2 daemon stop
ros2 daemon start
pkill -f pointlio_mapping 2>/dev/null
pkill -f laserMapping 2>/dev/null
pkill -f unitree_lidar 2>/dev/null
sleep 1
echo "✅ 环境清理完成"
echo ""

echo ">>> [1/8] 初始化环境..."
source /opt/ros/humble/setup.bash
source ~/nav_ws/install/setup.bash
echo "✅ 环境初始化完成"
echo ""

echo ">>> [2/8] 设置串口权限..."
if [ -e /dev/ttyACM0 ]; then
    sudo chmod 777 /dev/ttyACM0
    echo "✅ 串口权限已设置"
else
    echo "⚠️  警告: 未检测到 /dev/ttyACM0"
fi
echo ""

echo ">>> [3/8] 启动 Unitree 激光雷达驱动..."
ros2 launch unitree_lidar_ros2 launch.py &
echo ">>> 等待雷达驱动启动 (3秒)..."
sleep 3

# 验证雷达数据
if timeout 2 ros2 topic list | grep -q "/unilidar/cloud"; then
    echo "✅ 雷达驱动已启动"
else
    echo "⚠️  警告: 雷达驱动可能未完全启动"
fi
echo ""

echo ">>> [4/8] 发布静态 TF 变换..."
ros2 run tf2_ros static_transform_publisher 0 0 0 0 0 0 odom camera_init &
ros2 run tf2_ros static_transform_publisher 0 0 0 0 0 0 aft_mapped base_link &
ros2 run tf2_ros static_transform_publisher 0 0 0 0 0 0 base_link unilidar_imu_initial &
ros2 run tf2_ros static_transform_publisher 0 0 0 0 0 0 base_link base_footprint &
echo "✅ TF 变换已发布"
echo ""

echo ">>> [5/8] 启动 Point-LIO 里程计..."
export LD_PRELOAD=/lib/x86_64-linux-gnu/libusb-1.0.so.0

# 检查雷达和 IMU 数据
echo ">>> 检查传感器数据..."
timeout 5 bash -c 'until ros2 topic echo /unilidar/cloud --once > /dev/null 2>&1; do sleep 0.5; done' || echo "⚠️  警告: 雷达数据可能未就绪"
timeout 5 bash -c 'until ros2 topic echo /unilidar/imu --once > /dev/null 2>&1; do sleep 0.5; done' || echo "⚠️  警告: IMU 数据可能未就绪"

# 启动 Point-LIO
ros2 launch point_lio mapping_unilidar_l2.launch.py rviz:=false &
echo ">>> 等待 Point-LIO 初始化 (15秒，需要等待 IMU 初始化)..."
sleep 15
echo "✅ Point-LIO 已启动"
echo ""

echo ">>> [6/8] 启动 Pointcloud 转 LaserScan..."
ros2 run pointcloud_to_laserscan pointcloud_to_laserscan_node \
    --ros-args \
    -p target_frame:=base_link \
    -p transform_tolerance:=0.01 \
    -p min_height:=-0.4 \
    -p max_height:=1.0 \
    -p angle_min:=-3.1415 \
    -p angle_max:=3.1415 \
    -p range_min:=0.1 \
    -p range_max:=20.0 \
    -p use_inf:=true \
    -r cloud_in:=/unilidar/cloud \
    -r scan:=/scan &
echo "✅ Pointcloud 转 LaserScan 已启动"
echo ""

echo ">>> [7/8] 启动 Nav2 导航..."
# 检查地图文件参数
MAP_FILE="${1:-/home/nyu/Desktop/map/11_map.yaml}"
if [ ! -f "$MAP_FILE" ]; then
    echo "⚠️  警告: 地图文件不存在: $MAP_FILE"
    echo "   将启动 Nav2 但不加载地图（可以稍后加载）"
    MAP_FILE=""
fi

ros2 launch nav2_bringup bringup_launch.py \
    use_sim_time:=False \
    map:="$MAP_FILE" \
    params_file:="$CONFIG_DIR/nav2_params.yaml" &
echo ">>> 等待 Nav2 启动 (8秒)..."
sleep 8
echo "✅ Nav2 已启动"
echo ""

echo ">>> [8/8] 自动设置初始位置..."
for i in {1..5}
do
   ros2 topic pub -1 /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
       "{header: {frame_id: 'map'}, pose: {pose: {position: {x: 0.0, y: 0.0, z: 0.0}, orientation: {w: 1.0}}}}" \
       > /dev/null 2>&1
   sleep 1
done
echo "✅ 初始位置已设置"
echo ""

echo "=========================================="
echo "✅ 所有节点已启动！"
echo "=========================================="
echo ""
echo "系统组件："
echo "  ✅ Unitree Lidar L2 驱动"
echo "  ✅ Point-LIO 里程计"
echo "  ✅ Pointcloud 转 LaserScan"
echo "  ✅ Nav2 导航系统"
echo ""
echo "话题："
echo "  - /unilidar/cloud (点云)"
echo "  - /unilidar/imu (IMU)"
echo "  - /scan (激光扫描)"
echo "  - /odom (里程计)"
echo ""
echo "使用说明："
echo "  1. 在 RViz 中查看点云和地图"
echo "  2. 使用 2D Goal Pose 设置导航目标"
echo "  3. 按 Ctrl+C 停止所有节点"
echo ""
echo "=========================================="

# 保持脚本运行
wait
