"""Publish a synthetic LiDAR-like PointCloud2 (xyz + intensity).

usage: pub_cloud.py <num_points> [rate_hz]   (rate 0 = publish once, transient local)
"""
import sys

import numpy as np
import rclpy
from rclpy.qos import DurabilityPolicy, QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import PointCloud2, PointField


def make_cloud(n, seed):
    rng = np.random.default_rng(seed)
    # Points on a noisy cylinder/room so the view is filled, like a SLAM map.
    th = rng.uniform(0, 2 * np.pi, n).astype(np.float32)
    r = rng.uniform(5, 40, n).astype(np.float32)
    z = rng.uniform(-2, 8, n).astype(np.float32)
    pts = np.empty(n, dtype=[('x', 'f4'), ('y', 'f4'), ('z', 'f4'), ('intensity', 'f4')])
    pts['x'] = r * np.cos(th)
    pts['y'] = r * np.sin(th)
    pts['z'] = z
    pts['intensity'] = r
    msg = PointCloud2()
    msg.header.frame_id = 'map'
    msg.height, msg.width = 1, n
    msg.fields = [PointField(name=f, offset=4 * i, datatype=PointField.FLOAT32, count=1)
                  for i, f in enumerate(['x', 'y', 'z', 'intensity'])]
    msg.is_bigendian, msg.point_step, msg.row_step = False, 16, 16 * n
    msg.is_dense = True
    msg.data = pts.tobytes()
    return msg


def main():
    n = int(sys.argv[1])
    rate = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
    rclpy.init()
    node = rclpy.create_node('pub_cloud')
    qos = QoSProfile(depth=1, reliability=ReliabilityPolicy.RELIABLE,
                     durability=DurabilityPolicy.TRANSIENT_LOCAL)
    pub = node.create_publisher(PointCloud2, '/cloud', qos)
    msgs = [make_cloud(n, s) for s in range(2 if rate > 0 else 1)]
    i = [0]

    def tick():
        m = msgs[i[0] % len(msgs)]
        m.header.stamp = node.get_clock().now().to_msg()
        pub.publish(m)
        i[0] += 1

    tick()
    if rate > 0:
        node.create_timer(1.0 / rate, tick)
    rclpy.spin(node)


if __name__ == '__main__':
    main()
