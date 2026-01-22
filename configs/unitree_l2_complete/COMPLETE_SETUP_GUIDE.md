# Unitree Lidar L2 完整系统配置指南

## 📋 系统组件

1. **Unitree Lidar L2** - 激光雷达驱动
2. **Point-LIO** - 建图和里程计
3. **Pointcloud to LaserScan** - 点云转激光扫描
4. **Nav2** - 导航和避障

## 🚀 快速开始

### 步骤 1: 应用配置

```bash
cd ~/nav_ws
./configs/unitree_l2_complete/setup_complete_system.sh
```

这个脚本会：
- 备份现有配置
- 应用新的干净配置
- 编译 Point-LIO
- 验证配置

### 步骤 2: 启动系统

**建图模式**（不加载地图）：
```bash
cd ~/nav_ws
source install/setup.bash
./configs/unitree_l2_complete/start_complete_system.sh
```

**导航模式**（加载地图）：
```bash
./configs/unitree_l2_complete/start_complete_system.sh /path/to/your/map.yaml
```

## 📁 配置文件说明

### 1. Point-LIO 配置 (`point_lio_config.yaml`)

**特点**：
- ✅ 干净的配置，基于官方示例
- ✅ 标准参数值
- ✅ 针对 Unitree Lidar L2 优化
- ✅ 使用预设重力方向（避免初始化问题）
- ✅ 使用固定外参（避免自动估计的不稳定性）

**关键参数**：
```yaml
lidar_type: 5              # Unitree Unilidar L2
scan_line: 18              # 18 条扫描线
start_in_aggressive_motion: true  # 使用预设重力方向
extrinsic_est_en: false    # 使用固定外参
extrinsic_R: [单位矩阵]    # 如果 IMU 和 LiDAR 有相对角度，需要校准
```

### 2. Nav2 配置 (`nav2_params.yaml`)

**特点**：
- ✅ 完整的 Nav2 配置
- ✅ 适用于差速驱动机器人
- ✅ 包含所有必要的插件

**关键参数**：
```yaml
robot_radius: 0.22         # 根据实际机器人调整
max_vel_x: 0.26           # 最大线速度
max_vel_theta: 1.0        # 最大角速度
resolution: 0.05          # 地图分辨率
```

### 3. Pointcloud to LaserScan 配置

**特点**：
- ✅ 标准配置
- ✅ 适合室内导航

## 🔧 根据实际情况调整

### 调整机器人参数

编辑 `nav2_params.yaml`：

```yaml
robot_radius: 0.22  # 改为你的机器人半径（米）
max_vel_x: 0.26     # 改为你的机器人最大速度
max_vel_theta: 1.0  # 改为你的机器人最大角速度
```

### 校准外参（如果点云旋转）

如果点云旋转，需要校准 `extrinsic_R`：

1. **使用 LI-Init 工具**：
   ```bash
   git clone https://github.com/hku-mars/LiDAR_IMU_Init.git
   # 按照工具说明进行校准
   ```

2. **更新配置**：
   编辑 `point_lio_config.yaml`：
   ```yaml
   extrinsic_T: [校准后的值]
   extrinsic_R: [校准后的值]
   ```

## 📊 使用流程

### 1. 建图

```bash
# 启动系统（不加载地图）
./configs/unitree_l2_complete/start_complete_system.sh

# 在 RViz 中查看点云
# 移动机器人进行建图

# 保存地图
ros2 run nav2_map_server map_saver_cli -f ~/my_map
```

### 2. 导航

```bash
# 启动系统（加载地图）
./configs/unitree_l2_complete/start_complete_system.sh ~/my_map.yaml

# 在 RViz 中使用 2D Goal Pose 设置导航目标
```

## ⚠️  重要提示

### 1. 外参校准

如果点云旋转或里程计漂移：
- 使用 LI-Init 工具精确校准外参
- 或手动测量 IMU 和 LiDAR 的相对安装角度

### 2. 初始化

- 启动时确保设备完全静止
- 等待 IMU 初始化完成（约 15 秒）
- 如果初始化失败，重新启动

### 3. 地图

- 确保地图文件路径正确
- 地图分辨率应与 Nav2 配置一致（0.05 米）

## 🐛 故障排除

### 问题 1: 点云旋转

**解决方案**：
1. 运行诊断：`python3 diagnose_rotation_issue.py`
2. 校准外参：使用 LI-Init 工具
3. 更新 `extrinsic_R`

### 问题 2: 里程计漂移

**解决方案**：
1. 确保 `extrinsic_est_en: false`
2. 校准外参
3. 检查 IMU 数据质量

### 问题 3: Nav2 无法规划路径

**解决方案**：
1. 检查地图是否加载
2. 检查 costmap 是否正常
3. 检查机器人初始位置

## 📝 配置文件位置

- Point-LIO: `src/point_lio_ros2/config/unilidar_l2.yaml`
- Nav2: `my_nav2_params.yaml` 或使用配置文件中的
- 原始配置: `configs/unitree_l2_complete/`

## 🔄 恢复原配置

如果需要恢复原配置：

```bash
# 查看备份文件
ls src/point_lio_ros2/config/unilidar_l2.yaml.backup_*

# 恢复
cp src/point_lio_ros2/config/unilidar_l2.yaml.backup_YYYYMMDD_HHMMSS \
   src/point_lio_ros2/config/unilidar_l2.yaml
```

## 📚 参考文档

- [Point-LIO 官方文档](https://github.com/hku-mars/Point-LIO)
- [Nav2 官方文档](https://navigation.ros.org/)
- [LI-Init 工具](https://github.com/hku-mars/LiDAR_IMU_Init)
