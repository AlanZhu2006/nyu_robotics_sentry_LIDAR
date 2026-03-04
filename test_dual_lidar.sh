#!/bin/bash
# 双雷达融合（双驱动+合并方案）
# 雷达1 (182) -> 内置网口  雷达2 (114) -> USB 网口

echo "=========================================="
echo "双雷达融合测试"
echo "=========================================="

echo ""
echo ">>> 1. 设置两个网口 IP..."
sudo ip addr add 192.168.1.2/24 dev enp114s0 2>/dev/null || true
sudo ip addr add 192.168.1.3/24 dev enx00e04c2536b0 2>/dev/null || true

echo ""
echo ">>> 2. 添加路由（双网口同网段需指定 114 走 USB）..."
sudo ip route add 192.168.1.114/32 dev enx00e04c2536b0 2>/dev/null || true
sudo ip route add 192.168.1.182/32 dev enp114s0 2>/dev/null || true

echo ""
echo ">>> 3. Ping 两个雷达..."
OK=0
ping -c 1 -I 192.168.1.2 192.168.1.182 >/dev/null 2>&1 && echo "   雷达1 (182) ✅" && OK=$((OK+1)) || echo "   雷达1 (182) ❌"
ping -c 1 -I 192.168.1.3 192.168.1.114 >/dev/null 2>&1 && echo "   雷达2 (114) ✅" && OK=$((OK+1)) || echo "   雷达2 (114) ❌"

if [ $OK -lt 2 ]; then
    echo "   请确保两个雷达都已连接并上电"
    exit 1
fi

echo ""
echo ">>> 4. 启动双雷达（双驱动+合并）..."
echo "   在另一终端运行: ros2 topic hz /livox/lidar"
echo "   成功时应有 'livox custom format' 输出且约 10 Hz"
echo ""
cd ~/nav_ws && source install/setup.bash
ros2 launch livox_dual_merge dual_lidar_merge_launch.py
