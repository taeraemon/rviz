#!/usr/bin/env bash
# Build and test (including the ament linters CI runs) a PR branch checked out in docker/pr_src.
# usage: pr_check.sh <packages...>
WS=/workspace/ws; export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1
pgrep -x Xvfb >/dev/null || { Xvfb :99 -screen 0 1920x1080x24 >/dev/null 2>&1 & sleep 1; }
source /opt/ros/rolling/setup.bash; source $WS/install_ogre/setup.bash
mkdir -p $WS/pr && cd $WS/pr
colcon build --base-paths $WS/src/rviz/docker/pr_src --packages-up-to "$@" \
  --packages-skip rviz_ogre_vendor \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON -DEnableDisplayTests=True \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache 2>&1 | grep -E "^(Summary|Failed)|error:" 
colcon test --base-paths $WS/src/rviz/docker/pr_src --packages-select "$@" --ctest-args -E visual \
  --event-handlers console_direct- >/dev/null 2>&1
colcon test-result --all --verbose 2>&1 | grep -E "^build/.*(failure|error)|<<< failure|^ *(Value|Expected|Actual)|\.cpp:[0-9]+:|Summary" | grep -v "^build.* 0 errors, 0 failures" | head -30
