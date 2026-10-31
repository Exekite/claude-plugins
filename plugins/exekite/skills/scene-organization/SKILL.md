---
name: scene-organization
description: "For Exekite-hosted Godot games only. File placement and structure for a multi-scene Godot project — entities/ vs scenes/ vs ui/, scene vs script vs Resource, when to extract a sub-scene, group tagging. Use when restructuring an existing project or when a new file's location is genuinely unclear."
---

# Scene organization

Vanilla Godot. The filesystem is the source of truth. There is no manifest above it.

## Folder layout (canonical)

```
project_root/
├── project.godot                  # HARNESS-WRITTEN. You may not touch it.
├── export_presets.cfg             # harness-written
├── scenes/
│   └── Main.tscn                  # THE ENTRY SCENE. run/main_scene points here.
├── <anything>.gd                  # scripts live wherever you want them
└── <anything>.tres                # typed Resource values, likewise
```

**The hosted authoring path rules are enforced.** `.godot/` and other
platform-managed/private paths are refused. Read the returned turn state
rather than assuming a refusal rolled back the draft. (`.json` and `.md` are
also accepted suffixes.)

Within those rules, group however the game reads best. A conventional shape:

```
scenes/Main.tscn                   # required
entities/<id>/<id>.gd + <id>.tscn  # one folder per entity kind
entities/<id>/stats.tres           # typed values, when there are many
ui/<name>/<name>.gd + <name>.tscn  # HUD, pause menu, dialogs
```

That is the shape the rest of this document assumes. `entities/` and `ui/` are
ordinary directories you create — nothing special about them beyond convention.

When adding something, ask: **is this a thing the world has many of (entity), a place the player visits (scene), or an interface they read (ui)?**

## Scene vs script vs resource — the decision tree

```
Is this thing INSTANTIABLE multiple times in the world?
    ├── Yes → it's an entity. Make a .tscn under entities/<id>/.
    │
    └── No, is it a place/screen the player navigates to?
            ├── Yes → it's a scene. Make a .tscn under scenes/<name>/ or ui/<name>/.
            │
            └── No, is it pure data (numbers, strings, references)?
                    ├── Yes → it's a Resource. Make a class_name X extends Resource
                    │         and a .tres file.
                    │
                    └── No → it's behavior on an existing thing. Edit the
                              relevant script, or extract a child node.
```

## Entity scene shape

A typical entity (`entities/coin/coin.tscn`):

```
Coin (Area2D, script: coin.gd)
├── Sprite2D
├── CollisionShape2D
└── Sound (AudioStreamPlayer)
```

Or for the player (`entities/player/player.tscn`):

```
Player (CharacterBody2D, script: player.gd, groups: ["player"])
├── Sprite2D
├── CollisionShape2D
├── Camera2D
├── JumpSound (AudioStreamPlayer)
├── LandSound (AudioStreamPlayer)
└── HurtSound (AudioStreamPlayer)
```

The root node owns the script. Children are atoms (visual, collision, audio). Nothing fancier than that until you genuinely need it.

## Level/scene shape

A level scene's root is usually a `Node2D` (or `Node` for non-spatial). The level instances entities and arranges them:

```
Level1 (Node2D, script: level_1.gd)
├── Background (TileMapLayer or Parallax2D)
├── Terrain (TileMapLayer)
├── Entities/
│   ├── @Player.tscn             (instanced)
│   ├── @Coin.tscn ×N            (instanced multiple times)
│   └── @Flag.tscn               (instanced)
├── Hazards/
│   └── @Spike.tscn ×N
└── HUD (CanvasLayer + Control nodes)
```

Use **scene instancing**: declare `[ext_resource type="PackedScene" path="res://entities/coin/coin.tscn" id="3_coin"]` at the top of the level `.tscn` (and bump `load_steps`), then instance it with `[node name="Coin" parent="Entities" instance=ExtResource("3_coin")]`. Don't inline-copy an entity's nodes into the level; you lose the link to the source scene.

## When to extract a sub-scene

Extract a scene when the thing repeats. If you're going to need 50 of them, it's a scene. If you're going to need 2, it's also probably a scene (linking is cheaper than duplicating).

Conversely, don't extract a scene that has exactly one instance and isn't reused — that's overhead. Inline it in its parent.

## When to make a Resource

You're making a Resource when:

- You want the values editable in the Inspector and saved as `.tres`.
- The same shape (e.g. enemy stats) will exist with different values.

Skip a Resource when there are 1–2 trivial fields. Inline `@export` on the script.

## Groups

Use Godot groups to tag entities the rest of the game queries:

```gdscript
# In .tscn or via script:
add_to_group("player")
add_to_group("enemy")

# Querying:
for e in get_tree().get_nodes_in_group("enemy"):
    e.queue_free()
```

The platformer's player is in the `"player"` group; coins check `body.is_in_group("player")` instead of casting to a specific class. This keeps coupling loose.

## Anti-patterns

- One giant scene file with everything inline. If it has more than ~20 nodes, look for sub-scenes.
- Entities under `scenes/`. Put entities under `entities/`; reserve `scenes/` for places.
- Naming entities by their class (`CharacterBody2D.tscn`). Name them by what they are: `player.tscn`, `goblin.tscn`.
- Referencing `res://assets/...` anywhere. There are no asset files; visuals and audio are generated in code, and a write into `assets/` is refused.
- Making a Resource for every entity. The player has one because it has 10 tunables; the coin has none because it has 2.
