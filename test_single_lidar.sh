#!/bin/bash
# 单雷达测试（仅内置网口 enp114s0）
# 雷达 192.168.1.182 接内置网口

set -e
echo "=========================================="
echo "单雷达测试（内置网口）"
echo "=========================================="

echo ""
echo ">>> 1. 设置网口 IP..."
sudo ip addr add 192.168.1.2/24 dev enp114s0 2>/dev/null || true
ip addr show enp114s0 | grep "inet "

echo ""
echo ">>> 2. Ping 雷达 192.168.1.182..."
if ping -c 2 -I 192.168.1.2 192.168.1.182; then
    echo "   ✅ Ping 成功"
else
    echo "   ❌ Ping 失败，请检查："
    echo "      - 雷达已上电"
    echo "      - 网线接在内置网口"
    exit 1
fi

echo ""
echo ">>> 3. 启动 Livox 驱动（单雷达）..."
echo "   请观察是否有 'custom format' 或类似输出"
echo "   在另一终端运行: ros2 topic hz /livox/lidar"
echo ""
cd ~/nav_ws && source install/setup.bash
ros2 launch livox_ros_driver2 msg_MID360_launch.py
