#!/usr/bin/env bash
# Drag a selection rectangle with the Select tool and screenshot the highlighted points.
V=$1 STYLE=$2 N=${3:-3000}
WS=/workspace/ws; OUT=$WS/bench_out; export DISPLAY=:99
source /opt/ros/rolling/setup.bash; source $WS/install_ogre/setup.bash
if [ "$V" = base ]; then source $WS/base/install/setup.bash; else source $WS/install/setup.bash; fi
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100))
python3 $WS/src/rviz/docker/bench/make_config.py "$STYLE" /tmp/sel.rviz 0.6 30 0 3
[ -n "$PPP" ] && sed -i "s|      Decay Time: \(.*\)|      Decay Time: \1\n      Max Points Per Pixel: $PPP|" /tmp/sel.rviz
sed -i 's|rviz_default_plugins/MoveCamera|rviz_default_plugins/Select|; s|^Panels: \[\]|Panels:\n  - Class: rviz_common/Selection\n    Name: Selection|' /tmp/sel.rviz
python3 $WS/src/rviz/docker/bench/pub_cloud.py $N 0 >/dev/null 2>&1 & PUB=$!
vglrun -d egl rviz2 -d /tmp/sel.rviz > $OUT/sel_$V.log 2>&1 & RV=$!
sleep ${WAIT:-8}
read X1 Y1 X2 Y2 <<< "${RECT:-900 500 910 506}"
xdotool mousemove $X1 $Y1 mousedown 1 mousemove $(((X1 + X2) / 2)) $(((Y1 + Y2) / 2)) mousemove $X2 $Y2 mouseup 1
sleep ${AFTER:-2}
xwd -root -silent | convert xwd:- -crop 1600x1000+0+0 $OUT/sel_${V}_${STYLE// /}_${N}${PPP:+_ppp$PPP}.png
kill $RV $PUB; wait $RV $PUB 2>/dev/null
