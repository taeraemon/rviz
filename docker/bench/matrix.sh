#!/usr/bin/env bash
# Static-cloud render cost on the GPU, baseline vs patched.
for N in 1000000 6500000; do
  for STYLE in "Points" "Flat Squares" "Squares" "Spheres" "Boxes"; do
    for V in base new; do
      bash /workspace/ws/src/rviz/docker/bench/run_bench.sh $V "$STYLE" $N gpu 0 10 | head -1
    done
  done
done
