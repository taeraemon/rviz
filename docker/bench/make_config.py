"""usage: make_config.py <style> <out.rviz>  (style: Points|Squares|Flat Squares|Spheres|Boxes)"""
import sys

style, out = sys.argv[1], sys.argv[2]
size = sys.argv[3] if len(sys.argv) > 3 else "0.05"
dist = sys.argv[4] if len(sys.argv) > 4 else "90"
decay = sys.argv[5] if len(sys.argv) > 5 else "0"
px = sys.argv[6] if len(sys.argv) > 6 else "3"
open(out, 'w').write(f"""Panels: []
Visualization Manager:
  Class: ""
  Displays:
    - Class: rviz_default_plugins/PointCloud2
      Enabled: true
      Name: PointCloud2
      Style: {style}
      Size (m): {size}
      Size (Pixels): {px}
      Selectable: true
      Decay Time: {decay}
      Color Transformer: Intensity
      Autocompute Intensity Bounds: true
      Position Transformer: XYZ
      Topic:
        Depth: 5
        Durability Policy: Transient Local
        History Policy: Keep Last
        Reliability Policy: Reliable
        Value: /cloud
      Value: true
  Enabled: true
  Global Options:
    Background Color: 48; 48; 48
    Fixed Frame: map
    Frame Rate: 50
  Name: root
  Tools:
    - Class: rviz_default_plugins/MoveCamera
  Value: true
  Views:
    Current:
      Class: rviz_default_plugins/Orbit
      Distance: {dist}
      Focal Point: {{X: 0, Y: 0, Z: 0}}
      Name: Current View
      Near Clip Distance: 0.01
      Pitch: 0.6
      Target Frame: <Fixed Frame>
      Value: Orbit (rviz)
      Yaw: 0.785398
    Saved: ~
Window Geometry:
  Height: 1000
  Width: 1600
  X: 0
  Y: 0
""")
