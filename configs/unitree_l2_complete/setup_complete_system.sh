#!/bin/bash

# ============================================
# 从零开始设置 Unitree Lidar L2 完整系统
# ============================================

echo "=========================================="
echo "从零开始设置 Unitree Lidar L2 完整系统"
echo "=========================================="
echo ""

cd ~/nav_ws
CONFIG_DIR="$HOME/nav_ws/configs/unitree_l2_complete"

# 检查配置目录
if [ ! -d "$CONFIG_DIR" ]; then
    echo "❌ 配置目录不存在: $CONFIG_DIR"
    exit 1
fi

echo ">>> [1/5] 备份现有配置..."
# 备份 Point-LIO 配置
if [ -f "src/point_lio_ros2/config/unilidar_l2.yaml" ]; then
    BACKUP_NAME="unilidar_l2.yaml.backup_$(date +%Y%m%d_%H%M%S)"
    cp src/point_lio_ros2/config/unilidar_l2.yaml \
       "src/point_lio_ros2/config/$BACKUP_NAME"
    echo "✅ 已备份到: $BACKUP_NAME"
fi

# 备份 Nav2 配置
if [ -f "my_nav2_params.yaml" ]; then
    BACKUP_NAME="my_nav2_params.yaml.backup_$(date +%Y%m%d_%H%M%S)"
    cp my_nav2_params.yaml "$BACKUP_NAME"
    echo "✅ 已备份 Nav2 配置到: $BACKUP_NAME"
fi
echo ""

echo ">>> [2/5] 应用新配置..."
# 复制 Point-LIO 配置
cp "$CONFIG_DIR/point_lio_config.yaml" \
   src/point_lio_ros2/config/unilidar_l2.yaml
echo "✅ Point-LIO 配置已应用"

# 复制 Nav2 配置（可选，保留原有配置）
if [ ! -f "my_nav2_params.yaml" ]; then
    cp "$CONFIG_DIR/nav2_params.yaml" my_nav2_params.yaml
    echo "✅ Nav2 配置已应用"
else
    echo "ℹ️  保留现有 Nav2 配置"
fi
echo ""

echo ">>> [3/5] 编译工作空间..."
source /opt/ros/humble/setup.bash
colcon build --packages-select point_lio
if [ $? -eq 0 ]; then
    echo "✅ 编译成功"
else
    echo "❌ 编译失败"
    exit 1
fi
echo ""

echo ">>> [4/5] 验证配置..."
source install/setup.bash

# 检查配置文件
if [ -f "src/point_lio_ros2/config/unilidar_l2.yaml" ]; then
    echo "✅ Point-LIO 配置文件存在"
else
    echo "❌ Point-LIO 配置文件不存在"
    exit 1
fi

# 检查必要的包
if ros2 pkg list | grep -q "point_lio"; then
    echo "✅ point_lio 包已安装"
else
    echo "❌ point_lio 包未找到"
    exit 1
fi

if ros2 pkg list | grep -q "nav2_bringup"; then
    echo "✅ nav2_bringup 包已安装"
else
    echo "⚠️  警告: nav2_bringup 包未找到，请安装 Nav2"
fi

if ros2 pkg list | grep -q "pointcloud_to_laserscan"; then
    echo "✅ pointcloud_to_laserscan 包已安装"
else
    echo "⚠️  警告: pointcloud_to_laserscan 包未找到，请安装"
fi
echo ""

echo ">>> [5/5] 完成！"
echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "配置文件位置："
echo "  - Point-LIO: src/point_lio_ros2/config/unilidar_l2.yaml"
echo "  - Nav2: my_nav2_params.yaml (如果已复制)"
echo ""
echo "启动系统："
echo "  cd ~/nav_ws"
echo "  source install/setup.bash"
echo "  ./configs/unitree_l2_complete/start_complete_system.sh [地图文件路径]"
echo ""
echo "或者使用原来的启动脚本："
echo "  ./start_robot.sh"
echo ""
echo "=========================================="
