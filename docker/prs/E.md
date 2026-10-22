> Stacked on the D1 PR (__D1__): the first commit of this branch is that PR. Please review the last commit only.
> Best merged together with __B__: changing the new property rebuilds the buffers, which draws
> clouds twice without that fix.

## Description

Accumulating clouds (large Decay Time, e.g. a SLAM map) quickly puts far more points on screen
than there are pixels: seen from afar, hundreds of points land on every pixel and RViz renders
all of them every frame.

This adds a "Max Points Per Pixel" property to the point cloud displays. 0, the default, keeps
the current behaviour. When set:

- Each renderable stores its points in a voxel hierarchy order (one point per coarse voxel first,
  then one more per voxel of half the size, and so on; computed with a Morton code radix sort),
  so any prefix of a buffer covers the whole cloud evenly and sparse regions are kept.
- Every frame, `PointCloudCommon` shares a budget of points per screen pixel between the visible
  clouds by their projected area ("water filling": clouds that are sparse on screen keep all
  their points, dense ones are thinned evenly), and each renderable draws a prefix of its buffer.
  No buffer is re-uploaded.
- The budget only applies to the camera it was computed for, so selection and other views
  (render panels, Camera displays) still draw every point.

Related: #1077.

### Is this user-facing behavior change?

Only when the new property is set. 1000 accumulated KITTI 00 scans (121M points), Points style,
4 points per pixel: median frame time 23.2 -> 8.6 ms. The map looks the same; which point ends
up on top of a pixel varies (RMSE 3.9% after downscaling both screenshots by 4). With all PRs
of this series, all 4541 scans (552M points) render at the 50 FPS cap of the benchmark (9 ms
median).

Styles whose points are much smaller than a pixel (e.g. Flat Squares of 1 cm seen from far
away) look sparser with level of detail, because the full cloud only fills pixels by drawing
many sub-pixel squares on top of each other.

### Did you use Generative AI?

Yes. Claude Opus 5.5 (Claude Code) designed and wrote the change, the tests and the benchmarks.
I tested it interactively with the KITTI replay.

### Additional Information

- Tests: the budget limits drawn vertices only with level of detail on; the budget only applies
  to its camera; a 10% prefix of the buffer contains all points of a sparse far region.
- Selection on a thinned 5M point cloud gives the same selected points as without level of
  detail. Top-down ortho views are covered (the scale comes from the projection matrix).
- Changing the property between 0 and a positive value rebuilds all buffers once.
- Changes the layout of `PointCloud` and `PointCloudRenderable`, so it is for Rolling only.
