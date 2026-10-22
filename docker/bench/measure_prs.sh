#!/usr/bin/env bash
# Per-PR measurements against unmodified upstream (run inside the bench container).
R=/workspace/ws/src/rviz/docker/bench/run_kitti.sh
echo "### C: 4541 small clouds (every 100th point), Points"
for V in base pr_C; do SUBSAMPLE=100 bash $R $V Points scan 4541 50 15 | grep -E "rss|steady"; done
echo "### D1/D2: resident memory after 1000 scans, Flat Squares"
for V in base pr_D1 pr_D2; do bash $R $V "Flat Squares" scan 1000 20 5 | grep -E "rss|steady"; done
echo "### E: 1000 scans, Points, level of detail off/on"
bash $R base Points scan 1000 20 15 | grep -E "rss|steady"
PPP=4 bash $R pr_E Points scan 1000 20 15 | grep -E "rss|steady"
