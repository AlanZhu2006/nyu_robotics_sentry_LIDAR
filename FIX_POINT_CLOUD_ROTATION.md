# 修复点云旋转问题

## 问题原因

点云旋转的主要原因是 **重力方向估计错误**。

### 当前配置的问题

1. **`start_in_aggressive_motion: false`**
   - 系统会使用 IMU 初始化时的平均加速度 (`mean_acc`) 来计算重力方向
   - 如果初始化时设备有振动、倾斜或数据不稳定，会导致重力方向估计错误
   - 错误的重力方向会导致旋转矩阵计算错误，点云就会旋转

2. **`gravity_align: true`**
   - 启用重力对齐，会根据估计的重力方向计算旋转矩阵
   - 如果重力方向估计错误，旋转矩阵就会错误

### 代码逻辑

当 `start_in_aggressive_motion: false` 且 `gravity_align: true` 时：

```cpp
// 从 IMU 初始化时的平均加速度计算重力方向
state_in.gravity = -1 * p_imu->mean_acc * G_m_s2 / acc_norm;

// 使用 Set_init() 计算旋转矩阵来对齐重力
p_imu->Set_init(state_in.gravity, rot_init);
state_in.rot = state_out.rot = rot_init;
```

如果 `mean_acc` 不准确（比如初始化时有振动），计算出的 `rot_init` 就会错误，导致点云旋转。

## 解决方案

### ✅ 已修复：设置 `start_in_aggressive_motion: true`

**修改**：
```yaml
start_in_aggressive_motion: true  # 使用预设重力方向
```

**效果**：
- 系统会直接使用 `gravity_init` 作为重力方向
- 不依赖 IMU 初始化时的平均加速度
- 避免因初始化时的振动或倾斜导致的重力方向估计错误

### 其他可能的原因

如果修复后仍然旋转，可能的原因：

1. **`extrinsic_R` 不正确**
   - 如果 IMU 和 LiDAR 有相对旋转，需要正确设置 `extrinsic_R`
   - 当前是单位矩阵，如果实际有旋转，需要校准

2. **`gravity_init` 不正确**
   - 如果设备安装在倾斜的平台上，需要调整 `gravity_init`
   - 例如：如果平台倾斜 10 度，需要计算对应的重力向量

3. **IMU 数据质量问题**
   - IMU 数据不稳定也会导致重力对齐错误
   - 可以通过增大 `imu_meas_acc_cov` 和 `imu_meas_omg_cov` 来减少影响

## 验证

修复后，重启 Point-LIO 并观察：
1. 点云是否不再旋转
2. 点云是否水平
3. 里程计是否稳定

如果仍然有问题，可能需要：
- 校准 `extrinsic_R`
- 调整 `gravity_init`（如果设备倾斜安装）
- 检查 IMU 数据质量
