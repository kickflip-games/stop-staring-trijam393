# Wall eye assets

`eyes_sheet_v2.png` is a byte-for-byte copy of the latest user-supplied
replacement. Its 1448 × 1086 canvas contains four columns and three rows
with transparent padding. It is not a uniform 16 × 16 tile atlas.

`eye_sprites.tres` provides twelve static poses and a blink animation. Each
AtlasTexture uses a 300 × 304 crop starting at:

```text
x = 80 + column * 332
y = 84 + row * 304
```

| Row | Column 0 | Column 1 | Column 2 | Column 3 |
|---|---|---|---|---|
| 0 | look_center | look_left | look_right | look_up |
| 1 | look_down | look_up_left | look_up_right | look_down_left |
| 2 | look_down_right | closed | empty_socket | hurt |

Use nearest filtering and a common Sprite scale of `(32/300, 32/304)` for
the intended 32 × 32 display size. Keep the original PNG at its source
resolution. Imports use lossless compression, no mipmaps, no resizing,
no alpha-border modification, and no automatic 3D compression.

The shared `../dungeon_crawler/dungeon_tileset.tres` includes
`eye_tile_source.tres` as **source ID 2**. It supplies five scene tiles:

| Scene tile ID | State |
|---|---|
| 0 | look_center |
| 1 | blink |
| 2 | closed |
| 3 | empty_socket |
| 4 | hurt |

These are decorative AnimatedSprite2D scenes without collision. They use a
32 × 32 canvas on the 16-pixel grid; leave adjacent cells free. The first
two appear in `res://scenes/2d/dungeon_tiles_preview.tscn`.

`empty_socket.tres` is the replacement sheet's row 2, column 2 crop. The
playable experiment uses it underneath a native-resolution eyeball and an
independent tracking pupil in `res://experiments/pixel_pivot/wall_eye.tscn`.
Use that gameplay scene for tracking, closing and reopening, rather than the
decorative scene tiles. Its CLOSED visual reuses the existing row 2, column 1
eyelid crop after the hit squash; no new artwork is added. The face stays
upright on all wall sides.

The configured poses and playable scene use the replacement sheet. No license
was supplied for the eyes; the file is recorded as user-provided artwork in
the third-party notes.

Rebuild from the repository root after PNG import:

```bash
godot --headless --path stop_staring --script ../tools/build_eye_assets.gd
godot --headless --path stop_staring --script ../tools/build_dungeon_2d.gd
```

These commands replace generated eye resources/scenes, the shared TileSet,
and the art preview.
