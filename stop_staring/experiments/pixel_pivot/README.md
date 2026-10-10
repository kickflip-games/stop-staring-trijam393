# 2D gameplay

Open the project in Godot and press **F5**, or run
`res://experiments/pixel_pivot/pixel_pivot.tscn` with **F6**. This is the
playable room and contains **one level**: four solid, symmetric quadrant islands and sixteen wall eyes.
Twelve eyes sit on the perimeter; four sit on the inward-facing island faces.
The former six alcoves, narrow arms and middle pockets are removed.
The complete room stays visible at once. There is no 2D level selection.

From the repository root, using the installed runtime:

```bash
GODOT_BIN='/Users/avi/Library/Application Support/Godot/app_userdata/Godots/versions/Godot_v4_8-dev6_macos_universal/Godot.app/Contents/MacOS/Godot'
"$GODOT_BIN" --path stop_staring --scene res://experiments/pixel_pivot/pixel_pivot.tscn
```

The runtime remains Godot 4.8.dev6 with the existing Compatibility renderer.
`project.godot` opens `res://ui/home_screen.tscn`; **Play** loads this scene.
The existing folder path is retained for scene references. **Home** in the
pause or clear panel returns to the title screen.

## Controls and game loop

Hold the left mouse button on the arena, pull back opposite the desired
direction, and release. Aim while moving to redirect; release replaces
velocity. The
dotted arrow shows launch direction. A drag shorter than two viewport
pixels cancels. Touch uses the same displacement rule.

Aiming slows gameplay to 0.25× while stretch and input remain responsive.
Charge adds tension wobble, a restrained rubber cue and a room-only
dim/desaturation effect that keeps the slime and brighter arrow in focus.
Release restores full speed and room color immediately, with recoil,
a short bright mint trail, a one-pixel camera pull and a sharp whoosh.
Strike an OPEN eye head-on with enough speed to close it. Its eyelid stays
in the solid wall and cannot count again while CLOSED. All targets are visible
in the fixed whole-room view.
**R** or the retry button resets immediately. **P** or **Escape** toggles
pause. Losing focus suspends play and cancels aiming. Resizing or releasing
over the HUD/outside the game view also cancels an unfinished gesture.

Every valid OPEN-eye hit starts **only that eye's 60-second closed timer**.
A CLOSED hit cannot refresh it or trigger eye feedback; it receives the normal
wall bounce. When its duration expires, that one eye snaps open and resumes
tracking. Other eyes retain their own remaining durations. The final three
seconds produce a subtle local eyelid twitch, without individual numbers.

Win by having **all sixteen eyes CLOSED simultaneously**. A final hit settles
all older deadlines first, then checks the closed count. If every eye is
closed, all individual timers stop, further launches are blocked, and the
existing final impact/quiet beat leads into the clear panel. Retry clears
every timer, squash, warning and reopening animation.

Eye durations use monotonic **real elapsed time**, including slow-motion and
hit-stop, excluding explicit pause and focus loss. The separate overall run
clock starts at the first launch, continues through individual reopens, and
freezes on success for clear-time scoring. It never reopens an eye or fails
a run. The HUD shows `CLOSED n / 16` plus `RUN` time. No global deadline,
heartbeat, collective wake-up flash or failure state remains.

The existing socket remains 24px wide (12px visible radius). Its wall-contact
hit window is now 15px, **25% wider than that visual radius**, increased from
14px. Surface-contact tolerance is 0.5px rather than 0.15px. Supporting wall,
minimum impact speed, surface normal rules, player collider and ricochets
remain unchanged. Real sweep tests include offsets beyond the old radius.

## Eye gaze cones

Open eyes cast translucent red cones that follow their pupils. Solid walls
and prop colliders clip the light, and it stops when an eye closes. Each
eye's independent reopen restores its cone immediately. Pause freezes
tracking; a completed clear extinguishes every cone. The effect stays
beneath the eyes, props and slime and changes no collision or timer rules.

Each eye exposes `gaze_enabled`, `gaze_length` (160 px),
`gaze_half_angle_degrees` (12°) and `gaze_opacity` (0.18).
See [matched gaze captures and checks](../../../docs/gaze_cones/README.md).
Run `res://experiments/pixel_pivot/tests/gaze_cones.gd` for the focused
state/occlusion checks and native screenshot refresh.

## Retro UI

`res://ui/retro_hud.tscn` owns the compact HUD and pause/clear panels.
`res://ui/retro_theme.tres` uses Press Start 2P at 8 pixels for body text
and 16 pixels for headings, nearest-filtered Kenney borders, dark navy
insets and mint progress pips. The complete room and UI scale together.

The **II** button pauses; **Continue [P]** resumes; **Retry [R]** and
**Play Again [R]** reset the room. Header and modal clicks cannot launch
the slime. The run clock shows one decimal place after launch; closed-count pips fill
and empty with individual eye states. Asset sources and licenses are in
`res://assets/ui/README.md`.
The arena builder retains this editable UI scene when regenerating the room.

See `docs/retro_ui/README.md` for the matched before/after and scale captures.
Run `res://experiments/pixel_pivot/tests/retro_ui.gd` with a native Godot
window for the UI checks and screenshot refresh.

## Scene and editable layout

`pixel_pivot.tscn` presents a nearest-filtered 448 × 336 SubViewport at an
uniform proportional scale that fills the available window, centered with
letterboxing only when its aspect ratio differs from the screen. The game starts
fullscreen; F11 toggles windowed mode on both the home screen and in gameplay.
Resizing or toggling fullscreen cancels an active aim gesture without launching.
It includes a separate
32-pixel HUD band above the room. Camera2D stays at the room center with
fixed zoom and no scrolling. Window stretch settings are changed only while the
experiment is loaded and restored on exit.

`pixel_arena.tscn` contains editable Floor, WallArt, WallTops, WallEdges and
WallInsets TileMapLayers, ten StaticBody2D rectangles, sixteen instances of
`wall_eye.tscn`, `slime.tscn`, Camera2D, Clock, Effects and HUD. Tile collision
is disabled here because the merged wall bodies provide collision. Physics
positions stay continuous; small visual offsets snap. Eight barrels retain
five-pixel circular colliders: four on the islands and four tucked near the
outer wall corners. Four crates have their existing 12 × 12-pixel box
colliders and sit against the side walls, clear of eye mounts. The scattered
props are fixed, mirrored placements; the whole central cross remains clear.
One wall grille, one banner and six animated torches remain
decoration. WallShadows supplies visual depth; WallInsets is empty. Each
island is a single 64 × 48-pixel solid rectangle with no neck or pocket.
The central vertical lane is 128 pixels wide; the uninterrupted horizontal
crossing, top and bottom lanes are 48 pixels wide. Side lanes are 64 pixels wide
between walls and islands; the wall-side crates occupy 12 pixels locally.
The side-wall midpoints have matching 16 × 48-pixel inward lips. Their
midpoint eyes sit on the exposed faces at (48, 184) and (400, 184), keeping
48 pixels clear at the shoulders. All gameplay geometry and eye positions
mirror about the spawn at (224, 184).

`layout.json` is the rebuild source. Its `islands` array holds the four
quadrant blocks; `wall_lips` holds the two attached perimeter extensions.
Coordinates are in 16-pixel tiles:

| Element | Origin | Size |
|---|---|---|
| Viewport including HUD | (0, 0) | 28 × 21 tiles |
| Room | (0, 2) | 28 × 19 tiles |
| Border | perimeter | 2 tiles thick |
| Upper left / right islands | (6, 7) / (18, 7) | 4 × 3, solid |
| Lower left / right islands | (6, 13) / (18, 13) | 4 × 3, solid |
| Left / right midpoint wall lips | (2, 10) / (25, 10) | 1 × 3, attached |
| Slime spawn | (14, 11.5) | fixed radius 5 px |

Each eye's origin lies on its supporting wall's physical surface. Its
`facing_normal` points into the reachable floor. The upright face uses a 32 × 32
socket canvas at 0.75× visual scale, inset sixteen pixels into the wall.
Hits match the swept collider,
normal, contact position and incoming normal speed. Counting is synchronous
and happens once per OPEN-to-CLOSED transition. `eye.gd` uses `State.OPEN` and
`State.CLOSED`; `reopen()` cancels the age-driven squash, resets eyelid transforms and
starts a 0.1-second squash-to-open snap while tracking resumes. Neither
reaction uses a delayed Tween callback. `closed_duration` is exported on
each eye. The arena supplies unscaled elapsed time to each eye and settles
all deadlines before accepting a hit or declaring a simultaneous win.

Regenerate scenes after editing the layout:

```bash
"$GODOT_BIN" --headless --path stop_staring --script ../tools/build_pixel_pivot.gd -- --arena-only
```

The arena-only option replaces the generated arena and presentation scenes
while retaining the current slime, eye and HUD scenes. Running without it
also rebuilds the slime and eye scenes. Alternatively, edit the native scenes
directly and keep the art boundary, wall body and eye attachment together.
There is no camera addon installed for this experiment; Camera2D is its
single camera driver.

## Selected art and atlas coordinates

Shared sheets and resources live in `res://assets/2d/dungeon_crawler/` and
`res://assets/2d/eyes/`. Atlas coordinates below are zero-based cells.

| Use | Source | Regions |
|---|---|---|
| Main floor / raised wall-top backing | full_tilemap, ID 0 | (3, 1) |
| Sparse floor variations | ID 0 | (4, 2), (5, 2), (3, 3), (2, 2) |
| Solid wall fill / cracked brick | ID 0 | (7, 4), (8, 5) |
| Top / bottom cap | ID 0 | (2, 7), (2, 6) |
| Left / right edge | ID 0 | (4, 5), (3, 5) |
| Top corners | ID 0 | (1, 7), (5, 7) |
| Bottom corners | ID 0 | (1, 6), (5, 6) |
| Inside corners | ID 0 | (3, 4), (4, 4), (3, 6), (4, 6) |
| Slime idle | full_spritesheet, ID 1 | six 16 × 16 frames, columns 0–5, row 3 |
| Slime run | ID 1 | six 16 × 16 frames, columns 0–5, row 4 |
| Barrel / red banner | ID 0 | (1, 0) / (4, 0), each 16 × 16 |
| Torch | ID 1 | columns 6–11, row 3, 16 × 16 |
| Wall grille | ID 0 | (7, 5), 16 × 16 |

The supplied floor uses a CanvasItem modulate color `(0.38, 0.66, 1.0)`
for the reference's dark slate palette. The PNGs are unchanged. Of the 306
visible floor cells, 284 (92.8%) use the quiet base slab; 22 wear/mark cells
are explicitly placed near walls and obstacles. The slime sprite renders at
1.5× with a brighter green tint; its physics body and collision remain unscaled.

The replacement eye sheet supplies the stone/empty socket crop at
pixel Rect2(744, 692, 300, 304), rendered on a 32 × 32 canvas. A native
20 × 20 off-white eyeball and separate 8 × 8 red/black pupil sit above it.
Pupil displacement is bounded to three pixels. The supplied full poses are
also configured in `eye_sprites.tres` and as five paintable scene tiles in
the shared TileSet; their high-resolution source PNG remains unchanged.
The gameplay CLOSED pose uses the same sheet's existing eyelid from
`eye_sprites.tres`, at the same 0.75× parent visual scale.

See `docs/quadrant_arena/README.md` for the current layout, matched arena
before/after, lane measurements and physical validation.

## Tuning defaults

Select Slime, Camera2D, Clock or a wall eye to tune exported properties.
The collider never scales with visual squash.

| Parameter | Default |
|---|---|
| Closed duration (each eye) | 60 s real time |
| Local reopening warning | final 3 s |
| Snap-open duration | 0.1 s |
| Drag deadzone / maximum | 2 / 48 viewport px |
| Minimum / maximum launch speed | 64 / 288 world px/s |
| Bounce retention | 0.9 |
| Exponential movement damping | 0.35 per second |
| Settle speed | 5.6 px/s |
| Maximum swept contacts per physics step | 8 |
| Aim time scale | 0.25 |
| Eye hit-stop | 40 ms real time |
| Final-hit hold / clear-panel reveal | 120 / 520 ms real time |
| Camera wall / launch / eye / final impulses | 1 / 1 / 2 / 3 logical px |
| Eye minimum incoming normal speed | 48 px/s |
| Eye tangent hit radius / contact tolerance | 15 / 0.5 px |
| Pupil tracking limit | 3 px |
| Camera framing | whole room; fixed zoom 1× |
| Camera follow / look-ahead | unused in this level |
| Bright launch window / trail lifetime | 0.22 / 0.14 s real time |
| Wall dust / eye pixel-burst lifetime | 0.16 / 0.32 s real time |

Clock is the only time-scale writer while this scene is loaded. It evaluates
hit-stop, then the current aim state, then normal time. Retry and focus loss
clear deadlines; no delayed restoration callback survives a reset. Existing
stretch, wall-impact and eye-pop sounds are reused alongside two retained
synthesized launch/hit cues in `audio/juice/`. Pause freezes visual ages and suspends
cue playback; retry cancels all pending feedback. The feedback shader and
extra cue players are installed by `effects.gd`, so scene rebuilding retains
them. The idle dungeon gets no additional ambient VFX.

## Verification and captures

The action-feedback fixture and matched captures are documented in
`docs/juice/README.md`. Run
`res://experiments/pixel_pivot/tests/juice.gd` headlessly for state checks or
with a native window to refresh the feedback gallery.

Run the focused regression fixture:

```bash
"$GODOT_BIN" --headless --path stop_staring --script res://experiments/pixel_pivot/tests/regression.gd
"$GODOT_BIN" --path stop_staring --script res://experiments/pixel_pivot/tests/regression.gd
"$GODOT_BIN" --headless --path stop_staring --script res://experiments/pixel_pivot/tests/independent_eyes.gd
"$GODOT_BIN" --path stop_staring --script res://experiments/pixel_pivot/tests/independent_eyes.gd
```

The fixture checks native GUI routing, resizing and viewport-space aiming,
real-time effect composition, rapid retry, maximum-speed swept corner
contacts, perimeter/structure containment, all sixteen actual contact hits,
counting once while closed, bounded tracking, final-eye visibility, clear/retry,
layout connectivity, and the configured default 2D entry point. Native mode
also saves the room before and after four hits under `docs/pixel_pivot/`.

The independent-eye fixture checks staggered real-time deadlines, no refresh
on closed hits, normal closed-eye bounces, wider physical hit contacts,
individual warnings and expiry while live physics/aiming continues, pause
and hit-stop handling, boundary contacts, rapid squash/snap/retry sequences,
simultaneous completion and frozen score time. Native mode saves current
HUD/eye captures under `docs/independent_eyes/`. These are scripted checks,
not a human clear or a difficulty measurement.

Capture the scripted live-physics movement demonstration:

```bash
"$GODOT_BIN" --path stop_staring --script res://experiments/pixel_pivot/tests/record_movement.gd --write-movie /private/tmp/pixel-pivot-movement.avi --fixed-fps 60
```

See the repository's `docs/pixel_pivot/README.md` for screenshots, the
short MP4 and recorded validation results. The movement demonstration
uses native pointer events with live physics. The full
clear fixture positions the player near each target to test contacts; it is
not a timed human clear.

This is one playable room. Human playtesting is still needed for
launch feel, the audio mix and routing difficulty with 60-second independent eye durations.
Native mouse input was tested; touch and browser/device performance were
not tested. Attribution is recorded in `res://CREDITS.md`, with local
provenance in `docs/third_party_assets.md`.
