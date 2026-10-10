# Asset attribution and provenance

The canonical public credit is [`stop_staring/CREDITS.md`](../stop_staring/CREDITS.md).
Keep it updated when assets are added, replaced or removed.

## Dungeon Crawler 16 × 16 Pixel Pack v1.1

- Creator: **o_lobster**.
- Publisher/source: [Simple Dungeon Crawler 16 × 16 Pixel Pack](https://o-lobster.itch.io/simple-dungeon-crawler-16x16-pixel-pack).
- Publisher license: **Creative Commons Zero v1.0 Universal**, verified on the publisher page on 2026-10-10.
- Supplied local folder: `/Users/avi/Desktop/v1.1 dungeon crawler 16X16 pixel pack/`.
- Bundled files: `stop_staring/assets/2d/dungeon_crawler/full_tilemap.png`, `full_spritesheet.png`, and `credits.txt`.

The supplied download's README contains creator and credits information;
no separate license text was found in the local pack. `credits.txt` retains
that original README. Both full sheets are copied unchanged. Atlas crops,
SpriteFrames and TileSet resources reference these originals.

## Wall eye sheets

The user-supplied 1448 × 1086 replacement sheet is retained as
`stop_staring/assets/2d/eyes/eyes_sheet_v2.png` and supplies the configured
static poses, blink and stone/empty socket.

No creator attribution or license was supplied for the eye sheet.
No third-party license is inferred. The prototype's native pixel eyeball
and independent pupil are local SVG components based on the supplied
reference. The source PNG is unchanged.

## Audio

- Action cues: `stop_staring/audio/juice/` contains two original synthesized
  WAVs for launch and eye-impact snap. The fixed-seed
  generator is `tools/build_juice_audio.py`; no external samples are used.

- Wall impacts: **Impact Sounds (1.0)** by **Kenney**, CC0. The original
  license is retained as `stop_staring/audio/wall_hits/License.txt`. The game
  uses the retained `impactSoft_heavy_002.ogg` clip.
- Stretch: `stop_staring/audio/aim/stretch.wav`, converted from the supplied
  `strech.m4a`. Creator, original source and license remain unrecorded.
- Eye pop: `stop_staring/audio/eye/squish_sfx.mp3`. Creator, original source
  and license remain unrecorded.

## Music

Music by **Avi**, created with [BeepBox](https://www.beepbox.co/).

[Original BeepBox composition](https://www.beepbox.co/#9n31s0k0l00e03t2ma7g0fj07r1i0o432T0v1u00f1137qwx10p511d08w2h0E3b6060cT0v1u12f10s4q00d03w2h2E0T1v1u3df0qwx10p511d08AcFbBfQ269cP969bE2bi7iT3v3uf9f0qwx10l511d08SW86bmhkrrzrkrrrE1b6b4h40000000014g000000004h0000000001400000000p1_FHY70IR-EEnFHYu3ws4U1dtd7xAt4zihRQBWq_A1dtd7xBZ1BQ4t17g0FKDbi00).

The supplied WAV is bundled as `stop_staring/audio/music/BeepBox-Song.wav`;
`stop_staring/audio/music/BeepBox-Song.json` retains the editable composition.

## UI

**Fantasy UI Borders** by **Kenney**:
https://kenney-assets.itch.io/fantasy-ui-borders.

The publisher lists CC0 1.0 Universal, checked on 2026-10-10. The current
HUD uses `panel-border-010.png`, `panel-border-007.png` and `divider-002.png`
from `stop_staring/assets/ui/kenney/`. The original `License.txt` is retained
in that folder.

## Font

`stop_staring/assets/ui/fonts/PressStart2P-Regular.ttf` is **Press Start 2P**
by **Cody Boisclair (CodeMan38)** and the Press Start 2P Project Authors.
The original `OFL.txt` records copyright 2012 and the SIL Open Font License,
Version 1.1; `FONTLOG.txt` records additional contributions and provenance.
Both files are retained alongside the font and included in exports.

## Engine and default icon

Godot Engine is MIT licensed: https://godotengine.org/license/.

`stop_staring/icon.svg` contains the default Godot Engine logo. The official
logo license credits **Andrea Calabró**, copyright 2017, under CC BY 4.0
International:
https://github.com/godotengine/godot/blob/master/misc/logo/LICENSE.txt.
The local template icon places the logo on a rounded square background.

## Distribution

`publish.sh` includes `CREDITS.md` and the original bundled attribution files
in the resource pack, and copies `CREDITS.md` next to the exported Web game
and into the ZIP. Local editor tooling is excluded from the staged export.
