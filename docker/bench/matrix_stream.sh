#!/usr/bin/env bash
# Streaming LiDAR: a new cloud every 100 ms (10 Hz), baseline vs patched.
for GL in gpu mesa; do
  for N in 300000 1000000; do
    for STYLE in "Flat Squares" "Boxes"; do
      for V in base new; do
        bash /workspace/ws/src/rviz/docker/bench/run_bench.sh $V "$STYLE" $N $GL 10 10 | head -1
      done
    done
  done
done
