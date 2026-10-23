## Description

The Orbit view clamps the pitch just short of looking straight down or up, so the camera cannot
be rotated over the top or under the bottom of the scene, as CAD programs and many 3D viewers
allow.

This adds a "Free Orbit" option to the Orbit view, off by default. When enabled, the pitch wraps
around instead of being clamped. The camera orientation is then built directly from yaw and
pitch, so the up direction stays continuous over the poles (the fixed yaw axis used today would
flip the view there). While the camera is upside down the yaw direction is reversed, so the scene
still follows the mouse, and `lookAt()` (e.g. the Focus Camera tool) keeps an upside down camera
upside down instead of flipping it.

The Pitch property now allows -pi..pi so that a saved upside down view loads. Without Free Orbit
the pitch is still kept within the previous limits. XYOrbit and ThirdPersonFollower hide the
option.

### Is this user-facing behavior change?

Only when the new option is enabled. With it disabled (the default) the Orbit view behaves as
before; the only visible difference is the wider range of the Pitch property, which is clamped
back to the old limits.

### Did you use Generative AI?

Yes. Claude Opus 5.5 (Claude Code) wrote the change and the tests. I tested it interactively on
a KITTI odometry map replayed into rviz.

### Additional Information

- New unit tests: the pitch still stops at the pole without the option; with it, the camera goes
  over the pole and ends up upside down looking at the focal point; `lookAt()` keeps it there.
- The Orbit and XYOrbit view controller tests and the rviz_default_plugins linters (uncrustify,
  cpplint, cppcheck, copyright, lint_cmake, xmllint) pass.
- __OTHER__ (Navigate At Cursor) changes neighbouring lines of the same files; whichever is
  merged second needs a trivial rebase.
