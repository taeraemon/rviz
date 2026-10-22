"""Replay KITTI odometry as a SLAM system would publish it.

usage: kitti_replay.py <seq> <mode> [rate_hz] [num_frames] [map_every]
  mode scan : publish each scan registered in the map frame (like /cloud_registered);
              rviz accumulates them with a large Decay Time.
  mode map  : publish the whole accumulated map every <map_every> scans (like /global_map).
After num_frames scans the node keeps running but stops publishing new data.
"""
import sys
import time

import numpy as np
import rclpy
from rclpy.qos import DurabilityPolicy, QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import PointCloud2, PointField

ROOT = '/data/kitti_odometry'


def load_poses(seq):
    calib = {}
    for line in open(f'{ROOT}/data_odometry_calib/dataset/sequences/{seq}/calib.txt'):
        k, v = line.split(':', 1)
        calib[k] = np.array(v.split(), dtype=np.float64)
    tr = np.eye(4)
    tr[:3] = calib['Tr'].reshape(3, 4)
    tr_inv = np.linalg.inv(tr)
    poses = []
    for line in open(f'{ROOT}/data_odometry_poses/dataset/poses/{seq}.txt'):
        p = np.eye(4)
        p[:3] = np.array(line.split(), dtype=np.float64).reshape(3, 4)
        poses.append(tr_inv @ p @ tr)  # velodyne pose in the frame of the first scan (z up)
    return poses


def load_scan(seq, i, pose):
    pts = np.fromfile(
        f'{ROOT}/data_odometry_velodyne/dataset/sequences/{seq}/velodyne/{i:06d}.bin',
        dtype=np.float32).reshape(-1, 4)
    xyz = pts[:, :3] @ pose[:3, :3].T.astype(np.float32) + pose[:3, 3].astype(np.float32)
    pts[:, :3] = xyz
    return pts


def to_msg(pts, stamp):
    msg = PointCloud2()
    msg.header.frame_id = 'map'
    msg.header.stamp = stamp
    msg.height, msg.width = 1, len(pts)
    msg.fields = [PointField(name=f, offset=4 * i, datatype=PointField.FLOAT32, count=1)
                  for i, f in enumerate(['x', 'y', 'z', 'intensity'])]
    msg.is_bigendian, msg.point_step, msg.row_step = False, 16, 16 * len(pts)
    msg.is_dense = True
    msg.data = pts.tobytes()
    return msg


def main():
    seq, mode = sys.argv[1], sys.argv[2]
    rate = float(sys.argv[3]) if len(sys.argv) > 3 else 10.0
    num = int(sys.argv[4]) if len(sys.argv) > 4 else 10 ** 9
    map_every = int(sys.argv[5]) if len(sys.argv) > 5 else 50
    poses = load_poses(seq)
    num = min(num, len(poses))

    rclpy.init()
    node = rclpy.create_node('kitti_replay')
    qos = QoSProfile(depth=100, reliability=ReliabilityPolicy.RELIABLE,
                     durability=DurabilityPolicy.TRANSIENT_LOCAL if mode == 'map'
                     else DurabilityPolicy.VOLATILE)
    pub = node.create_publisher(PointCloud2, '/cloud', qos)
    state = {'i': 0, 'map': [], 'points': 0}

    def tick():
        i = state['i']
        if i >= num:
            return
        pts = load_scan(seq, i, poses[i])
        state['i'] += 1
        state['points'] += len(pts)
        stamp = node.get_clock().now().to_msg()
        if mode == 'scan':
            pub.publish(to_msg(pts, stamp))
        else:
            state['map'].append(pts)
            if state['i'] % map_every == 0 or state['i'] == num:
                pub.publish(to_msg(np.concatenate(state['map']), stamp))
        if state['i'] % 100 == 0 or state['i'] == num:
            print(f'{time.time():.3f} frame {state["i"]} points {state["points"]}', flush=True)

    node.create_timer(1.0 / rate, tick)
    rclpy.spin(node)


if __name__ == '__main__':
    main()
