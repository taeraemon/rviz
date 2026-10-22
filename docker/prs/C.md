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
