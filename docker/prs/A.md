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
  paging. Resident memory drops from about 273 to 89 bytes per point, since the driver keeps a
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
