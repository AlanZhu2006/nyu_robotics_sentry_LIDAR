#!/bin/bash

# --- 脚本功能：一键启动 激光雷达 + Point-LIO + Nav2 ---

# 捕捉 Ctrl+C 信号，退出时自动清理所有后台进程
trap 'echo "正在关闭所有节点..."; kill $(jobs -p); exit' SIGINT

echo ">>> [0/9] 清理环境..."
# 清理 FastRTPS 共享内存
rm -f /dev/shm/fastrtps_*
# 重启 ROS2 daemon
ros2 daemon stop
ros2 daemon start
# 停止所有 Point-LIO 相关进程（确保干净启动）
echo "   正在停止所有 Point-LIO 相关进程..."
pkill -9 -f pointlio_mapping 2>/dev/null
pkill -9 -f laserMapping 2>/dev/null
pkill -9 -f "point_lio" 2>/dev/null
pkill -9 -f "mapping_unilidar" 2>/dev/null
# 等待进程完全退出
sleep 2
# 再次检查并强制杀死残留进程
if pgrep -f "pointlio_mapping\|laserMapping\|point_lio" > /dev/null; then
    echo "   发现残留进程，强制清理..."
    pkill -9 -f pointlio_mapping 2>/dev/null
    pkill -9 -f laserMapping 2>/dev/null
    pkill -9 -f "point_lio" 2>/dev/null
    sleep 1
fi
# 清理 Point-LIO 的 Log 目录（避免旧日志影响）
if [ -d "src/point_lio_ros2/Log" ]; then
    rm -f src/point_lio_ros2/Log/*.txt 2>/dev/null
    echo "   已清理 Log 目录"
fi
echo "✅ 环境清理完成"

echo ">>> [1/9] 初始化环境..."
source /opt/ros/humble/setup.bash
# 假设你的工作空间在这里，根据实际情况修改
source ~/nav_ws/install/setup.bash 

echo ">>> [2/9] 设置串口权限 (如果卡在这里，请输入密码)..."
# 建议永久解决权限问题，避免每次都 sudo
if [ -e /dev/ttyACM0 ]; then
    sudo chmod 777 /dev/ttyACM0
else
    echo "警告: 未检测到 /dev/ttyACM0，跳过权限设置"
fi

echo ">>> [3/9] 启动 Unitree 激光雷达驱动..."
# 先停止可能存在的旧驱动进程
pkill -f livox_ros_driver2_node 2>/dev/null
sleep 1

# 清理串口（释放可能被占用的串口）
if [ -e /dev/ttyACM0 ]; then
    fuser -k /dev/ttyACM0 2>/dev/null
    sleep 0.5
fi

# 启动驱动
ros2 launch unitree_lidar_ros2 launch.py &
DRIVER_PID=$!
echo ">>> 等待雷达驱动启动 (5秒)..."
sleep 5

# 验证驱动是否正常启动并发布数据
DRIVER_OK=false
for i in {1..3}; do
    if pgrep -f "unitree_lidar_ros2_node" > /dev/null && \
       timeout 2 ros2 topic echo /unilidar/cloud --once > /dev/null 2>&1 && \
       timeout 2 ros2 topic echo /unilidar/imu --once > /dev/null 2>&1; then
        DRIVER_OK=true
        break
    fi
    echo "   重试检查 ($i/3)..."
    sleep 2
done

if [ "$DRIVER_OK" = true ]; then
    echo "✅ 雷达驱动已启动并正常发布数据"
else
    echo "⚠️  警告: 雷达驱动可能未正常启动或卡住"
    echo "   尝试重启驱动..."
    pkill -f unitree_lidar_ros2_node 2>/dev/null
    sleep 2
    ros2 launch unitree_lidar_ros2 launch.py &
    sleep 5
    echo "   请手动检查驱动状态: ./check_driver_health.sh"
fi

echo ">>> [4/9] 发布静态 TF 变换..."
# 保持你原来的 TF 树配置
ros2 run tf2_ros static_transform_publisher 0 0 0 0 0 0 odom camera_init &
ros2 run tf2_ros static_transform_publisher 0 0 0 0 0 0 aft_mapped base_link &
ros2 run tf2_ros static_transform_publisher 0 0 0 0 0 0 base_link unilidar_imu_initial &
ros2 run tf2_ros static_transform_publisher 0 0 0 0 0 0 base_link base_footprint &

echo ">>> [5/9] 启动 Point-LIO 里程计..."
# 设置 libusb 环境变量（修复 PCL 兼容性问题）
export LD_PRELOAD=/lib/x86_64-linux-gnu/libusb-1.0.so.0

# 关键：确保 IMU 数据稳定后再启动 Point-LIO
echo ">>> 检查并等待 IMU 数据稳定..."
IMU_STABLE=false
for i in {1..10}; do
    # 收集一些 IMU 数据检查稳定性
    ACC_DATA=$(timeout 2 ros2 topic echo /unilidar/imu --once 2>/dev/null | grep -A 3 "linear_acceleration:" | head -4)
    if [ -n "$ACC_DATA" ]; then
        X=$(echo "$ACC_DATA" | grep "x:" | awk '{print $2}')
        Y=$(echo "$ACC_DATA" | grep "y:" | awk '{print $2}')
        Z=$(echo "$ACC_DATA" | grep "z:" | awk '{print $2}')
        if [ -n "$X" ] && [ -n "$Y" ] && [ -n "$Z" ]; then
            # 计算加速度模长
            NORM=$(python3 -c "import math; x=$X; y=$Y; z=$Z; print(math.sqrt(x*x + y*y + z*z))" 2>/dev/null)
            if [ -n "$NORM" ]; then
                # 检查模长是否在合理范围内（8-12 m/s²）
                if (( $(echo "$NORM >= 8.0 && $NORM <= 12.0" | bc -l 2>/dev/null || echo "0") )); then
                    echo "   IMU 数据稳定: 模长=${NORM%.2f} m/s² (第 $i 次检查)"
                    if [ $i -ge 3 ]; then
                        IMU_STABLE=true
                        break
                    fi
                else
                    echo "   IMU 数据异常: 模长=${NORM%.2f} m/s²，继续等待..."
                fi
            fi
        fi
    fi
    sleep 1
done

if [ "$IMU_STABLE" != true ]; then
    echo "⚠️  警告: IMU 数据可能不稳定，但继续启动 Point-LIO"
    echo "   如果出现问题，请确保设备完全静止后重新启动"
    # 如果数据不稳定，额外等待更长时间
    echo ">>> 额外等待 3 秒确保 IMU 数据稳定..."
    sleep 3
else
    # 数据已经稳定，只需要短暂等待确保完全稳定（因为配置了 start_in_aggressive_motion: true，不需要从IMU计算重力）
    echo ">>> IMU 数据已稳定，短暂等待 1 秒后启动 Point-LIO..."
    sleep 1
fi

# 启动前最后检查：确保没有残留进程
if pgrep -f "pointlio_mapping\|laserMapping\|point_lio" > /dev/null; then
    echo "⚠️  警告: 发现残留的 Point-LIO 进程，正在清理..."
    pkill -9 -f pointlio_mapping 2>/dev/null
    pkill -9 -f laserMapping 2>/dev/null
    pkill -9 -f "point_lio" 2>/dev/null
    sleep 2
fi

# 启动 Point-LIO（在设置了环境变量的 shell 中）
# 使用 bash -c 确保环境变量正确传递
echo ">>> 正在启动 Point-LIO（请确保设备完全静止！）..."
bash -c "export LD_PRELOAD=/lib/x86_64-linux-gnu/libusb-1.0.so.0 && ros2 launch point_lio mapping_unilidar_l2.launch.py rviz:=false" &
POINTLIO_PID=$!

echo ">>> 等待 Point-LIO 进程启动..."
# 等待 Point-LIO 进程启动
sleep 4

# 验证 Point-LIO 是否成功启动
# 检查进程名（可能是 pointlio_mapping 或通过 launch 启动的其他名称）
POINTLIO_RUNNING=false
for i in {1..5}; do
    if pgrep -f "pointlio_mapping" > /dev/null || \
       pgrep -f "laserMapping" > /dev/null || \
       pgrep -f "point_lio" > /dev/null; then
        POINTLIO_RUNNING=true
        break
    fi
    sleep 1
done

if [ "$POINTLIO_RUNNING" != true ]; then
    echo "❌ 错误: Point-LIO 启动失败！"
    echo "   请检查日志或手动启动: ros2 launch point_lio mapping_unilidar_l2.launch.py"
    echo "   如果实际上已经启动，可以忽略此错误并继续"
    read -p "   按 Enter 继续，或 Ctrl+C 退出..." 
fi

# 等待 IMU 初始化完成（MAX_INI_COUNT = 100，需要约 100 个 LiDAR 帧）
# LiDAR 频率约 10 Hz，100 帧需要约 10 秒，加上安全余量
echo ">>> 等待 Point-LIO IMU 初始化完成（需要约 100 个 LiDAR 帧，约 15 秒）..."
echo "   ⚠️  重要：请确保设备在此过程中完全静止！"
INIT_COMPLETE=false
ODOM_STABLE=false
for i in {1..25}; do
    sleep 1
    # 检查是否开始发布 odometry（初始化完成后会发布）
    if timeout 1 ros2 topic echo /aft_mapped_to_init --once > /dev/null 2>&1 || \
       timeout 1 ros2 topic echo /aft_mapped --once > /dev/null 2>&1; then
        if [ "$ODOM_STABLE" != true ]; then
            echo "   Point-LIO 已开始发布数据（第 $i 秒）"
            ODOM_STABLE=true
        fi
        # 检查 odometry 是否稳定（连续几次检查位置变化很小）
        if [ $i -ge 15 ]; then
            # 获取两次 odometry 数据，检查位置是否稳定
            ODOM1=$(timeout 1 ros2 topic echo /aft_mapped_to_init --once 2>/dev/null | grep -A 10 "pose:" | head -15)
            sleep 1
            ODOM2=$(timeout 1 ros2 topic echo /aft_mapped_to_init --once 2>/dev/null | grep -A 10 "pose:" | head -15)
            if [ -n "$ODOM1" ] && [ -n "$ODOM2" ]; then
                # 简单检查：如果两次数据都存在，认为初始化完成
                echo "   ✅ Point-LIO 初始化完成（odometry 已稳定发布）"
                INIT_COMPLETE=true
                break
            fi
        fi
    fi
    if [ $((i % 5)) -eq 0 ]; then
        echo "   等待中... ($i/25 秒) - 请保持设备静止！"
    fi
done

if [ "$INIT_COMPLETE" != true ]; then
    echo "⚠️  警告: Point-LIO 初始化可能未完成！"
    echo "   这可能导致点云旋转或飞走问题"
    echo "   建议："
    echo "     1. 确保设备完全静止"
    echo "     2. 检查 IMU 数据是否正常"
    echo "     3. 查看 Point-LIO 日志: tail -f src/point_lio_ros2/Log/*.txt"
    read -p "   按 Enter 继续（不推荐），或 Ctrl+C 退出重新启动..." 
else
    echo "✅ Point-LIO 初始化完成，可以开始使用"
fi

echo ">>> [6/9] 启动 Pointcloud 转 LaserScan..."
ros2 run pointcloud_to_laserscan pointcloud_to_laserscan_node --ros-args \
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

echo ">>> [7/9] 启动 Nav2 导航..."
ros2 launch nav2_bringup bringup_launch.py \
    use_sim_time:=False \
    map:=/home/nyu/Desktop/map/11_map.yaml \
    params_file:=/home/nyu/nav_ws/my_nav2_params.yaml &

echo ">>> 等待 Nav2 启动 (8秒)..."
sleep 15

echo ">>> [8/9] 自动设置初始位置 (解决 Costmap 等待问题)..."
for i in {1..5}
do
   ros2 topic pub -1 /initialpose geometry_msgs/msg/PoseWithCovarianceStamped "{header: {frame_id: 'map'}, pose: {pose: {position: {x: 0.0, y: 0.0, z: 0.0}, orientation: {w: 1.0}}}}" > /dev/null
   sleep 1
done

echo ">>> [9/9] 启动完成！"
echo "-----------------------------------------------------"
echo ">>> 机器人端所有节点已启动！"
echo ">>> 请在【你的笔记本电脑】上打开终端运行: rviz2"
echo ">>> 按 Ctrl+C 可以停止脚本并关闭所有节点"
echo ""
echo "💡 提示："
echo "   - Point-LIO 会在启动时进行 IMU 初始化（约 10-12 秒）"
echo "   - 初始化时请确保设备完全静止，处于你希望使用的姿态"
echo "   - 如果需要在不同姿态下使用，请重新启动脚本"
echo "   - 如果点云旋转，请检查配置中的 start_in_aggressive_motion 是否为 true"
echo "-----------------------------------------------------"

# 这是一个技巧：让脚本不退出，挂起等待，直到你按 Ctrl+C
ros2 run rviz2 rviz2 -d $(ros2 pkg prefix nav2_bringup)/share/nav2_bringup/rviz/nav2_default_view.rviz
