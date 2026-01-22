#!/bin/bash
# ==========================================
# 测试并调整 acc_norm
# ==========================================

echo "=========================================="
echo "测试当前IMU加速度并计算合适的 acc_norm"
echo "=========================================="
echo ""
echo ">>> 请确保机器人保持完全静止！"
echo ">>> 正在收集IMU数据（5秒）..."
echo ""

# 收集IMU数据
python3 << 'EOF'
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Imu
import numpy as np
import time

class IMUTester(Node):
    def __init__(self):
        super().__init__('imu_tester')
        self.acc_data = []
        self.subscription = self.create_subscription(
            Imu,
            '/unilidar/imu',
            self.imu_callback,
            10)
        
    def imu_callback(self, msg):
        acc = msg.linear_acceleration
        norm = np.sqrt(acc.x**2 + acc.y**2 + acc.z**2)
        self.acc_data.append([acc.x, acc.y, acc.z, norm])
        
    def get_stats(self):
        if len(self.acc_data) == 0:
            return None
        data = np.array(self.acc_data)
        return {
            'mean_x': np.mean(data[:, 0]),
            'mean_y': np.mean(data[:, 1]),
            'mean_z': np.mean(data[:, 2]),
            'mean_norm': np.mean(data[:, 3]),
            'std_norm': np.std(data[:, 3]),
            'min_norm': np.min(data[:, 3]),
            'max_norm': np.max(data[:, 3]),
            'count': len(self.acc_data)
        }

rclpy.init()
node = IMUTester()

print(">>> 开始收集数据...")
time.sleep(5)

stats = node.get_stats()
if stats:
    print("\n==========================================")
    print("IMU 加速度统计（静止时）")
    print("==========================================")
    print(f"平均加速度: x={stats['mean_x']:.3f}, y={stats['mean_y']:.3f}, z={stats['mean_z']:.3f}")
    print(f"加速度模长: 平均={stats['mean_norm']:.3f} m/s², 标准差={stats['std_norm']:.3f}")
    print(f"模长范围: {stats['min_norm']:.3f} ~ {stats['max_norm']:.3f} m/s²")
    print(f"样本数: {stats['count']}")
    print("")
    print(f"✅ 建议 acc_norm 设置为: {stats['mean_norm']:.2f}")
    print("")
    print("如果标准差较大（>1.0），说明有振动，可以：")
    print("1. 增大 acc_norm 到稍大于平均值（如 +1.0）")
    print("2. 增大 imu_meas_acc_cov 来减少噪声影响")
    print("")
else:
    print("❌ 未收集到IMU数据，请检查：")
    print("1. /unilidar/imu topic 是否存在")
    print("2. 雷达驱动是否已启动")

node.destroy_node()
rclpy.shutdown()
EOF

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
