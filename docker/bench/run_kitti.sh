#!/usr/bin/env bash
# usage: run_kitti.sh <variant> <style> <mode scan|map> <frames> <rate_hz> [tail_secs] [map_every]
# Replays KITTI seq 00 into rviz2 (accumulating with a huge Decay Time in scan mode) and prints
# the render frame rate against the number of accumulated points.
VARIANT=$1 STYLE=$2 MODE=$3 FRAMES=$4 RATE=$5 TAIL=${6:-20} MAP_EVERY=${7:-100}
WS=/workspace/ws; OUT=$WS/bench_out; mkdir -p $OUT
TAG="kitti_${VARIANT}_${STYLE// /}_${MODE}_${FRAMES}${PPP:+_ppp$PPP}${VIEW:+_$VIEW}"
export DISPLAY=:99
pgrep -x Xvfb >/dev/null || { Xvfb :99 -screen 0 1920x1080x24 >/dev/null 2>&1 & sleep 2; }
source /opt/ros/rolling/setup.bash; source $WS/install_ogre/setup.bash
case $VARIANT in base) source $WS/base/install/setup.bash;; *) source $WS/install/setup.bash;; esac
export ROS_DOMAIN_ID=$((RANDOM % 100 + 100))

python3 $WS/src/rviz/docker/bench/make_config.py "$STYLE" /tmp/$TAG.rviz ${SIZE:-0.05} ${DIST:-450} ${DECAY:-1000000} ${PX:-2}
sed -i "s|Depth: 5|Depth: 100|" /tmp/$TAG.rviz
[ -n "$PPP" ] && sed -i "s|      Decay Time: \(.*\)|      Decay Time: \1\n      Max Points Per Pixel: $PPP|" /tmp/$TAG.rviz
[ "$MODE" = scan ] && sed -i "s|Durability Policy: Transient Local|Durability Policy: Volatile|" /tmp/$TAG.rviz
sed -i 's|Pitch: 0.6|Pitch: 1.0|; s|Focal Point: {X: 0, Y: 0, Z: 0}|Focal Point: {X: 120, Y: 100, Z: 0}|' /tmp/$TAG.rviz
if [ "$VIEW" = ortho ]; then
  python3 - /tmp/$TAG.rviz <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
i = s.index('  Views:'); j = s.index('Window Geometry:')
s = s[:i] + """  Views:
    Current:
      Class: rviz_default_plugins/TopDownOrtho
      Name: Current View
      Near Clip Distance: 0.01
      Scale: 2
      X: 120
      Y: 100
      Angle: 0
      Target Frame: <Fixed Frame>
      Value: TopDownOrtho (rviz_default_plugins)
    Saved: ~
""" + s[j:]
open(p, 'w').write(s)
PY
fi
FRAMETIME_OUT=$OUT/$TAG.ft LD_PRELOAD=$WS/libframetime.so vglrun -d egl \
  rviz2 -d /tmp/$TAG.rviz $RVIZ_ARGS > $OUT/$TAG.log 2>&1 & RV=$!
sleep 6
python3 -u $WS/src/rviz/docker/bench/kitti_replay.py 00 $MODE $RATE $FRAMES $MAP_EVERY > $OUT/$TAG.pub 2>&1 & PUB=$!
# wait until the last frame was published, then measure the steady state
while ! grep -q "frame $FRAMES " $OUT/$TAG.pub 2>/dev/null; do
  sleep 1; kill -0 $RV 2>/dev/null || { echo "$TAG rviz died"; break; }
done
if [ -n "$PROFILE" ]; then
  sleep 3
  nvidia-smi -i 0 --query-gpu=utilization.gpu --format=csv,noheader,nounits -lms 200 > $OUT/$TAG.gpu & SMI=$!
  perf record -F 499 -g -p $RV -o $OUT/$TAG.perf -- sleep 8 >/dev/null 2>&1
  kill $SMI
  echo "  gpu util avg: $(awk '{s+=$1} END {printf "%.0f", s/NR}' $OUT/$TAG.gpu)%"
  perf report -i $OUT/$TAG.perf --no-children --sort dso,sym --stdio 2>/dev/null | grep -v "^#" | grep "%" | head -40 > $OUT/$TAG.top
  sleep $((TAIL > 11 ? TAIL - 11 : 1))
else
  sleep $TAIL
fi
xwd -root -silent | convert xwd:- -crop 1600x1000+0+0 $OUT/$TAG.png 2>/dev/null
RSS=$(awk '/VmRSS/{print int($2/1024)}' /proc/$RV/status 2>/dev/null)
kill $RV $PUB 2>/dev/null; wait $RV $PUB 2>/dev/null
python3 - $OUT/$TAG.ft $OUT/$TAG.pub $TAIL "$TAG" "$RSS" <<'PY'
import sys, bisect
ft = [tuple(map(float, l.split())) for l in open(sys.argv[1]) if l.strip()]
pub = [(float(l.split()[0]), int(l.split()[2]), int(l.split()[4])) for l in open(sys.argv[2]) if ' frame ' in l]
tail, tag, rss = float(sys.argv[3]), sys.argv[4], sys.argv[5]
ts = [t for t, _ in ft]
def fps(t0, t1):
    i, j = bisect.bisect_left(ts, t0), bisect.bisect_left(ts, t1)
    d = sorted(x for _, x in ft[i:j])
    return (j - i) / (t1 - t0), (d[len(d) // 2] if d else float('nan'))
print(f'{tag}  (rss {rss} MiB)')
for k in range(1, len(pub)):
    f, m = fps(pub[k - 1][0], pub[k][0])
    print(f'  while publishing frames {pub[k-1][1]:5d}-{pub[k][1]:5d} ({pub[k][2]/1e6:6.1f}M pts): {f:5.1f} fps, median frame {m:7.1f} ms')
end = pub[-1][0] if pub else ts[0]
f, m = fps(end + 2, end + tail)
print(f'  steady state after {pub[-1][2]/1e6 if pub else 0:.1f}M pts: {f:5.1f} fps, median frame {m:7.1f} ms')
PY
