# Simple board support meshes

These static ArrayMesh resources are built with Godot's SurfaceTool:

- `beveled_block.tres`: unit block with six broad faces, twelve bevels and
  eight clipped corners; 44 triangles. Scaled instances form the board plinth,
  inner lips, outer steps and four corner blocks.
- `eye_stone_collar.tres`: a 24-sided annular mount with a shallow stepped
  bevel; 288 triangles. Its outer radius is 1.02, inner opening 0.76 and depth
  0.26. The existing eye's white face and pupil remain the same size.

No physics shapes or bodies are embedded in either resource. Blender was
not used. The source generator is `tools/build_board_supports.gd` at the
repository root. Run it from that root with your Godot executable:

```bash
godot --headless --path stop_staring --script "$PWD/tools/build_board_supports.gd"
```

The blob's soft contact-shadow SVG is in `art/environment/`. It is a simple
radial gradient on a visual QuadMesh, independent of the sphere collider.
