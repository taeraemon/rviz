# Pull request drafts for ros2/rviz

Six independent PRs against `rolling`, in suggested submission order. Branches are on
github.com/taeraemon/rviz. All numbers: ROS Rolling on Ubuntu 26.04.1 (container), GCC 15.2,
Qt 6.10.2, Ogre 1.12.10, NVIDIA RTX 4090 (driver 580.178.04) through VirtualGL/EGL; frame
times include ~5 ms of VirtualGL readback per frame. Data: KITTI odometry sequence 00 replayed
as registered scans (each scan published in the map frame, accumulated with a large Decay Time).

| # | Branch | Depends on | ABI |
|---|---|---|---|
| A | `perf/pointcloud-geometry-shaders` | – | unchanged (backportable) |
| B | `pr/pointcloud-double-render` | – | unchanged (backportable) |
| C | `pr/pointcloud-shared-materials` | – | unchanged |
| D1 | `pr/pointcloud-release-transformed-points` | – | adds inline getters |
| D2 | `pr/pointcloud-compact-points` | D1 | private member type changes |
| E | `pr/pointcloud-lod` | D1 (B recommended) | changes class layout, Rolling only |

Before opening: rebase each on the latest `upstream/rolling` and rerun `docker/bench/pr_check.sh`.

---

## A. Expand point cloud billboards and boxes with geometry shaders

## Description

The Squares, Flat Squares, Spheres and Boxes styles only have "nogp" techniques today, so
`PointCloud` writes 6 vertices per point (36 for Boxes), 28 bytes each, into the vertex buffers.
The geometry shader techniques rviz1 used were disabled in #851 and removed in #1600, but
`PointCloud` still supports them (one 16 byte vertex per point).

This brings them back as `gp` techniques placed before the existing `nogp` ones in the
`scripts120` materials. Ogre picks the first supported technique, so drivers without geometry
program support keep using the `nogp` techniques exactly as before. That missing fallback is
most likely why the GLSL 1.50 materials failed to load in #851: with Ogre 1.12 the GL render
system only reports geometry programs when `GL_EXT_geometry_shader4` is exposed, which Mesa does
not do, so those materials had no usable technique. The shaders are also fixed to be valid GLSL
1.50 compatibility profile code (no `gl_PerVertex` redeclaration).

The geometry shaders reproduce the nogp billboard orientation, texture coordinates and box
shading, so the output is unchanged.

Related: #1077, #1308.

### Is this user-facing behavior change?

Large point clouds render much faster and use far less GPU and system memory on drivers with
geometry shaders (NVIDIA, including Jetson). Nothing changes on drivers without them.

- Vertex data per point: 168 -> 16 bytes (squares, spheres), 1008 -> 16 bytes (boxes).
- GPU memory, static 6.5M point cloud: Flat Squares 1147 -> 200 MiB, Boxes 6382 -> 200 MiB.
- 1M point cloud streamed at 10 Hz: Flat Squares 30 -> 42 FPS, Boxes 3 -> 45 FPS.
- KITTI 00, 1500 accumulated scans (181M points), Flat Squares: 0.7 -> 38 FPS. Without the
  change the vertex buffers exceed the 24 GB of VRAM at about 160M points and the driver starts
  paging. Resident memory drops from about 260 to 85 bytes per point, since the driver keeps a
  system memory copy of every vertex buffer.

### Did you use Generative AI?

Yes. Claude Opus 5.5 (Claude Code) found the cause, wrote the change and the benchmarks, and ran
the tests. I tested the result interactively with the KITTI replay.

### Additional Information

- Screenshots of all six styles match the current rendering (RMSE below 0.4%; Points and Tiles
  identical). Selecting points with the Select tool gives pixel-identical results.
- Mesa llvmpipe: Ogre reports no geometry programs, the nogp techniques are used, and rendering
  is unchanged.
- `colcon test` for rviz_rendering and rviz_default_plugins (including linters) passes. CI runs on
  Mesa, so it only covers the fallback path; the geometry shader path was checked on NVIDIA.
- Not tested: Ogre 14 (#1655), Windows, macOS, AMD/Intel hardware drivers.

---

## B. Do not attach point cloud renderables to the scene node

## Description

`PointCloud` queues its renderables itself in `_updateRenderQueue()`. When renderables are created
while the cloud is already attached to a node (every `regenerateAll()`: style change,
`setColor()`, point selection), `createRenderable()` also attached them to that node, so Ogre
queued them a second time and the cloud was drawn twice from then on (and blended twice with
alpha < 1). Renderables created before the cloud is attached, which is the normal path in
`PointCloudCommon`, were not affected, which is why this went unnoticed.

### Is this user-facing behavior change?

After changing the style of a point cloud display, or selecting points, the cloud no longer costs
twice the rendering work, and translucent clouds no longer turn more opaque.

### Did you use Generative AI?

Yes. Claude Opus 5.5 (Claude Code) found the bug during a review and wrote the fix and the test.

### Additional Information

- New test `regenerating_an_attached_cloud_does_not_attach_its_renderables` fails on unchanged
  code (2 objects attached to the node instead of 1) and passes with the fix.
- #1655 touches the same `detachObject()` loop (guarding it with `isAttached()` for Ogre 14);
  with this change the loop is not needed anymore.

---

## C. Share materials between point clouds

## Description

Every `PointCloud` cloned six materials (one per style), only so that `setAlpha()` could switch
their blending mode per cloud. Everything else that differs between clouds (size, alpha,
highlight, pick colour) is already passed per renderable as custom parameters.

This keeps one shared clone per style and blending mode instead. Creating a cloud no longer
clones and loads six materials, and Ogre renders the renderables of many clouds in one pass
instead of switching material for every cloud.

### Is this user-facing behavior change?

Many accumulated clouds (large Decay Time, e.g. laser scans) render faster: 4541 small clouds
(KITTI 00, every 100th point, Points style): median frame time 27.3 -> 12.6 ms, resident memory
1032 -> 785 MiB.

### Did you use Generative AI?

Yes. Claude Opus 5.5 (Claude Code) wrote the change, the test and the benchmark.

### Additional Information

- Material names change from `PointCloudMaterial<N><Style>` to `rviz/PointCloud<Style>/Opaque`
  and `.../AlphaBlended`; the existing test checking the names was updated.
- New test: two clouds share a material, and `setAlpha()` on one does not change the other.
- No API or ABI change (one private non-virtual member function added).

---

## D1. Release transformed points once they are in the point cloud

## Description

`CloudInfo::transformed_points_` and the `rviz_rendering::PointCloud` built from it held the same
points, so every displayed point was kept in RAM twice (28 bytes each), on top of the message.

This frees `transformed_points_` right after the cloud is built and reads positions for
selection and the point count for the status from the cloud instead (new
`PointCloud::getPoint()` and `getNumPoints()`).

### Is this user-facing behavior change?

Less memory for accumulated clouds: 1000 KITTI scans (121M points), 28.1 -> 25.9 GB resident.

### Did you use Generative AI?

Yes. Claude Opus 5.5 (Claude Code) wrote the change and measured it.

### Additional Information

- `CloudInfo` is exported; code outside rviz that reads `transformed_points_` after the cloud was
  created now finds it empty. The selection handler test now leaves it empty like
  `PointCloudCommon` does, so it covers the new path.
- `retransform()` refills and releases it the same way.

---

## D2. Store point cloud colours packed like the hardware buffers

Depends on D1.

## Description

`PointCloud` keeps a CPU copy of its points to rebuild the hardware buffers (style changes,
selection). It stored colours as four floats, 28 bytes per point, although the buffers only hold
8 bit RGBA. This stores them packed (16 bytes per point); rebuilt buffers are bit for bit the
same.

### Is this user-facing behavior change?

Less memory: 1000 KITTI scans (121M points), 25.9 -> 24.6 GB resident (on top of D1).

`getPoints()` and `getPoint()` now return colours at 8 bit precision, which is what was drawn
anyway. One test comparing exact float colours was adapted.

### Did you use Generative AI?

Yes. Claude Opus 5.5 (Claude Code) wrote the change and the tests.

### Additional Information

New test: colours and positions are unchanged after 20 buffer rebuilds (selection rebuilds twice
per pick).

---

## E. Add level of detail for large point clouds

Depends on D1 (`getNumPoints()`); B is recommended, since toggling the property rebuilds the
buffers.

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
up on top of a pixel varies (RMSE 3.9% after downscaling both screenshots by 4). Together with A
and C, all 4541 scans (552M points) render at the 50 FPS cap of the benchmark (9 ms median).

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
