# Action feedback pass

This is a historical checkpoint. The current gameplay uses [independent 60-second eye timers](../independent_eyes/README.md) and wins when all eyes are closed simultaneously.

The feedback is driven by charge, launch, collision, cycle expiry and success.
The room stays quiet between actions. All feedback lives in the existing 2D
gameplay scripts and survives scene regeneration.

Open [the gallery](gallery.html) for matched current-room captures and an
[8.7-second native preview with audio](preview.mp4). The recording begins with
a native pointer drag and live physics, then positions the fixture for real
swept contacts to show the closed eyes, countdown, reopen and final hit.
It shortens the countdown for demonstration; it is not a human timed clear.

| Action | Feedback | Implementation |
|---|---|---|
| Aim / charge | 0.25× speed, stronger stretch, one-pixel tension wobble, room dim/desaturation, brighter arrow, quiet rising rubber cue | `slime.gd`, `effects.gd`, `juice_screen.gdshader` |
| Launch | Immediate full speed/color, recoil, bright mint trail, one-pixel camera pull, 130 ms whoosh | `slime.gd`, `arena.gd`, `effects.gd`, `camera.gd` |
| Wall bounce | Modest squash, four small dust pixels, soft thud, one-pixel bump | `slime.gd`, `effects.gd` |
| Eye hit | 40 ms hold, stronger slime squash, eye bulge/squint, pixel burst on the eye, white flash, polygon ring, pop/thwack, two-pixel shake | `arena.gd`, `clock.gd`, `eye.gd`, `effects.gd` |
| Closed eye | Pupil disappears immediately, eyelid snaps shut, socket darkens, tiny settling bounce | `eye.gd` |
| Countdown | First-hit punch; red size/color pulse and quiet double beat in final five seconds | `hud.gd`, `effects.gd` |
| All eyes reopen | Bass hit and room pulse; closed eyes twitch in the final 200 ms, then all snap open at zero and pupils immediately lock onto the slime | `arena.gd`, `eye.gd`, `effects.gd`, `hud.gd` |
| Win | 120 ms final hold, larger ring/burst and three-pixel impulse; sound cuts after impact, effects resolve, panel reveals at 520 ms with FINALLY. / PEACE AND QUIET. and total clear time | `arena.gd`, `clock.gd`, `effects.gd`, `hud.gd` |

The deadline remains 35 real seconds, including aiming and hit-stop and
excluding pause/focus suspension. Reopen anticipation happens before expiry;
it adds no invulnerability delay or additional time. Camera feedback uses
small offsets with the fixed whole-room framing and zoom. The collider,
launch speeds, hit rules, bounce retention and damping remain unchanged.
Eye hits receive their own reaction rather than an additional wall thud/squash.

Four original synthesized WAVs are under `stop_staring/audio/juice/`, with
their reproducible generator at `tools/build_juice_audio.py`. All four are
44.1 kHz 16-bit mono and have zero clipped samples. Existing supplied sounds
remain in use. No music file was bundled; the quiet win beat currently cuts
the gameplay effects. Final volume balance and play feel need a play-through
by ear; numerical levels and scripted captures do not establish that.

## Captures

The arena was revised separately during this pass from fourteen eyes at
448 × 384 to sixteen at 448 × 336. The main `before_*` captures therefore
render the original feedback scripts on an isolated copy of the **current**
room. The main `after_*` captures use that same current room, a 1280 × 800
native window, the Compatibility renderer and integer 2× scaling. Earlier
captures of the fourteen-eye room are retained under `original_room/`.

Short-lived hit/final-hit screenshots hold only the fixture's visual clock
to ensure the impact is visible despite screenshot/render timing. The burst
capture advances the feedback by 90 ms before holding it. Normal gameplay
uses the production real clock; the video does not hold screenshot poses.

## Validation

All checks passed on the integrated sixteen-eye room:

| Suite | Mode | Checks |
|---|---|---|
| `regression.gd` | Headless | 2,361 |
| Previous global-cycle fixture (removed) | Headless | 1,040 |
| `retro_ui.gd` | Headless | 47 |
| `home_screen.gd` | Headless | 39 |
| `juice.gd` | Headless | 107 |
| `juice.gd` | Native window | 118 |

The feedback fixture covers native pointer routing, immediate launch speed,
unscaled collision, differentiated real wall/eye sweeps, countdown punch and
heartbeat, non-scoring anticipation, simultaneous pupil lock-on, movement
preservation across expiry, pause/audio suspension, final-hit hold, delayed
clear, silence, and repeated retry/scene teardown with no stale effects.
The native preview reached a final clear with zero remaining eyes. Godot
import/parsing and the native shader render succeeded; `git diff --check`
passed. Browser, touch-device performance and human difficulty were not
validated by this pass.

Run from the repository root with the installed Godot runtime:

```bash
GODOT_BIN='/Users/avi/Library/Application Support/Godot/app_userdata/Godots/versions/Godot_v4_8-dev6_macos_universal/Godot.app/Contents/MacOS/Godot'
"$GODOT_BIN" --headless --path stop_staring --script res://experiments/pixel_pivot/tests/juice.gd
"$GODOT_BIN" --path stop_staring --script res://experiments/pixel_pivot/tests/juice.gd
"$GODOT_BIN" --path stop_staring --script res://experiments/pixel_pivot/tests/record_juice.gd --write-movie /private/tmp/stop-staring-juice.avi --fixed-fps 60
```
