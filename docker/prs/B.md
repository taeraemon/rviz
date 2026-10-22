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
