#!/usr/bin/env bash
# Scripted mouse navigation on the KITTI demo config under Xvfb; screenshots each step.
# usage (in the rviz-rolling container): nav_test.sh [frames]
N=${1:-300}
WS=/workspace/ws; OUT=$WS/bench_out/nav; mkdir -p $OUT; export DISPLAY=:99
source /opt/ros/rolling/setup.bash; source $WS/install_ogre/setup.bash; source $WS/install/setup.bash
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100))
cp $WS/src/rviz/docker/demo/kitti_demo.rviz /tmp/nav.rviz
[ -n "$PPP" ] && sed -i "s/Max Points Per Pixel: .*/Max Points Per Pixel: $PPP/" /tmp/nav.rviz
python3 -u $WS/src/rviz/docker/bench/kitti_replay.py 00 scan 50 $N >/dev/null 2>&1 & PUB=$!
# MESA=1: software rendering through Mesa (the driver stack of Intel and AMD GPUs) instead of NVIDIA.
if [ -n "$MESA" ]; then LIBGL_ALWAYS_SOFTWARE=1 rviz2 -d /tmp/nav.rviz > $OUT/rviz.log 2>&1 & RV=$!
else vglrun -d egl rviz2 -d /tmp/nav.rviz > $OUT/rviz.log 2>&1 & RV=$!; fi
shot() { xwd -root -silent | convert xwd:- -crop 1600x1000+0+0 -resize 50% $OUT/$1.png; }
sleep $((N / 50 + 10)); shot 0_start
xdotool mousemove 800 300; for i in $(seq 30); do xdotool click 4; sleep 0.05; done; sleep 1; shot 1_wheel_in
xdotool mousemove 800 300 mousedown 1; for i in $(seq 20); do xdotool mousemove_relative 10 0; sleep 0.03; done
xdotool mouseup 1; sleep 1; shot 2_rotate
xdotool mousemove 800 300 mousedown 1; for i in $(seq 40); do xdotool mousemove_relative 0 10; sleep 0.03; done
xdotool mouseup 1; sleep 1; shot 3_over_pole
for i in $(seq 30); do xdotool click 5; sleep 0.05; done; sleep 1; shot 4_wheel_out
kill $RV $PUB; wait $RV $PUB 2>/dev/null
grep -i "error\|exception" $OUT/rviz.log | head
