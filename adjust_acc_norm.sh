#!/bin/bash
# ==========================================
# 调整 acc_norm 以适应更大的加速度读数
# ==========================================
# 用途：如果IMU加速度读数比标准值大，调整 acc_norm 来适应
# ==========================================

CONFIG_FILE="/home/nyu/nav_ws/src/point_lio_ros2/config/unilidar_l2.yaml"

echo "=========================================="
echo "调整 acc_norm 以适应更大的加速度读数"
echo "=========================================="
echo ""

# 检查 IMU topic 是否存在
if ! timeout 2 ros2 topic list | grep -q "/unilidar/imu"; then
    echo "⚠️  未找到 /unilidar/imu topic，将使用默认值"
    echo ""
    read -p "请输入 acc_norm 值（默认: 11.0）: " ACC_NORM
    ACC_NORM=${ACC_NORM:-11.0}
else
    echo ">>> 正在测量当前IMU加速度..."
    echo ">>> 请确保机器人保持静止！"
    echo ""
    
    # 收集一些IMU数据来计算平均加速度模长
    ACC_DATA=$(timeout 3 ros2 topic echo /unilidar/imu --once 2>/dev/null | grep -A 3 "linear_acceleration:" | head -4)
    
    if [ -z "$ACC_DATA" ]; then
        echo "⚠️  无法读取IMU数据，将使用默认值"
        read -p "请输入 acc_norm 值（默认: 11.0）: " ACC_NORM
        ACC_NORM=${ACC_NORM:-11.0}
    else
        # 提取加速度值
        X=$(echo "$ACC_DATA" | grep "x:" | awk '{print $2}')
        Y=$(echo "$ACC_DATA" | grep "y:" | awk '{print $2}')
        Z=$(echo "$ACC_DATA" | grep "z:" | awk '{print $2}')
        
        if [ -n "$X" ] && [ -n "$Y" ] && [ -n "$Z" ]; then
            # 计算模长
            NORM=$(python3 -c "import math; x=$X; y=$Y; z=$Z; print(math.sqrt(x*x + y*y + z*z))")
            echo "当前IMU加速度: x=$X, y=$Y, z=$Z"
            echo "加速度模长: $NORM m/s²"
            echo ""
            
            # 根据模长推荐 acc_norm
            if (( $(echo "$NORM > 15" | bc -l) )); then
                RECOMMENDED=16.0
            elif (( $(echo "$NORM > 12" | bc -l) )); then
                RECOMMENDED=13.0
            elif (( $(echo "$NORM > 10" | bc -l) )); then
                RECOMMENDED=11.0
            else
                RECOMMENDED=9.81
            fi
            
            echo "推荐 acc_norm: $RECOMMENDED (基于当前加速度模长)"
            read -p "请输入 acc_norm 值（默认: $RECOMMENDED）: " ACC_NORM
            ACC_NORM=${ACC_NORM:-$RECOMMENDED}
        else
            echo "⚠️  无法解析IMU数据，将使用默认值"
            read -p "请输入 acc_norm 值（默认: 11.0）: " ACC_NORM
            ACC_NORM=${ACC_NORM:-11.0}
        fi
    fi
fi

echo ""
echo ">>> 正在更新配置..."
echo ""

# 备份当前配置
BACKUP_FILE="${CONFIG_FILE}.backup_before_acc_norm_$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ 已备份当前配置到: $BACKUP_FILE"
echo ""

# 使用 sed 直接修改 acc_norm（保持YAML格式）
sed -i "s/acc_norm:.*#.*/acc_norm: $ACC_NORM # 1.0 for g as unit, 9.81 for m\/s^2 as unit of the IMU's acceleration/" "$CONFIG_FILE"

if [ $? -eq 0 ]; then
    echo "✅ acc_norm 已更新为: $ACC_NORM"
    echo ""
    echo "=========================================="
    echo "✅ 配置已更新"
    echo "=========================================="
    echo ""
    echo "重要提示："
    echo "1. 必须重新编译 Point-LIO 才能使配置生效："
    echo "   cd ~/nav_ws"
    echo "   colcon build --packages-select point_lio"
    echo "   source install/setup.bash"
    echo ""
    echo "2. 确保 start_in_aggressive_motion: true（使用预设重力方向）"
    echo "   这样可以避免从IMU初始化时计算重力方向，减少飞走的风险"
    echo ""
    echo "3. 然后重新启动导航系统测试"
    echo ""
else
    echo "❌ 配置更新失败！"
    exit 1
fi
