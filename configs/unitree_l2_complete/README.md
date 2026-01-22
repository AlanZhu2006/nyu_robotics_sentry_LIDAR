# Unitree Lidar L2 完整系统配置

## 概述

这是一个从零开始的完整配置，包括：
1. **Unitree Lidar L2** 驱动
2. **Point-LIO** 建图和里程计
3. **Pointcloud 转 LaserScan** 转换
4. **Nav2** 导航和避障

## 目录结构

```
configs/unitree_l2_complete/
├── README.md                          # 本文件
├── point_lio_config.yaml             # Point-LIO 配置
├── nav2_params.yaml                  # Nav2 配置
├── pointcloud_to_laserscan_params.yaml # 点云转激光扫描配置
├── launch_complete_system.launch.py   # 完整系统启动文件
└── start_complete_system.sh          # 一键启动脚本
```

## 快速开始

### 1. 复制配置文件到正确位置

```bash
cd ~/nav_ws

# 复制 Point-LIO 配置
cp configs/unitree_l2_complete/point_lio_config.yaml \
   src/point_lio_ros2/config/unilidar_l2.yaml

# 编译
colcon build --packages-select point_lio
source install/setup.bash
```

### 2. 启动完整系统

**方法 A: 使用启动脚本（推荐）**

```bash
cd ~/nav_ws
./configs/unitree_l2_complete/start_complete_system.sh [地图文件路径]
```

**方法 B: 使用 Launch 文件**

```bash
cd ~/nav_ws
source install/setup.bash
ros2 launch configs/unitree_l2_complete/launch_complete_system.launch.py \
    map:=/path/to/your/map.yaml
```

## 配置说明

### Point-LIO 配置

**关键参数**：
- `lidar_type: 5` - Unitree Unilidar L2
- `scan_line: 18` - 18 条扫描线
- `start_in_aggressive_motion: true` - 使用预设重力方向
- `extrinsic_est_en: false` - 使用固定外参（避免不稳定性）
- `extrinsic_R`: 单位矩阵（如果 IMU 和 LiDAR 有相对角度，需要校准）

**外参校准**：
如果点云旋转，可能需要校准 `extrinsic_R`。使用 [LI-Init](https://github.com/hku-mars/LiDAR_IMU_Init) 工具进行精确校准。

### Nav2 配置

**关键参数**：
- `robot_radius: 0.22` - 机器人半径（根据实际情况调整）
- `max_vel_x: 0.26` - 最大线速度
- `max_vel_theta: 1.0` - 最大角速度
- `resolution: 0.05` - 地图分辨率

**根据实际情况调整**：
- 机器人尺寸（`robot_radius`）
- 速度限制（`max_vel_x`, `max_vel_theta`）
- 加速度限制（`acc_lim_x`, `acc_lim_theta`）

### Pointcloud 转 LaserScan 配置

**关键参数**：
- `target_frame: base_link` - 目标坐标系
- `min_height: -0.4` - 最小高度（过滤地面以下）
- `max_height: 1.0` - 最大高度（过滤障碍物）
- `range_max: 20.0` - 最大检测距离

## 使用流程

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

## 故障排除

### 问题 1: 点云旋转

**解决方案**：
1. 检查 `extrinsic_R` 是否正确
2. 使用 LI-Init 工具校准外参
3. 运行诊断脚本：`python3 diagnose_rotation_issue.py`

### 问题 2: 里程计漂移

**解决方案**：
1. 确保 `extrinsic_est_en: false`（使用固定外参）
2. 检查 IMU 数据质量
3. 校准外参

### 问题 3: Nav2 无法规划路径

**解决方案**：
1. 检查地图是否加载
2. 检查 costmap 是否正常
3. 检查机器人初始位置是否正确

## 校准外参（如果需要）

如果点云旋转或里程计漂移，需要校准外参：

1. **安装 LI-Init**：
   ```bash
   git clone https://github.com/hku-mars/LiDAR_IMU_Init.git
   ```

2. **收集数据并校准**

3. **更新配置文件**：
   ```yaml
   extrinsic_T: [校准后的值]
   extrinsic_R: [校准后的值]
   ```

## 文件说明

- `point_lio_config.yaml`: Point-LIO 配置（干净的，标准参数）
- `nav2_params.yaml`: Nav2 完整配置
- `pointcloud_to_laserscan_params.yaml`: 点云转激光扫描配置
- `launch_complete_system.launch.py`: ROS2 Launch 文件
- `start_complete_system.sh`: 一键启动脚本

## 下一步

1. 根据实际情况调整参数（机器人尺寸、速度等）
2. 如果需要，校准外参
3. 建图并测试导航
