#!/usr/bin/env bash
# Key cases with the final shaders, base/new interleaved.
for C in "Boxes 1000000 10" "Flat Squares 1000000 10" "Boxes 6500000 0" "Flat Squares 6500000 0"; do
  set -- $C; if [ $# = 4 ]; then STYLE="$1 $2"; N=$3; R=$4; else STYLE=$1; N=$2; R=$3; fi
  for V in base new; do
    bash /workspace/ws/src/rviz/docker/bench/run_bench.sh $V "$STYLE" $N gpu $R 10 | head -1
  done
done
