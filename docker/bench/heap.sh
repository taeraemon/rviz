#!/usr/bin/env bash
N=${1:-200}
WS=/workspace/ws; OUT=$WS/bench_out; export DISPLAY=:99
source /opt/ros/rolling/setup.bash; source $WS/install_ogre/setup.bash; source $WS/install/setup.bash
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100))
python3 $WS/src/rviz/docker/bench/make_config.py "Flat Squares" /tmp/mem.rviz 0.05 450 1000000 2
sed -i "s|Depth: 5|Depth: 100|; s|Durability Policy: Transient Local|Durability Policy: Volatile|" /tmp/mem.rviz
rm -f $OUT/heaptrack.*
cd $OUT && vglrun -d egl heaptrack -o $OUT/heaptrack.rviz rviz2 -d /tmp/mem.rviz > /tmp/heap.log 2>&1 & 
sleep 15
python3 -u $WS/src/rviz/docker/bench/kitti_replay.py 00 scan 10 $N > /tmp/mem.pub 2>&1 & PUB=$!
while ! grep -q "frame $N " /tmp/mem.pub; do sleep 1; done; sleep 5
pkill -INT -x rviz2; kill $PUB; sleep 15
heaptrack_print -f $OUT/heaptrack.rviz.*zst --print-peaks 1 --print-allocators 0 --print-temporary 0 --print-leaks 0 -n 12 -s 0 2>/dev/null | head -150
