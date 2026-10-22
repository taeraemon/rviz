#!/usr/bin/env bash
# usage: run_bench.sh <base|new> <style> <num_points> <gpu|mesa> [rate_hz] [seconds]
# Runs inside the rviz-rolling container. Prints median/mean/p95 frame time and saves a screenshot.

VARIANT=$1 STYLE=$2 N=$3 GL=$4 RATE=${5:-0} SECS=${6:-15}
WS=/workspace/ws
OUT=$WS/bench_out; mkdir -p $OUT
TAG="${VARIANT}_${STYLE// /}_${N}_${GL}_r${RATE}"
export DISPLAY=:99
pgrep -x Xvfb >/dev/null || { Xvfb :99 -screen 0 1920x1080x24 >/dev/null 2>&1 & sleep 2; }

source /opt/ros/rolling/setup.bash
source $WS/install_ogre/setup.bash
if [ "$VARIANT" = base ]; then source $WS/base/install/setup.bash; else source $WS/install/setup.bash; fi
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100))

MEM0=$(nvidia-smi -i 0 --query-gpu=memory.used --format=csv,noheader,nounits)
python3 $WS/src/rviz/docker/bench/make_config.py "$STYLE" /tmp/$TAG.rviz ${SIZE:-0.05} ${DIST:-90}
python3 $WS/src/rviz/docker/bench/pub_cloud.py $N $RATE >/dev/null 2>&1 & PUB=$!

if [ "$GL" = gpu ]; then LAUNCH="vglrun -d egl"; else LAUNCH="env LIBGL_ALWAYS_SOFTWARE=1"; fi
FRAMETIME_OUT=$OUT/$TAG.ft LD_PRELOAD=$WS/libframetime.so \
  $LAUNCH rviz2 -d /tmp/$TAG.rviz $RVIZ_ARGS > $OUT/$TAG.log 2>&1 & RV=$!

# warm-up (cloud delivery + first upload), then keep only the measurement window
sleep 8; START=$(wc -l < $OUT/$TAG.ft 2>/dev/null || echo 0)
T0=$(awk '{print $14+$15}' /proc/$RV/stat)
sleep $SECS
T1=$(awk '{print $14+$15}' /proc/$RV/stat)
CPU=$(( (T1 - T0) * 100 / $(getconf CLK_TCK) / SECS ))
END=$(wc -l < $OUT/$TAG.ft)
MEM1=$(nvidia-smi -i 0 --query-gpu=memory.used --format=csv,noheader,nounits)
xwd -root -silent | convert xwd:- -crop 1600x1000+0+0 $OUT/$TAG.png 2>/dev/null
kill $RV $PUB 2>/dev/null; wait $RV $PUB 2>/dev/null
sed -n "$((START + 1)),${END}p" $OUT/$TAG.ft | python3 -c '
import sys, statistics as s
v = sorted(float(x.split()[-1]) for x in sys.stdin if x.strip())
if not v: print("'"$TAG"' NO FRAMES"); sys.exit()
print(f"'"$TAG"' frames={len(v)} median={s.median(v):.2f}ms mean={s.mean(v):.2f}ms p95={v[int(.95*len(v))-1]:.2f}ms fps={len(v)/'"$SECS"':.1f} cpu='"$CPU"'% gpu_mem=+'"$((MEM1 - MEM0))"'MiB")'
grep -iE "error|geometry|technique|glsl" $OUT/$TAG.log | head -5
