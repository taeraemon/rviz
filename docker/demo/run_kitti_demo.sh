#!/usr/bin/env bash
# Opens rviz2 on this X display (e.g. an xrdp session) and replays KITTI 00 into it,
# accumulating the registered scans like a SLAM map. Rendering runs on the NVIDIA GPU via
# VirtualGL; the frames are sent to the X display.
#
# usage: run_kitti_demo.sh [new|base] [scan_rate_hz] [frames]
#   new  : this branch (default)    base : unmodified upstream rviz2, for comparison
# In rviz, "KITTI map > Max Points Per Pixel" turns level of detail off (0) or on (e.g. 4).
set -euo pipefail
VARIANT=${1:-new} RATE=${2:-10} FRAMES=${3:-4541}
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${DISPLAY:?DISPLAY is not set; run this from a terminal inside the desktop session}"
xhost +local: >/dev/null 2>&1 || true

docker run --rm $([ -t 0 ] && echo -it) --name rviz-kitti-demo \
  --runtime nvidia -e NVIDIA_VISIBLE_DEVICES=0 -e NVIDIA_DRIVER_CAPABILITIES=all \
  --net host -e DISPLAY="$DISPLAY" -e ROS_DOMAIN_ID=77 -e QT_X11_NO_MITSHM=1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "${XAUTHORITY:-$HOME/.Xauthority}":/root/.Xauthority:ro \
  -v /home/tykim/Documents/project_slam/rviz/docker/ws:/workspace/ws \
  -v /home/tykim/Documents/project_slam/rviz:/workspace/ws/src/rviz \
  -v /mnt/wall_rose/kitti_odometry:/data/kitti_odometry:ro \
  rviz-rolling:latest bash -c "
    source /opt/ros/rolling/setup.bash
    source /workspace/ws/install_ogre/setup.bash
    if [ '$VARIANT' = base ]; then source /workspace/ws/base/install/setup.bash
    else source /workspace/ws/install/setup.bash; fi
    cfg=/tmp/kitti_demo.rviz
    cp /workspace/ws/src/rviz/docker/demo/kitti_demo.rviz \$cfg
    [ '$VARIANT' = base ] && sed -i '/Max Points Per Pixel/d' \$cfg
    (sleep 8; python3 -u /workspace/ws/src/rviz/docker/bench/kitti_replay.py 00 scan $RATE $FRAMES) &
    vglrun -d egl rviz2 -d \$cfg
    kill %1 2>/dev/null; pkill -f kitti_replay || true"
