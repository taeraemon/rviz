Backport of #1882 to Jazzy.

## Description

Changing a color or transformer property calls `PointCloudCommon::retransform()`, which uses
`PointCloud::clear()` and then `addPoints()`. `clear()` keeps the CPU point vector, so every
change appends another full copy of the cloud: memory grows with every change, and the next
style, size or selection change regenerates the geometry from all copies, so points in their old
colors are drawn again. On large accumulated clouds a few colour changes are enough to exhaust
RAM. The fix uses `clearAndRemoveAllPoints()`, as in #1882.

### Is this user-facing behavior change?

Yes. Repeated colour/transformer changes no longer grow memory or bring back points in old
colours. See #1882 for measurements.

### Did you use Generative AI?

Yes. Claude Opus 5.5 (Claude Code) prepared the backport and adapted the tests.

### Additional Information

- The change itself cherry-picks cleanly. The new tests in #1882 call `update()` with
  `std::chrono` durations; on Jazzy it takes floats, so they call `update(0, 0)` like the other
  tests in that file (otherwise the test does not compile).
- Built and tested on `ros:jazzy-ros-base` with Mesa llvmpipe: `colcon test` for rviz_rendering and
  rviz_default_plugins passes.
