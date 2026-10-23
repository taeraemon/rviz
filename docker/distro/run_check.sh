#!/usr/bin/env bash
# Build and test the docker/bp_<distro> worktree in the rviz-<distro> image (ccache kept per distro).
for d in "$@"; do
  echo "== $d $(git -C /home/tykim/Documents/project_slam/rviz/docker/bp_$d log --oneline -1)"
  docker run --rm -v /home/tykim/Documents/project_slam/rviz/docker/bp_$d:/src \
    -v /home/tykim/Documents/project_slam/rviz/docker/ws/distro_$d:/workspace \
    -v /home/tykim/Documents/project_slam/rviz/docker/distro/check.sh:/check.sh:ro \
    -e CCACHE_DIR=/workspace/.ccache rviz-$d bash /check.sh
done
