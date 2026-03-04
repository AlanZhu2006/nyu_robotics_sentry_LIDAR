#!/usr/bin/env python3
"""
合并双 Livox Mid360 点云和 IMU，输出到 /livox/lidar 和 /livox/imu 供 FAST-LIO 使用。
"""
import rclpy
from rclpy.node import Node
from livox_ros_driver2.msg import CustomMsg, CustomPoint
from sensor_msgs.msg import Imu
from std_msgs.msg import Header


class LivoxDualMergeNode(Node):
    def __init__(self):
        super().__init__('livox_dual_merge_node')
        self.declare_parameter('frame_id', 'livox_frame')

        self.last_lidar_1 = None
        self.last_lidar_2 = None
        self.frame_id = self.get_parameter('frame_id').value

        self.sub_lidar_1 = self.create_subscription(
            CustomMsg, '/livox/lidar_1', self.lidar_1_cb, 10)
        self.sub_lidar_2 = self.create_subscription(
            CustomMsg, '/livox/lidar_2', self.lidar_2_cb, 10)
        self.sub_imu_1 = self.create_subscription(
            Imu, '/livox/imu_1', self.imu_1_cb, 10)
        self.sub_imu_2 = self.create_subscription(
            Imu, '/livox/imu_2', self.imu_2_cb, 10)

        self.pub_lidar = self.create_publisher(CustomMsg, '/livox/lidar', 10)
        self.pub_imu = self.create_publisher(Imu, '/livox/imu', 10)

    def lidar_1_cb(self, msg):
        self.last_lidar_1 = msg
        self._publish_merged_lidar()

    def lidar_2_cb(self, msg):
        self.last_lidar_2 = msg
        self._publish_merged_lidar()

    def _publish_merged_lidar(self):
        if self.last_lidar_1 is None or self.last_lidar_2 is None:
            return
        merged = CustomMsg()
        merged.header = Header()
        merged.header.stamp = self.get_clock().now().to_msg()
        merged.header.frame_id = self.frame_id
        merged.lidar_id = 0
        merged.rsvd = [0, 0, 0]
        merged.points = []

        # 以 timebase 较早的为基准
        t1 = self.last_lidar_1.timebase
        t2 = self.last_lidar_2.timebase
        base = min(t1, t2)
        dt1 = t1 - base
        dt2 = t2 - base

        for p in self.last_lidar_1.points:
            pt = CustomPoint()
            pt.offset_time = p.offset_time + dt1
            pt.x, pt.y, pt.z = p.x, p.y, p.z
            pt.reflectivity, pt.tag, pt.line = p.reflectivity, p.tag, p.line
            merged.points.append(pt)
        for p in self.last_lidar_2.points:
            pt = CustomPoint()
            pt.offset_time = p.offset_time + dt2
            pt.x, pt.y, pt.z = p.x, p.y, p.z
            pt.reflectivity, pt.tag, pt.line = p.reflectivity, p.tag, p.line
            merged.points.append(pt)

        merged.timebase = base
        merged.point_num = len(merged.points)
        self.pub_lidar.publish(merged)

    def imu_1_cb(self, msg):
        msg.header.frame_id = self.frame_id
        self.pub_imu.publish(msg)

    def imu_2_cb(self, msg):
        msg.header.frame_id = self.frame_id
        self.pub_imu.publish(msg)


def main(args=None):
    rclpy.init(args=args)
    node = LivoxDualMergeNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
