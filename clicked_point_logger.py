#!/usr/bin/env python3
"""
Listen to RViz clicked points and print coordinates in the map frame.

Usage:
  source /opt/ros/humble/setup.bash
  # If needed, also source your workspace:
  # source ~/nav_ws/install/setup.bash
  python3 ~/nav_ws/clicked_point_logger.py

In RViz:
  - Set Fixed Frame to "map"
  - Use the "Publish Point" tool
  - Click on map, this node prints x/y/z
"""

from datetime import datetime

import rclpy
from geometry_msgs.msg import PointStamped
from rclpy.node import Node


class ClickedPointLogger(Node):
    def __init__(self) -> None:
        super().__init__("clicked_point_logger")
        self.subscription = self.create_subscription(
            PointStamped,
            "/clicked_point",
            self.clicked_point_callback,
            10,
        )
        self.count = 0
        self.get_logger().info("Listening on /clicked_point (RViz Publish Point)")

    def clicked_point_callback(self, msg: PointStamped) -> None:
        self.count += 1
        stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        frame = msg.header.frame_id or "unknown"
        x = msg.point.x
        y = msg.point.y
        z = msg.point.z

        self.get_logger().info(
            f"[{self.count}] {stamp} frame={frame} "
            f"-> x={x:.3f}, y={y:.3f}, z={z:.3f} (relative to map origin)"
        )


def main() -> None:
    rclpy.init()
    node = ClickedPointLogger()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
