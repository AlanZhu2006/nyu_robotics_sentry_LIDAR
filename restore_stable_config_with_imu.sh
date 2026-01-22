#!/bin/bash
# ==========================================
# 恢复到稳定配置并调整 acc_norm 以支持IMU
# ==========================================
# 用途：恢复到之前"完全没有问题"的配置，然后调整 acc_norm 让IMU能正常工作
# ==========================================

CONFIG_FILE="/home/nyu/nav_ws/src/point_lio_ros2/config/unilidar_l2.yaml"

echo "=========================================="
echo "恢复到稳定配置并调整 acc_norm"
echo "=========================================="
echo ""

# 备份当前配置
BACKUP_FILE="${CONFIG_FILE}.backup_before_restore_$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ 已备份当前配置到: $BACKUP_FILE"
echo ""

# 读取用户输入的 acc_norm 值
echo "请输入 acc_norm 的值（用于归一化加速度）："
echo "  - 如果IMU加速度模长约为 9.81 m/s²，使用 9.81"
echo "  - 如果IMU加速度模长约为 11-12 m/s²，使用 11.0"
echo "  - 如果IMU加速度模长约为 16 m/s²，使用 16.0"
echo ""
read -p "acc_norm (默认: 11.0): " ACC_NORM
ACC_NORM=${ACC_NORM:-11.0}
echo ""

echo ">>> 正在恢复配置..."
echo ""

# 使用 Python 来精确修改 YAML
python3 << EOF
import yaml
import sys

config_file = "$CONFIG_FILE"

# 读取配置
with open(config_file, 'r') as f:
    content = f.read()
    # 移除开头的 /**:
    if content.startswith('/**:'):
        content = content[4:].lstrip()
    config = yaml.safe_load(content)

# 恢复稳定配置
config['/**']['ros__parameters']['mapping']['imu_en'] = True
config['/**']['ros__parameters']['mapping']['start_in_aggressive_motion'] = True
config['/**']['ros__parameters']['mapping']['gravity_align'] = True
config['/**']['ros__parameters']['mapping']['gravity'] = [0.0, 0.0, -9.810]
config['/**']['ros__parameters']['mapping']['gravity_init'] = [0.0, 0.0, -9.810]
config['/**']['ros__parameters']['mapping']['acc_norm'] = $ACC_NORM

# 恢复其他稳定参数
config['/**']['ros__parameters']['mapping']['imu_meas_acc_cov'] = 0.1
config['/**']['ros__parameters']['mapping']['imu_meas_omg_cov'] = 0.1
config['/**']['ros__parameters']['mapping']['acc_cov_input'] = 0.1
config['/**']['ros__parameters']['mapping']['time_lag_imu_to_lidar'] = 0.0

# 恢复外参为单位矩阵
config['/**']['ros__parameters']['mapping']['extrinsic_T'] = [0.007698, 0.014655, -0.00667]
config['/**']['ros__parameters']['mapping']['extrinsic_R'] = [
    1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 0.0, 1.0
]

# 写回文件
with open(config_file, 'w') as f:
    f.write('/**:\n')
    yaml.dump(config['/**'], f, default_flow_style=False, sort_keys=False, allow_unicode=True)

print("✅ 配置已更新")
print(f"   - imu_en: True")
print(f"   - start_in_aggressive_motion: True (使用预设重力方向，避免从IMU计算)")
print(f"   - acc_norm: $ACC_NORM (适应更大的加速度读数)")
print(f"   - gravity_align: True")
print(f"   - gravity: [0.0, 0.0, -9.810]")
print(f"   - gravity_init: [0.0, 0.0, -9.810]")
EOF

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ 配置更新失败！"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ 配置已恢复并调整"
echo "=========================================="
echo ""
echo "重要提示："
echo "1. 必须重新编译 Point-LIO 才能使配置生效："
echo "   cd ~/nav_ws"
echo "   colcon build --packages-select point_lio"
echo "   source install/setup.bash"
echo ""
echo "2. 然后重新启动导航系统测试"
echo ""
echo "3. 如果点云仍然倾斜，可能需要调整 gravity_init 来匹配实际安装角度"
echo ""
