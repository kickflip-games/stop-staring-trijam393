# Aim and impact polish

Aim slows gameplay to 0.25x. Mouse/touch input still projects directly onto the same XY plane; visual anticipation and recovery use unscaled time. Release replaces velocity immediately, with no animation gate. Physics shapes, collision sweeps, launch strength and bounce retention are unchanged.

`TimeEffects` is the only script that writes `Engine.time_scale`. It applies hit-stop > aiming > normal. Hit-stop uses a monotonic microsecond deadline, extends safely on consecutive hits, and resumes the current aim state. Navigation, pause, focus loss and scene teardown restore normal time. A release during an active hit-stop clears aiming, and returns to 1.0 when that short stop expires.

Eye hits strengthen the existing procedural squash, bulge and retract the eye in 0.11 seconds real time, play the existing squish sound with randomized pitch, emit a short radial 3D mesh burst, and kick the camera by a small bounded offset. Aim clears that offset before ray projection. Wall hits retain their existing squash/dust/audio and only add a much smaller camera bump. There is no new asset, shader, mechanic or UI system. The existing clear overlay waits 0.18 seconds to allow the final impact to read.

## Inspector tuning

| Node | Property | Default |
| --- | --- | --- |
| Player | aim_time_scale | 0.25 |
| TimeEffects | hit_stop_duration | 0.05 seconds real time |
| Player/VisualPivot | eye_impact_multiplier | 1.45 |
| Eye | pop_bulge | 1.3 |
| Eye | pop_bulge_duration / pop_retract_duration | 0.035 / 0.075 seconds |
| Eye | pop_pitch_variation | 0.1 (pitch 0.9–1.1) |
| ImpactFeedback | eye_particle_count / particle_lifetime | 14 / 0.24 seconds |
| ImpactFeedback | eye_camera_kick / wall_camera_kick | 0.075 / 0.008 world units |
| ImpactFeedback | camera_duration / max_active_bursts | 0.14 seconds / 6 |

The existing aim stretch, pullback, smoothing, wall squash/expansion/duration and sound volume remain available. Eye squash, burst velocity and camera amplitude scale modestly with normal impact speed and are clamped.

## Files changed for this pass

- `stop_staring/scripts/blob.gd`: aim state informs time controller; clears camera offset before input projection.
- `stop_staring/scripts/blob_visual.gd`: responsive anticipation; stronger speed-aware eye squash.
- `stop_staring/scripts/eye.gd`: one-shot hit notification, punchier reaction and randomized existing sound.
- `stop_staring/scripts/level.gd`: connects confirmed eye hits to feedback.
- `stop_staring/scripts/game.gd`: navigation cleanup and brief final-impact presentation delay.
- `stop_staring/scenes/main.tscn`: wires the two small helper nodes.
- `stop_staring/scripts/time_effects.gd`: centralized real-time arbitration and lifecycle cleanup.
- `stop_staring/scripts/impact_feedback.gd`: radial mesh fragments and bounded camera offsets.
- `stop_staring/tests/impact_polish.gd`: acceptance sequence and rapid-hit/lifecycle checks.
- `docs/impact_polish/`: before, aim, impact, burst and recovered screenshots plus this report.

## Validation

Native graphical and headless acceptance runs passed: moving full speed, hold aim, responsive stretch, release, wall ricochet, re-aim, release, swept eye impact, immediate re-aim and release. A configured 0.05-second hit-stop measured about 0.06 seconds including frame scheduling. Checks cover pause, focus loss, overlapping impact deadlines, camera cleanup, particle cleanup, unchanged collision transforms and actual restart through the scene transition.

Existing launch_controls, ricochets, blob_visual, wall_eye, menu_levels and scene_transitions suites all passed. `git diff --check` passed. This is automated native runtime validation; subjective sound/feel still benefits from a human playtest.
