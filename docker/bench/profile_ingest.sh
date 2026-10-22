#!/usr/bin/env bash
# Profile rviz2 while it ingests KITTI scans at a high rate (only the latest scan is kept).
VARIANT=$1 RATE=${2:-50}
WS=/workspace/ws; OUT=$WS/bench_out; TAG="ingest_${VARIANT}${PPP:+_ppp$PPP}"
export DISPLAY=:99
source /opt/ros/rolling/setup.bash; source $WS/install_ogre/setup.bash
case $VARIANT in base) source $WS/base/install/setup.bash;; *) source $WS/install/setup.bash;; esac
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100))
python3 $WS/src/rviz/docker/bench/make_config.py "Flat Squares" /tmp/$TAG.rviz 0.05 450 0 2
sed -i "s|Depth: 5|Depth: 100|; s|Durability Policy: Transient Local|Durability Policy: Volatile|" /tmp/$TAG.rviz
[ -n "$PPP" ] && sed -i "s|      Decay Time: \(.*\)|      Decay Time: \1\n      Max Points Per Pixel: $PPP|" /tmp/$TAG.rviz
vglrun -d egl rviz2 -d /tmp/$TAG.rviz > $OUT/$TAG.log 2>&1 & RV=$!
sleep 6
python3 -u $WS/src/rviz/docker/bench/kitti_replay.py 00 scan $RATE 100000 > /dev/null 2>&1 & PUB=$!
sleep 5
perf record -F 999 -g --call-graph dwarf,16384 -t $(ls /proc/$RV/task | head -1) -o $OUT/$TAG.perf -- sleep 6 >/dev/null 2>&1
kill $RV $PUB; wait $RV $PUB 2>/dev/null
perf report -i $OUT/$TAG.perf --children --sort sym --stdio 2>/dev/null | grep -E "^ +[0-9]" | head -45 | cut -c1-160
