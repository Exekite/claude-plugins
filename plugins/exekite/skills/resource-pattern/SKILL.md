---
name: resource-pattern
description: "For Exekite-hosted Godot games only. Typed Resource + .tres pattern for entity tunables — the two-file schema/values shape, @export_range/@export_group syntax, load() caching and duplicate(true) traps. Use when writing or restructuring a stats Resource or .tres file; skip for entities with one or two inline knobs."
---

# Resource pattern (.tres tunables)

The Exekite shape: per-entity tunables live in **typed `Resource` subclasses**, instantiated as `.tres` files. The script defines the schema; the `.tres` carries the values.

Why: values in a `.tres` are DATA — they diff cleanly, and many entities can share one resource. A magic number in a script is neither.

## Two-file shape

For an entity with many tunables (player has 10), make a Resource subclass:

`entities/player/player_stats.gd`:
```gdscript
class_name PlayerStats
extends Resource
##
## Player tunables. Edit values in the inspector (or any .tres instance);
## the player controller reads them every physics tick.

@export_group("Movement")
@export_range(50.0, 400.0, 5.0)    var speed: float = 130.0
@export_range(500.0, 3000.0, 50.0) var acceleration: float = 1500.0
@export_range(200.0, 3000.0, 50.0) var friction: float = 1200.0

@export_group("Jump")
@export_range(-600.0, -100.0, 10.0) var jump_velocity: float = -300.0
@export_range(0.0, 1.0, 0.05)       var jump_cutoff: float = 0.4
@export_range(0.0, 0.3, 0.01)       var coyote_time: float = 0.10

@export_group("Death")
@export var fall_death_y: float = 600.0
```

The matching `.tres` (just values; the schema is in the script):

`entities/player/stats.tres`:
```
[gd_resource type="Resource" script_class="PlayerStats" load_steps=2 format=3]

[ext_resource type="Script" path="res://entities/player/player_stats.gd" id="1_stats"]

[resource]
script = ExtResource("1_stats")
speed = 130.0
acceleration = 1500.0
jump_velocity = -300.0
jump_cutoff = 0.4
coyote_time = 0.1
fall_death_y = 600.0
```

The entity script slots the resource:

```gdscript
extends CharacterBody2D
@export var stats: PlayerStats        # appears in the Inspector as a slot

func _physics_process(delta: float) -> void:
    velocity.x = move_toward(velocity.x, stats.speed * dir, stats.acceleration * delta)
```

In the entity's `.tscn`, set the `stats` property to point at `entities/player/stats.tres`.

## Single-file shape (for 1–2 knobs)

Don't make a Resource for two values. Inline `@export` on the entity script:

```gdscript
extends Area2D
@export_group("Bob")
@export_range(0.0, 8.0, 0.5) var bob_amplitude: float = 2.0
@export_range(0.2, 2.5, 0.1) var bob_period: float = 1.2
```

Each coin instance can override these in its scene Inspector. No `.tres` needed.

## When to use which

| Tunable count | Pattern |
|---|---|
| 1–2, used by one entity | `@export` on the entity script |
| 3+, used by one entity | Resource subclass + one `.tres` |
| Same shape used by multiple entity classes | Resource subclass + multiple `.tres` (e.g. `goblin_stats.tres`, `boss_stats.tres`) |

Reuse case: if you want a "fast" and a "heavy" player, save two `PlayerStats` resources (`fast.tres`, `heavy.tres`) and let the level pick which one to load.

**Platform note — manifest tunables never live in a `.tres`.** Player-facing tunables (the birth manifest's `tunables`) are applied by rewriting top-level `const`/typed-var declarations in `.gd` files. A value set in a `.tres` SHADOWS the script default, so a manifest tunable whose runtime value comes from a `.tres` ships a slider that does nothing. Keep manifest-exposed knobs as top-level declarations in a `.gd` file; use the Resource pattern for everything else.

## `@export_group`, `@export_range`, `@export_subgroup`

Group related tunables in the Inspector — makes the editing UX dramatically better:

```gdscript
@export_group("Movement")
@export_range(50.0, 400.0, 5.0) var speed: float = 130.0

@export_group("Jump")
@export_range(-600.0, -100.0, 10.0) var jump_velocity: float = -300.0
```

`@export_range(min, max, step, ...)` exports a range. The optional 3rd argument sets the increment; omitting it still exports a range. Integer steps default to 1; float steps use the Inspector's default-float-step setting. Supply an explicit step when increments matter. Optional flags after step: `"or_greater"`, `"or_less"`, `"hide_slider"`.

`@export_enum("Easy", "Normal", "Hard")` for picklists.

`@export_color_no_alpha` for opaque colors. `@export_node_path("CharacterBody2D")` for typed node paths.

## Loading and saving Resources at runtime

```gdscript
# Load a .tres (cached by Godot — same path returns the same instance)
var preset := load("res://entities/player/stats.tres") as PlayerStats

# Save a Resource (e.g. for save files)
ResourceSaver.save(stats, "user://my_player.tres")

# Make a runtime copy (so edits don't mutate the shared instance)
var local := stats.duplicate(true) as PlayerStats
```

`load(path)` returns a cached instance — multiple call sites get the same object. If two entities share a stats resource and one mutates it, both see the change. Use `duplicate(true)` for a deep copy when that matters.

## Anti-patterns

- A `Resource` for one float. That's just `@export var x: float`.
- Hardcoded constants in the entity script that should be tunable. `const JUMP := -300` is wrong; `@export var jump := -300.0` is right. A knob exposed via the birth manifest's `tunables` must be declared at COLUMN 0 in a `.gd` file, but it does NOT have to be a `const`: the panel's own matcher (`workspace/tunables.ts` `declPattern`) accepts `const`, `var`, a typed `var`, `@export var` and `@export_range(...) var` alike. This paragraph used to say `const` was mandatory, which pushed authors away from the idiomatic `@export` spelling for the exact knobs the panel exists to expose.
- Mutating the shared `.tres` via `stats.speed = 99` at runtime. That edits the loaded instance and persists across the session — usually a bug. Use `duplicate(true)` or copy values into a local var.
- Resource fields without type hints. Without types, Godot can't validate the `.tres`, and the Inspector shows generic widgets.
