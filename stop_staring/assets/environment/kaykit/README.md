# KayKit toy-board environment

Selected from the locally downloaded **KayKit Dungeon Pack 1.1 FREE**, by
Kay Lousberg. See `License.txt` for the supplied CC0 license.

The source pack includes glTF + binary buffers, OBJ + MTL, FBX, and Unity FBX.
The project uses glTF for native Godot scene import, with the original shared
palette texture. No conversion or mesh collision generation is required.

Current models, copied unchanged from `Assets/gltf/`:

- `floor_foundation_allsides.gltf` and `floor_foundation_allsides.bin`
- `wall.gltf` and `wall.bin`
- `dungeon_texture.png`

The original `floor_tile_large.gltf` and `.bin` remain from the first visual
experiment, but the polished layer uses the quieter foundation tops.
Also retained the pack's root `License.txt`. Godot generates `.import`
sidecars. `wall_corner_small`, `wall_pillar` and `column` were inspected but
not copied. No props or additional pack models are used.

`scripts/kaykit_arena_visuals.gd` instances 12 floor slabs and 16 straight wall
segments. It rotates KayKit's XZ ground plane into the game's XY board plane.
The playable dimensions come from the original box colliders; the extra wall
width extends outward. Imported materials are duplicated and tinted at runtime.
Slabs vary by at most 3%, with narrow seams. Source models and texture stay intact.

Simple static meshes in `../support/` provide a beveled plinth, stepped border,
four corner blocks, and the eye collars. No Blender conversion was needed.

Disable `Arena/KayKitVisuals.enabled`, hide the node, or remove it to restore
the prototype floor/wall meshes, directional-light settings and environment.
The separate blob material and eye collar polish remain. No physics objects
belong to this art layer.
