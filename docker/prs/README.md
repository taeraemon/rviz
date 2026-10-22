# ros2/rviz pull requests

One `<key>.title` / `<key>.md` pair per PR, used as is by `gh pr create`. `__A__` .. `__E__`
placeholders are replaced by the PR numbers once all PRs exist.

| Key | Branch | Notes |
|---|---|---|
| A | `pr/pointcloud-geometry-shaders` | |
| B | `pr/pointcloud-double-render` | |
| C | `pr/pointcloud-shared-materials` | |
| D1 | `pr/pointcloud-release-transformed-points` | |
| D2 | `pr/pointcloud-compact-points` | stacked on D1 |
| E | `pr/pointcloud-lod` | stacked on D1, best with B |

The branches merge with each other in any order without conflicts (checked pairwise and for all
six in two orders); `integration` is all six merged. Measurement setup: ROS Rolling on
Ubuntu 26.04.1, GCC 15.2, Qt 6.10.2, Ogre 1.12.10, RTX 4090 (driver 580.178.04) via
VirtualGL/EGL, KITTI odometry 00 replayed as registered scans.
