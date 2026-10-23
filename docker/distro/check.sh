#!/usr/bin/env bash
# Build rviz up to rviz_default_plugins from the mounted source and run its tests on Mesa.
# usage (in container): check.sh [ctest regex]
export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1
Xvfb :99 -screen 0 1920x1080x24 >/dev/null 2>&1 & sleep 1
source /opt/ros/$DISTRO/setup.bash
cd /workspace/build_$DISTRO 2>/dev/null || { mkdir -p /workspace/build_$DISTRO && cd /workspace/build_$DISTRO; }
colcon build --base-paths /src --packages-up-to rviz_default_plugins --packages-skip rviz_ogre_vendor \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON -DEnableDisplayTests=True \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache 2>&1 | grep -E "^(Summary|Failed)|error:"
colcon test --base-paths /src --packages-select rviz_rendering rviz_default_plugins \
  --ctest-args -E "${1:-visual}" --event-handlers console_direct- >/dev/null 2>&1
colcon test-result --all --verbose 2>&1 | grep -E "<<< failure|^ *(Value|Expected|Actual)|Summary|\.cpp:[0-9]+$" | head -20
