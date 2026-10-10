# stop-staring-trijam393

A 2D slingshot arcade game made with Godot 4.8.dev6. The project is in
`stop_staring/`.

## Play

Open `stop_staring/project.godot` and press **F5**. The pixel-art home screen
opens first; select **Play** to enter the 28 × 21 tile dungeon view with
four chunky quadrant islands and sixteen tracking wall eyes. Pull back and release to launch; re-aim while
moving, bank off walls, and keep every eye closed at the same time. Each eye reopens after 60 seconds. **R** retries; **P** or **Escape**
pauses. **How to Play** explains the launch and independent eye timers; **Home** in the
pause or clear panel returns to the title screen. The game starts fullscreen; **F11** toggles
windowed mode. Menu and gameplay fill the available screen while preserving their aspect ratios.
See [fullscreen captures and checks](docs/fullscreen/README.md).

The editable home scene is `stop_staring/ui/home_screen.tscn`. It reuses the
game's dungeon tiles, animated slime and torches, wall-eye layers and pixel
font, scaled proportionally with the rest of the view. See
[home screen captures](docs/home_screen/README.md).

[Independent eye timers](docs/independent_eyes/README.md) describes the current
60-second closure rule, simultaneous win condition, HUD and validation.

[Eye gaze cones](docs/gaze_cones/README.md) shows the red pupil-tracking
light fans, solid-wall occlusion and closed-eye transitions.

See [gameplay documentation](stop_staring/experiments/pixel_pivot/README.md)
for controls, scene rebuilding, atlas coordinates, tuning and validation.
[2D captures](docs/pixel_pivot/README.md) retain the room screenshots,
and earlier movement recording.

[Quadrant arena](docs/quadrant_arena/README.md) records the current symmetric
four-island map, broad lanes, all sixteen eyes and matched before/after captures.

[Retro UI preview](docs/retro_ui/README.md) shows the pixel font, brass HUD,
pause and clear panels at 1×, 2× and 3×. The editable UI scene is
`stop_staring/ui/retro_hud.tscn` with its shared `retro_theme.tres`.

## Attribution

[Credits](stop_staring/CREDITS.md) records music by Avi, made with BeepBox, o_lobster's dungeon art, Kenney's Fantasy UI
Borders and Impact Sounds, the Press Start 2P font, plus outstanding
provenance for supplied assets. The BeepBox song loops from the main menu through
gameplay and follows the gameplay slowdown. The menu silently renders the room
and plays its effect cues before enabling Play to warm graphics and audio.
[Asset provenance](docs/third_party_assets.md) records
local paths and usage.

## Checks

[Action feedback preview](docs/juice/gallery.html) shows the charge, launch,
eye-hit and final-hit/win polish, with a historical native video and matched captures. [Implementation notes](docs/juice/README.md)
record tuning and validation. Run the feedback fixture with
`res://experiments/pixel_pivot/tests/juice.gd`.

```bash
godot --headless --path stop_staring --script res://experiments/pixel_pivot/tests/regression.gd
```

Set the executable path explicitly if Godot is not on your PATH; the
installed runtime path is documented in the gameplay README.

## 2D tilesheet setup

The supplied dungeon sheets are saved and configured in
`stop_staring/assets/2d/dungeon_crawler/`. Open
`stop_staring/scenes/2d/dungeon_tiles_preview.tscn` and press **F6** for the
editable room and animation preview. The shared TileSet provides a 16 × 16
grid with wall collisions; the SpriteFrames resource provides 17 animations.
The replacement eye sheet is configured under `stop_staring/assets/2d/eyes/`
and adds five scene tiles as source 2 in the same TileSet. See the asset
folders' READMEs for atlas IDs and usage, and `docs/third_party_assets.md`
for provenance.

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

Outputs: `build/web/index.html`, `build/web/CREDITS.md` and
`build/stop-staring-web.zip`. Credits and bundled attribution files are
included in the export; local editor tooling is excluded.
Import/export logs and an isolated project copy are also under `build/`.

Set `GODOT_BIN` (or `GODOT`), `BUTLER`, or `ITCH_TARGET` to override defaults.
The script prefers the installed Godot 4.8.dev6 runtime, then `godot`/`godot4`
on your PATH. It can be invoked from any working directory.

On the itch.io edit page, set the game kind to HTML and mark the `html5` upload
as **This file will be played in the browser**. The build does not require
SharedArrayBuffer support.
