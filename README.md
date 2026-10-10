# stop-staring-trijam393



Godot 4.8dev6

## Graybox prototype

Open `stop_staring/project.godot` and press F6 on `scenes/main.tscn`, or F5
to run the project. The main scene contains an orthographic view of an 18 × 10
unit arena, four static collision walls, and a mint sphere placeholder.
Gameplay uses XY with Z fixed at zero; the player has no gravity and locked
rotation. Hold the mouse or a finger anywhere, drag back opposite the desired
direction, and release to fling. The arrow shows direction and strength.
Tiny drags cancel; long drags cap at maximum strength. Release replaces the
current velocity, and losing focus cancels an unfinished gesture.

Select `Player` in the main scene to tune maximum drag distance, deadzone,
and minimum/maximum launch speed. Wall ricochets and bank-shot prediction
will follow in issue #4.

