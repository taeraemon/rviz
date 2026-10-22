# Point cloud performance: dev environment

Tooling for the `perf/pointcloud-*` branches. Kept on the `dev/tools` branch only, so the
feature branches stay clean for upstream.

## Container

```bash
docker/rolling/run_container.sh   # ros:rolling + VirtualGL (EGL) + Xvfb + perf/heaptrack
```

Inside, the workspace is `/workspace/ws` (host: `docker/ws`, ignored) and KITTI odometry is
mounted at `/data/kitti_odometry`. Unmodified upstream is built from a worktree for A/B runs:

```bash
git worktree add --detach docker/base_src rolling
# in the container
colcon build --base-paths src --packages-skip rviz_ogre_vendor        # this branch -> install/
cd base && colcon build --base-paths /workspace/ws/src/rviz/docker/base_src \
  --packages-skip rviz_ogre_vendor --packages-up-to rviz2              # upstream -> base/install/
```

`rviz_ogre_vendor` is built once into `install_ogre/` and sourced by both.

## Interactive demo (on a desktop session)

```bash
docker/demo/run_kitti_demo.sh [new|base] [rate_hz] [frames]
```

Replays KITTI 00 as registered scans into rviz2 (huge Decay Time). Rendering uses the NVIDIA
GPU through VirtualGL and is shown on `$DISPLAY`. Toggle "Max Points Per Pixel" (0 = off).

## Benchmarks (headless, inside the container)

| Script | What it measures |
|---|---|
| `bench/run_bench.sh` | frame time / GPU memory for a synthetic static or streamed cloud |
| `bench/run_kitti.sh` | FPS vs accumulated points while replaying KITTI 00 (`PPP=` sets LOD, `PROFILE=1` runs perf) |
| `bench/select_test.sh` | Select tool result, for comparing variants |
| `bench/profile_ingest.sh` | perf profile of message ingestion |
| `bench/memmap.sh`, `bench/heap.sh` | resident memory by mapping, heaptrack peaks |
| `bench/lod_order_bench.cpp` | level of detail ordering micro benchmark |

Frame times come from `bench/frametime.cpp`, an `LD_PRELOAD` shim timing
`Ogre::Root::renderOneFrame()`; they include the VirtualGL readback (~5 ms per frame).
