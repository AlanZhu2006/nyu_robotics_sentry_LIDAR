# 快速开始指南

## 🚀 三步启动完整系统

### 步骤 1: 应用配置

```bash
cd ~/nav_ws
./configs/unitree_l2_complete/setup_complete_system.sh
```

### 步骤 2: 启动系统

**建图模式**（第一次使用）：
```bash
./configs/unitree_l2_complete/start_complete_system.sh
```

**导航模式**（已有地图）：
```bash
./configs/unitree_l2_complete/start_complete_system.sh /path/to/map.yaml
```

### 步骤 3: 使用系统

1. **查看点云**：在 RViz 中查看 `/unilidar/cloud`
2. **建图**：移动机器人，观察点云建图
3. **保存地图**：`ros2 run nav2_map_server map_saver_cli -f ~/my_map`
4. **导航**：使用 2D Goal Pose 设置目标

## 📝 配置文件位置

所有配置文件在：`~/nav_ws/configs/unitree_l2_complete/`

- `point_lio_config.yaml` - Point-LIO 配置
- `nav2_params.yaml` - Nav2 配置
- `pointcloud_to_laserscan_params.yaml` - 点云转激光扫描配置

## ⚙️ 根据实际情况调整

### 必须调整的参数

1. **机器人尺寸**（`nav2_params.yaml`）：
   ```yaml
   robot_radius: 0.22  # 改为你的机器人半径
   ```

2. **机器人速度**（`nav2_params.yaml`）：
   ```yaml
   max_vel_x: 0.26     # 改为你的机器人最大速度
   max_vel_theta: 1.0  # 改为你的机器人最大角速度
   ```

### 可能需要调整的参数

1. **外参**（如果点云旋转）：
   - 使用 LI-Init 工具校准
   - 更新 `point_lio_config.yaml` 中的 `extrinsic_T` 和 `extrinsic_R`

2. **重力方向**（如果设备倾斜安装）：
   - 运行诊断脚本获取实际重力方向
   - 更新 `gravity_init` 和 `gravity`

## 🔍 验证系统

### 检查话题

```bash
ros2 topic list
```

应该看到：
- `/unilidar/cloud` - 点云
- `/unilidar/imu` - IMU 数据
- `/scan` - 激光扫描
- `/odom` - 里程计
- `/map` - 地图（如果加载了）

### 检查 TF 树

```bash
ros2 run tf2_tools view_frames
evince frames.pdf
```

## 🐛 常见问题

### Q: 点云旋转怎么办？

A: 运行诊断脚本，然后校准外参：
```bash
python3 diagnose_rotation_issue.py
# 根据结果校准 extrinsic_R
```

### Q: 里程计漂移怎么办？

A: 确保 `extrinsic_est_en: false`，然后校准外参。

### Q: Nav2 无法规划路径？

A: 检查：
1. 地图是否加载
2. 机器人初始位置是否正确
3. costmap 是否正常

## 📚 更多信息

查看 `COMPLETE_SETUP_GUIDE.md` 获取详细说明。
