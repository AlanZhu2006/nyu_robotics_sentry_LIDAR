#!/bin/bash
# USB 网口单雷达测试
# 雷达 192.168.1.114 接 USB 网口 (enx00e04c2536b0)

set -e
echo "=========================================="
echo "USB 网口单雷达测试"
echo "=========================================="

echo ""
echo ">>> 1. 设置 USB 网口 IP..."
sudo ip addr add 192.168.1.3/24 dev enx00e04c2536b0 2>/dev/null || true
ip addr show enx00e04c2536b0 | grep "inet " || echo "   (检查网口名是否正确)"

echo ""
echo ">>> 2. Ping 雷达 192.168.1.114..."
if ping -c 2 -I 192.168.1.3 192.168.1.114; then
    echo "   ✅ Ping 成功"
else
    echo "   ❌ Ping 失败，请检查雷达接在 USB 网口"
    exit 1
fi

echo ""
echo ">>> 3. 启动 Livox 驱动（USB 雷达）..."
echo "   在另一终端运行: ros2 topic hz /livox/lidar"
echo ""
cd ~/nav_ws && source install/setup.bash
ros2 launch livox_ros_driver2 msg_MID360_usb_launch.py
