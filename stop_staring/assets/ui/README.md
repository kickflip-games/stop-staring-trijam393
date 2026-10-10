# Retro UI assets

The HUD and pause/clear panels use a dark blue inset, warm brass borders,
ivory pixel text and mint progress highlights matching the supplied dungeon
reference. `res://ui/retro_theme.tres` is the shared native Godot theme;
`res://ui/retro_hud.tscn` is the editable UI scene.

## Fantasy UI Borders

Creator: Kenney. Source: the user-supplied
`/Users/avi/Desktop/kenney_fantasy-ui-borders/` download, version 1.0.
The supplied vector sheet has companion PNG exports. These three native
48-pixel PNG exports are copied unchanged under `kenney/`:

- `PNG/Default/Border/panel-border-010.png`: header and keyboard focus.
- `PNG/Default/Border/panel-border-007.png`: pause and clear panel.
- `PNG/Default/Divider/divider-002.png`: panel divider.

The original `License.txt` is included: CC0. Tinting happens in Godot.
Nine-patch margins preserve the corner designs; texture filtering is nearest.

## Press Start 2P

Creator: The Press Start 2P Project Authors / Cody Boisclair.
The unmodified font was downloaded from the
[Google Fonts source repository](https://github.com/google/fonts/tree/main/ofl/pressstart2p)
on 2026-10-11. `fonts/OFL.txt` and `fonts/FONTLOG.txt` retain the license
and font history. License: SIL Open Font License 1.1.

Font SHA-256: `034c77f1f05ec89421e4a63f0e3a4ca1ecf852cc6d2bf611f126f275728e017d`.

Use 8-pixel body text and 16-pixel headings. The import disables antialiasing,
hinting and subpixel positioning, with oversampling fixed to one. The game
scales the complete viewport by an integer; there are no screen-space scanlines
or blur shaders.

The small eye icon reuses the game's existing local eyeball and pupil SVGs.
