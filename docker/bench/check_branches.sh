#!/usr/bin/env bash
# Run pr_check.sh (build + tests + linters) for each given branch in the docker/pr_src worktree.
for branch in "$@"; do
  git -C /home/tykim/Documents/project_slam/rviz/docker/pr_src switch -q --detach "$branch" || exit 1
  echo "== $branch $(git -C /home/tykim/Documents/project_slam/rviz/docker/pr_src rev-parse --short HEAD)"
  docker exec rviz-rolling bash -c 'rm -rf /workspace/ws/pr/build/*/test_results'
  docker exec rviz-rolling bash /workspace/ws/src/rviz/docker/bench/pr_check.sh rviz_default_plugins rviz_rendering
done
