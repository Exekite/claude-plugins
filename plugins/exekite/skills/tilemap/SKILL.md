---
name: tilemap
description: "For Exekite-hosted Godot games only. Godot 4 TileMapLayer + runtime-built TileSet craft. Use only when the level is an actual tile grid — painting cells in code, per-tile collision, terrains/autotiles, custom tile data, spawn-marker layers. Not needed for 3D levels or non-grid 2D scenes."
---

# TileMap / TileMapLayer

Godot 4.3+ replaced the monolithic `TileMap` node with `TileMapLayer` — one node per layer, each layer painting a different facet (ground, decorations, hazards). The TileSet resource (shared across layers) holds the actual tile defs.

## Layout

```
Level (Node2D)
├── Background (TileMapLayer)   # tile_set assigned in _ready() from _build_tileset()
├── Ground (TileMapLayer)       # same TileSet instance — the layer with collision
├── Decoration (TileMapLayer)   # same TileSet instance
└── Hazards (TileMapLayer)      # its own TileSet (different tiles/physics)
```

Each `TileMapLayer` has its own `tile_map_data` (the painted layout) and shares the `tile_set` resource. Collision is per-layer-per-physics-layer; you typically enable collision on the Ground layer only.

## Creating a TileSet

A `TileSet` resource (`*.tres`) catalogs:
- Source images (sprite atlases, scene tiles, terrains)
- Per-tile metadata (collision shape, navigation, custom data)
- Physics layers (which group of bodies tiles in this set collide with)
- Terrain sets (auto-tile rules)

There is no editor and no source image — art here is generated in code. Build
the whole `TileSet` at runtime from a texture you draw yourself:

```gdscript
func _build_tileset(cell: int) -> TileSet:
    # 1. Draw an atlas: one row of cells, each a flat colour. Anything you can
    #    compute — noise, gradients, borders — works the same way.
    var img := Image.create(cell * 3, cell, false, Image.FORMAT_RGBA8)
    var colours := [Color(0.25, 0.5, 0.25), Color(0.4, 0.3, 0.2), Color(0.2, 0.2, 0.3)]
    for i in colours.size():
        img.fill_rect(Rect2i(i * cell, 0, cell, cell), colours[i])

    var src := TileSetAtlasSource.new()
    src.texture = ImageTexture.create_from_image(img)
    src.texture_region_size = Vector2i(cell, cell)
    for i in colours.size():
        src.create_tile(Vector2i(i, 0))

    var ts := TileSet.new()
    ts.tile_size = Vector2i(cell, cell)
    ts.add_source(src, 0)
    return ts
```

Give solid tiles collision on the same source, in code:

```gdscript
    ts.add_physics_layer(0)
    var data := src.get_tile_data(Vector2i(0, 0), 0)
    var half := cell / 2.0
    data.add_collision_polygon(0)
    data.set_collision_polygon_points(0, 0, PackedVector2Array([
        Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
    ]))
```

Build the TileSet once and assign the same instance to every layer in `_ready()` (cache it in a static var or pass it in) — layers share by reference.

## Painting tiles

Programmatically:
```gdscript
@onready var ground: TileMapLayer = $Ground

func _ready() -> void:
    # Paint a 10x1 row of grass (atlas coords (0,0)) at world cells (0..9, 5):
    for x in range(10):
        ground.set_cell(Vector2i(x, 5), 0, Vector2i(0, 0))
    # Erase a cell:
    ground.set_cell(Vector2i(3, 5), -1)
```

`set_cell(coords, source_id, atlas_coords, alternative_tile_id)`. `source_id = -1` means "erase". `source_id` matches the source you added to the TileSet.

## Collision

The Ground layer with a physics layer assigned will register collision shapes per painted tile. The collision shape is part of the tile's metadata in the TileSet — the `add_collision_polygon` code above.

CharacterBody2D bodies with the right collision mask collide naturally — no extra setup beyond layer/mask matching.

## Terrain (autotile / wang tiles)

Terrain sets let you draw "ground" without picking individual corner/edge tiles — Godot picks the right tile based on neighbors.

No inspector here — build the terrain set in code on the same TileSet:

```gdscript
ts.add_terrain_set()
ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
ts.add_terrain(0)
ts.set_terrain_name(0, 0, "Grass")

# Per tile: declare its terrain and which sides/corners match ("grass" bits).
var data := src.get_tile_data(Vector2i(0, 0), 0)
data.terrain_set = 0
data.terrain = 0
data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, 0)  # repeat per covered bit

# Then paint by terrain instead of picking atlas coords per cell:
ground.set_cells_terrain_connect(cells, 0, 0)
```

Godot picks the matching tile based on the peering bitmask.

## Custom data layers (per-tile metadata)

A TileSet can declare custom data layers — typed metadata on each tile. Read at runtime:

```gdscript
# Declare the layer on the TileSet in code, then stamp values onto tiles:
ts.add_custom_data_layer()
ts.set_custom_data_layer_name(0, "damage")
ts.set_custom_data_layer_type(0, TYPE_INT)
src.get_tile_data(Vector2i(2, 0), 0).set_custom_data("damage", 10)

func _on_player_entered_cell(coords: Vector2i) -> void:
    var data := ground.get_cell_tile_data(coords)
    if not data: return
    var dmg := data.get_custom_data("damage") as int
    if dmg > 0:
        player.take_damage(dmg)
```

Useful for "this tile is a checkpoint", "this tile slows the player to 0.5×", etc.

## World-to-cell, cell-to-world

```gdscript
var cell := ground.local_to_map(ground.to_local(player.global_position))
var world_pos := ground.to_global(ground.map_to_local(Vector2i(3, 5)))
```

`local_to_map` is the inverse of `map_to_local`. They use the layer's local coordinate system, not global.

## Spawning entities from tilemap data

A pattern: paint markers in a "Spawns" TileMapLayer; on level start, iterate the cells and instance entities at their positions, then clear the markers.

```gdscript
@onready var spawns: TileMapLayer = $Spawns
const COIN := preload("res://scenes/coin.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")

func _ready() -> void:
    for cell in spawns.get_used_cells():
        var atlas := spawns.get_cell_atlas_coords(cell)
        var pos := spawns.to_global(spawns.map_to_local(cell))
        if atlas == Vector2i(0, 0):
            spawn(COIN, pos)
        elif atlas == Vector2i(1, 0):
            spawn(ENEMY, pos)
    spawns.clear()

func spawn(scene: PackedScene, pos: Vector2) -> void:
    var inst := scene.instantiate()
    inst.position = to_local(pos)  # this parent owns the instance's local transform
    add_child(inst)
```

## Performance notes

- `TileMapLayer` is fast — millions of cells render fine. Don't over-optimize.
- Distinct TileMapLayers with the same TileSet share GPU resources; cheap to add.
- For huge worlds, use chunking (multiple TileMapLayers, each covering one region; load/unload by player position).

## Anti-patterns

- One `TileMapLayer` painting both ground (with collision) and decoration (no collision). Split into two layers — collision is per-layer.
- Painting collision shapes on every tile when only some are solid. Solid tiles get a shape; "grass" tiles get nothing.
- Hardcoding tile coordinates (`set_cell(Vector2i(3, 5), 0, Vector2i(2, 1))`) instead of using terrains for terrain. Painting via terrain is faster and adapts to neighbor changes.
- Querying `get_cell_tile_data` every frame for every player tile when a signal-on-enter would do.
- Storing per-instance state on tiles (e.g. "this coin tile is collected"). Tiles are static; spawn entities for stateful things.
