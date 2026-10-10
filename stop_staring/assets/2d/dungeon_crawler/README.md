# Dungeon Crawler 2D assets

Original sheets from the supplied **v1.1 dungeon crawler 16X16 pixel pack**
by **o_lobster**. The pack's original credits are retained in `credits.txt`.
Both PNGs are byte-for-byte copies of the supplied files.

Open `res://scenes/2d/dungeon_tiles_preview.tscn` and press **F6** to preview
the tiles and animation strips. `Room/Floor`, `Room/Walls`, and `Room/Props`
are editable TileMapLayer nodes sharing the external TileSet resource.
The playable experiment is `res://experiments/pixel_pivot/pixel_pivot.tscn`.

## TileSet

Assign `dungeon_tileset.tres` to a TileMapLayer and set the node's
**Texture > Filter** to **Nearest** (or inherit it from a nearest-filtered
parent). This filtering is configured on the preview nodes. Use integer
pixel positions and integer display scales to keep the pixels even.

The square grid and atlas regions are **16 × 16**, with zero margins and
zero separation. Empty regions are excluded. Source IDs are stable:

| ID | Sheet | Dimensions | Paintable tiles |
|---|---|---|---|
| 0 | `full_tilemap.png` | 144 × 128 | 52 |
| 1 | `full_spritesheet.png` | 448 × 144 | 119 |
| 2 | `../eyes/eye_tile_source.tres` | 32 × 32 display canvas | 5 scene tiles |

Source 2 adds the replacement eye sheet alongside the two dungeon atlases:
center, blink, closed, empty socket and hurt. See the eye folder's README.
The shared resource has 171 atlas tiles plus five scene tiles.

The wide table and doorway floor occupy 2 × 1 atlas regions. Doors and
explosions occupy 2 × 2 regions. Their texture origins align the image's
top-left with the painted cell; leave adjacent cells free when placing
these larger tiles. `atlas_catalog.json` records each tile's source ID,
zero-based atlas coordinates, dimensions, name, and collision rectangle.
The same names and categories are exposed as TileSet custom data.

Environment walls have rectangular collision polygons following their
visible bounds on **2D physics layer 1**. Floors, props, sprites, and
decorative arches have no collision. Arch passage geometry and interactive
door collision should be authored for interactive doors. The experiment
disables tile collision and uses merged wall bodies plus circular barrel
bumpers. Tiles are
ready for manual painting; terrain connection rules are not configured.

Texture imports use lossless compression, no mipmaps, no resizing, no alpha
border modification, and disabled automatic 3D compression detection.

## SpriteFrames

Assign `dungeon_sprites.tres` to an AnimatedSprite2D with nearest filtering.
It contains `fly`, `bomb`, `goblin_idle`, `goblin_run`, `slime_idle`,
`slime_run`, `knight_idle`, `knight_run`, `chest_idle`, `chest_open`,
`torch`, `spikes`, `enemy_death`, `slash`, `explosion`, `door_open`, and
`hit`. All frame textures reference the bundled full sprite sheet.

Most frames are 16 × 16. `explosion` and `door_open` are 32 × 32;
`hit` uses the three 8 × 8 effects at pixel positions (176, 40), (184, 40),
and (192, 40). The door sequence uses the ten opening frames present in
the sheet, then its fully open image. Death, slash, explosion, door opening,
and hit are one-shot animations. Speeds are initial tunable defaults:
8 fps for characters/props and 12 fps for effects.

## Rebuild

After importing the PNGs, from the repository root:

```bash
godot --headless --path stop_staring --script ../tools/build_dungeon_2d.gd
```

This rebuilds both `.tres` resources and the preview scene from the bundled
sheets and catalog. Rebuilding replaces edits to those generated files.
