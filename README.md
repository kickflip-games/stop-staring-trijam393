# stop-staring-trijam393

Godot 4.8.dev6. The project is in `stop_staring/`.

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
godot --headless --path stop_staring --script res://tests/wall_eye.gd
```

## Wall-eye prototype (issue #6)

One googly eye sits inset into the top wall. Its pupil follows the player,
with a bounded spring response to ricochets. Fling into the eye to pop it;
an empty socket remains and the HUD updates the remaining count. Reload
the scene to try again. A hit requires at least 3 units/second **into the
wall**, so a fast, shallow graze does not count.

`scenes/eye.tscn` is reusable: place its XY origin on the arena-facing wall
surface, put Z slightly in front of the wall mesh (1.06 here), and point
local -Y into the arena. For example, rotate Z by -90 degrees on the right
wall. Set its `player_path` and `wall_path`; tune `hit_radius`,
`min_impact_speed`, and `tracking_limit` in the inspector. Keep the pupil
limit at or below 0.35 to retain it inside the supplied sclera.

The eye uses the player's swept `wall_contact` signal rather than an
overlap trigger. Every incoming wall contact reports its normal speed,
including multiple ricochets within a physics step. The level connects
each eye's one-shot `popped` signal and emits `remaining_eyes_changed` and
`all_eyes_popped`. Walls retain their existing collision and bounce behavior.

Run `wall_eye.gd` without `--headless` to also save tracking and popped
runtime screenshots to `/tmp/stop-staring-eye-{tracking,popped}.png`.

## Publish to itch.io

`publish.sh` exports a single-threaded Web build and uploads it to
`avivajpeyi/stop-staring:html5`.

Install matching Web export templates through Godot's **Manage Export Templates**, and install
itch.io Butler. Run `butler login` once if needed.

From this repository:

```bash
./publish.sh --check       # Check tools and main scene; no build or upload
./publish.sh --build-only  # Export locally; no upload
./publish.sh --dry-run     # Export and validate with Butler; no upload
./publish.sh               # Export and upload
```

Outputs: `build/web/index.html` and `build/stop-staring-web.zip`.
Import/export logs and an isolated project copy are also under `build/`.

Set `GODOT_BIN` (or `GODOT`), `BUTLER`, or `ITCH_TARGET` to override defaults.
The script prefers the installed Godot 4.8.dev6 runtime, then `godot`/`godot4`
on your PATH. It can be invoked from any working directory.

On the itch.io edit page, set the game kind to HTML and mark the `html5` upload
as **This file will be played in the browser**. The build does not require
SharedArrayBuffer support.
