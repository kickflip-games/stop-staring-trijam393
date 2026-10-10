# Animated cover

Rebuilt 2026-10-11 from a fresh native Godot capture of the current checkout.

Entry: `ui/home_screen.tscn`; Play loads `experiments/pixel_pivot/pixel_pivot.tscn`. The existing `record_movement.gd` fixture instantiates that same gameplay scene and sends native pointer input with live physics. Capture: 4 launches, 12 bounces, 14 of 16 eyes remaining. The recording shows the four quadrant islands and gaze cones. Godot reported resource leaks on exit, after recording completed.

`current-gameplay.mp4` retains the uncomposited capture. `stop-staring-cover.gif` overlays the supplied transparent title, crops out the HUD, and plays six seconds forward then backward for a continuous 12-second loop at 15 fps, 640 × 480. `stop-staring-cover.png` is the matching still.

## Source hashes at capture

- `stop_staring/project.godot`: `7d6a371cb61e426f70e8d6730b4dac6c5146328dd17720e94b7ddaa73d68018e`
- `stop_staring/ui/home_screen.gd`: `d3457531f4f39d4b2a64a971c8d4ecf1febfa512459fa25f1954c67ef4200709`
- `stop_staring/experiments/pixel_pivot/pixel_pivot.tscn`: `1aea0d246931122c6a519fa447fcb809153df24d6181e46776fb53ef299c7f9d`
- `stop_staring/experiments/pixel_pivot/pixel_arena.tscn`: `04e08fbb5aea22e28f1d49218cc5ab300d63e7909581927c6b78a7de0e7f10a5`
- `stop_staring/experiments/pixel_pivot/arena.gd`: `7319bce0038c1ffc9c86f45b860582684d0e0d9d36996bc1d1783dca573d43de`
- `stop_staring/experiments/pixel_pivot/eye.gd`: `fac4889973e215a7d0366b703ad641a87857df3b507b759308321e7d9f9e55f0`
- `stop_staring/experiments/pixel_pivot/gaze_cone.gd`: `840c914d2180f668379a0a8d5661d6b3301f35e9dbfd69d42d268f3d770965ed`
- `stop_staring/experiments/pixel_pivot/tests/record_movement.gd`: `afa5454d72bf1201affe51d327428a0d43ca26d3590ece1b34c9c79181cc0439`
