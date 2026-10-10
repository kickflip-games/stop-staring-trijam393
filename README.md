# stop-staring-trijam393



Godot 4.8dev6

## Menu and levels

Press F5 for the Kickflip splash and title menu. Start begins room 1;
Level Select opens any of the three rooms. Pop every eye to clear a room
and advance. R retries the current room; Escape returns to the menu.
Retry resets the timer and all targets.

`scenes/game.tscn` owns navigation. `scripts/game.gd` defines three layouts
with 1, 3, and 6 eyes and reuses `scenes/main.tscn` for each room.
These are prototype layouts; difficulty and movement feel still need playtesting.

```bash
godot --headless --path stop_staring --script res://tests/menu_levels.gd
```

## Graybox prototype

Open `stop_staring/project.godot` and press F6 on `scenes/main.tscn`
to run the arena directly. The gameplay scene contains an orthographic view of an 18 × 10
unit arena, four static collision walls, and a mint sphere placeholder.
Gameplay uses XY with Z fixed at zero. Hold the mouse or a finger anywhere,
drag back opposite the desired
direction, and release to fling. The arrow shows direction and strength.
Tiny drags cancel; long drags cap at maximum strength. Release replaces the
current velocity, and losing focus cancels an unfinished gesture.

Select `Player` in the main scene to tune maximum drag distance, deadzone,
and minimum/maximum launch speed, bounce retention, movement damping,
and settling speed. The sphere uses swept collision movement and reflects
velocity from wall normals, retaining 90% speed per hit by default.
Exponential damping slows it over time; below 0.35 units/second it settles.
The dotted aim preview shows up to 0.8 seconds of travel, stopping at the
first sphere-wall contact. Tune its duration on `HUD/AimIndicator`.

Run the input and ricochet checks with your Godot executable:

```bash
godot --headless --path stop_staring --script res://tests/launch_controls.gd
godot --headless --path stop_staring --script res://tests/ricochets.gd
```

