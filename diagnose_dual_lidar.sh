#!/bin/bash
# 双雷达连接问题诊断脚本
# 用法: 1) 先启动双雷达驱动  2) 在另一终端运行此脚本

echo "=========================================="
echo "双雷达连接诊断"
echo "=========================================="

echo ""
echo ">>> 1. 网络与路由"
echo "  enp114s0 (内置):"
ip -4 addr show enp114s0 2>/dev/null | grep inet || echo "    未配置"
echo "  enx00e04c2536b0 (USB):"
ip -4 addr show enx00e04c2536b0 2>/dev/null | grep inet || echo "    未配置"
echo "  路由 114 -> USB, 182 -> 内置:"
ip route get 192.168.1.114 2>/dev/null | head -1 || echo "    无"
ip route get 192.168.1.182 2>/dev/null | head -1 || echo "    无"

echo ""
echo ">>> 2. Ping 测试"
ping -c 1 -W 1 -I 192.168.1.2 192.168.1.182 >/dev/null 2>&1 && echo "  182 (内置) ✅" || echo "  182 (内置) ❌"
ping -c 1 -W 1 -I 192.168.1.3 192.168.1.114 >/dev/null 2>&1 && echo "  114 (USB)  ✅" || echo "  114 (USB)  ❌"

echo ""
echo ">>> 3. 驱动进程与端口（请在另一终端先启动双雷达驱动）"
if ! pgrep -f livox_ros_driver2 >/dev/null; then
    echo "  ⚠ livox_ros_driver2 未运行，请先执行: ros2 launch livox_dual_merge dual_lidar_merge_launch.py"
    echo "  然后重新运行本脚本"
else
    echo "  livox_ros_driver2 已运行 ✓"
    echo ""
    echo "  UDP 监听端口（雷达 182 应在 56101-56401，雷达 114 应在 56102-56402）:"
    ss -ulnp 2>/dev/null | grep -E "56101|56102|56201|56202|56301|56302|56401|56402" || true
    if [ -z "$(ss -ulnp 2>/dev/null | grep -E '56302|56402')" ]; then
        echo "  ⚠ 未发现 56302/56402 监听 → SDK 可能未为雷达 114 绑定端口"
    fi
fi

echo ""
echo ">>> 4. 防火墙（若端口被拦会导致收不到数据）"
if command -v ufw >/dev/null 2>&1; then
    ufw status 2>/dev/null | head -5 || true
else
    echo "  ufw 未安装，跳过"
fi

echo ""
echo ">>> 5. 建议检查"
echo "  - 若 3 中只有 56101/56201/56301/56401 无 56102-56402: SDK 可能只绑定第一组 host_net_info"
echo "  - 若 3 中两组端口都有: 可能是雷达 114 未响应命令或网络丢包"
echo "  - 可尝试 swap 测试: 修改 config 把 114 放第一项，看 114 能否连上、182 是否断开"
echo ""
