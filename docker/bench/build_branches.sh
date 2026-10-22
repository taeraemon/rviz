#!/usr/bin/env bash
# Build each given branch of the docker/pr_src worktree into /workspace/ws/pr/install_<name>.
# usage (host): build_branches.sh name=branch ...
for spec in "$@"; do
  name=${spec%%=*}; branch=${spec#*=}
  git -C /home/tykim/Documents/project_slam/rviz/docker/pr_src switch -q --detach "$branch" || exit 1
  echo "== $name ($branch $(git -C /home/tykim/Documents/project_slam/rviz/docker/pr_src rev-parse --short HEAD))"
  docker exec rviz-rolling bash -c "source /opt/ros/rolling/setup.bash && source /workspace/ws/install_ogre/setup.bash && cd /workspace/ws/pr && colcon build --base-paths /workspace/ws/src/rviz/docker/pr_src --packages-up-to rviz2 --packages-skip rviz_ogre_vendor --build-base build_$name --install-base install_$name --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_CXX_COMPILER_LAUNCHER=ccache 2>&1 | grep -E 'error|Summary'"
done
