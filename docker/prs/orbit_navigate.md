## Description

The Orbit view always rotates around and zooms towards its focal point. Zooming changes the
distance to the focal point by a fraction of itself, so it slows down and stops at the focal
point, and the only way to get close to something else is to move the focal point first (or use
the Focus Camera tool). In large scenes such as accumulated point cloud maps this makes it hard
to zoom into a region and look around there. A fast right drag can also push Distance to its
0.001 minimum, after which zooming back out takes a very long time.

This adds a "Navigate At Cursor" option to the Orbit view, off by default. When enabled, the
controller picks the point under the mouse with the view picker (the nearest point in a 13x13
pixel patch, so sparse point clouds can be grabbed), and works the way most CAD programs do:

- The wheel and right drag zoom towards the picked point.
- Left drag rotates around the point picked on press, which stays where it is on the screen.
- Middle drag (and Shift + left drag) pans so that the picked point follows the cursor.
- If nothing is under the cursor, the wheel moves the camera and the focal point together along
  the cursor ray, so zooming never stalls.

On press the focal point is moved along the view axis to the depth of the picked point. The
camera itself does not move, but Distance, the pan speed and the focal shape size then follow
what is under the cursor. While dragging, the focal shape is shown at the picked point. XYOrbit
and ThirdPersonFollower keep their focal point on the XY plane, so they hide the option, and it
stays off there even if a config file enables it.

### Is this user-facing behavior change?

Only when the new option is enabled. With it disabled (the default) the Orbit view behaves
exactly as before.

### Did you use Generative AI?

Yes. Claude Opus 5.5 (Claude Code) wrote the change and the tests. I tested it interactively on
a KITTI odometry map replayed into rviz.

### Additional Information

- New unit tests (using the existing `MockViewPicker`): the wheel zooms towards the picked
  point, the wheel keeps moving with nothing under the cursor, rotating keeps the picked point
  fixed in the camera frame, panning moves the picked point exactly with the mouse, wheel events
  that arrive between two frames all count, and the option stays off in XYOrbit.
- Picking uses the depth pass, which covers every visible object (not only selectable ones),
  like the Focus Camera tool. Mouse coordinates are already in physical pixels, so this also
  works with HiDPI scaling.
- Picking renders one small depth patch per wheel step or button press. With the KITTI 00 map
  accumulated in the view (RTX 4090), the median pick took 10-12 ms.
- The Orbit and XYOrbit view controller tests and the rviz_default_plugins linters (uncrustify,
  cpplint, cppcheck, copyright, lint_cmake, xmllint) pass, also with AddressSanitizer and
  UndefinedBehaviorSanitizer. The changed files compile without warnings with GCC 15 and Clang 21
  (`-Wall -Wextra -Wpedantic -Wshadow`).
- Scripted mouse tests (xdotool) on a KITTI map with NVIDIA and with Mesa llvmpipe (the Mesa
  driver stack, as used by Intel and AMD GPUs): picking, zooming, rotating and panning behave the
  same. Not tested on Windows or macOS.
- Approaching a picked surface slows down like in CAD programs and does not pass through it;
  rotating or panning gets past it.
- Adds members to `OrbitViewController`, so it is not ABI compatible for a backport.
- __OTHER__ (Free Orbit) changes neighbouring lines of the same files; whichever is merged second
  needs a trivial rebase.
