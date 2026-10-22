#!/usr/bin/env bash
# Accumulate N KITTI scans into rviz2 and break down its resident memory by mapping.
N=${1:-800}
WS=/workspace/ws; OUT=$WS/bench_out; export DISPLAY=:99
source /opt/ros/rolling/setup.bash; source $WS/install_ogre/setup.bash; source $WS/install/setup.bash
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100))
python3 $WS/src/rviz/docker/bench/make_config.py "Flat Squares" /tmp/mem.rviz 0.05 450 1000000 2
sed -i "s|Depth: 5|Depth: 100|; s|Durability Policy: Transient Local|Durability Policy: Volatile|" /tmp/mem.rviz
vglrun -d egl rviz2 -d /tmp/mem.rviz > /dev/null 2>&1 & RV=$!
sleep 6
python3 -u $WS/src/rviz/docker/bench/kitti_replay.py 00 scan 20 $N > /tmp/mem.pub 2>&1 & PUB=$!
while ! grep -q "frame $N " /tmp/mem.pub; do sleep 1; done; sleep 5
grep points /tmp/mem.pub | tail -1
awk '/^[0-9a-f]+-[0-9a-f]+ /{name=$6; if(name=="") name="[anon]"} /^Rss:/{rss[name]+=$2} END{for(n in rss) if(rss[n]>10000) printf "%8d MiB %s\n", rss[n]/1024, n}' /proc/$RV/smaps | sort -rn | head -15; grep VmRSS /proc/$RV/status
kill $RV $PUB; wait 2>/dev/null
