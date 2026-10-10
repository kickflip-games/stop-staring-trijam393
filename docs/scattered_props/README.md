# Scattered crates and extra barrels

The props remain in the current arena, which now also has [matching side-wall lips](../wall_lips/README.md). The image below records the prop placement before those lips were added.

Restored four floor crates and added four floor barrels, bringing the arena to **eight barrels and four crates**. The original four island-top barrels remain. Props use the existing art and bounce colliders.

The new props sit near the outer walls, clear of all eye mounts and the central cross. Crates are against the left/right boundaries, so they leave no tiny pocket behind them; they leave 52 px between their inner face and the nearest island edge. The floor barrels sit near the top/bottom corners. Placements mirror across both axes and remain fixed on retry.

![Current arena](arena.png)

The four island rectangles, sixteen eye mounts, slime spawn, movement, camera, HUD, per-eye timers and presentation are unchanged. `layout.json` is the source; `pixel_arena.tscn` is regenerated with the existing arena-only builder. Current prop descriptions and geometry-dependent regression checks were updated.

The existing regression passed **2460 headless assertions** and **2464 native assertions**, with no failures: real collider connectivity, mirrored prop collisions, unobstructed central cross, all sixteen swept eye contacts, bank shots, input, win and retry. Native rendering was visually inspected. Existing teardown warnings remain: two ObjectDB instances in native mode; the headless fixture sometimes also retains its scene resources at exit.
