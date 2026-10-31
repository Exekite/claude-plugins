---
name: godot-4-syntax-vs-3
description: "For Exekite-hosted Godot games only. Godot 3 → 4 migration cheat sheet. Use when written or encountered GDScript shows a Godot-3 idiom — `KinematicBody2D`, string-based 4-arg `connect()`, `yield(...)`, `OS.get_ticks_msec`, `export var`, or a `Pool*Array`. Covers body renames, connect changes, exports, lifecycle, math/utility relocations."
---

# Godot 3 → 4 syntax migration

Most LLM training data leans Godot 3, so this is the failure mode to defeat first. The tables below give the Godot-4 form for each; `start_check` with the parse profile catches what slips through.

## Physics bodies — the renames you must memorize

| Godot 3 | Godot 4 |
|---|---|
| `KinematicBody2D` / `KinematicBody` | `CharacterBody2D` / `CharacterBody3D` |
| `RigidBody2D` (kinematic mode) | `RigidBody2D` with `freeze = true` and `freeze_mode = FREEZE_MODE_KINEMATIC` |
| `move_and_slide(velocity, Vector2.UP)` | set `velocity` as a property, then call `move_and_slide()` (no args) |
| `is_on_floor()` after `move_and_slide` | identical, but only valid AFTER the call |
| `Transform` (3D) | `Transform3D` |

```gdscript
# WRONG (Godot 3)
extends KinematicBody2D
var velocity := Vector2.ZERO
func _physics_process(delta):
    velocity = move_and_slide(velocity, Vector2.UP)

# RIGHT (Godot 4)
extends CharacterBody2D
func _physics_process(delta: float) -> void:
    velocity.y += 980.0 * delta
    move_and_slide()
```

## Signals — the connect form changed

```gdscript
# WRONG (Godot 3 string-based connect)
button.connect("pressed", self, "_on_button_pressed")

# RIGHT (Godot 4 — pass the Callable directly)
button.pressed.connect(_on_button_pressed)

# disconnect:
button.pressed.disconnect(_on_button_pressed)
```

Signal declaration in the script body:
```gdscript
signal hit(damage: int)        # typed args supported in 4
hit.emit(10)                   # Godot 3 used `emit_signal("hit", 10)`
```

## Exports

```gdscript
# WRONG
export var speed := 100.0
export(int, 1, 10) var difficulty := 1

# RIGHT
@export var speed: float = 100.0
@export_range(1, 10) var difficulty: int = 1
@export_group("Movement")    # groups in the Inspector
@export_range(0.0, 1.0, 0.05) var jump_cutoff: float = 0.4
```

**Give `@export_range` an explicit step when increments matter.**
`@export_range(0.0, 10.0, 0.25)` retains the 0.25 increment in its property
hint. Omitting the step still exports a range: integers default to 1, while
float increments depend on the Inspector's default-float-step setting.
The two-argument form is valid; it does not force float values to integers.

`@onready` is unchanged in spirit; the syntax is the same `@onready var sprite: Sprite2D = $Sprite2D`.

## Lifecycle and types

```gdscript
# WRONG
func _ready():
    pass

# RIGHT — always type the return, even when it's void
func _ready() -> void:
    pass
```

`_process(delta)` and `_physics_process(delta)` both take `delta: float`. The class declarations:

```gdscript
class_name PlayerStats
extends Resource
```

## Function and global utility moves

| Godot 3 | Godot 4 |
|---|---|
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` |
| `OS.get_unix_time()` | `Time.get_unix_time_from_system()` |
| `yield(timer, "timeout")` | `await timer.timeout` (or `await get_tree().create_timer(0.5).timeout`) |
| `Sprite` | `Sprite2D` |
| `AnimatedSprite` | `AnimatedSprite2D` (or 3D) |
| `Tween` (node) | call `create_tween()` per-tween; no Tween node |
| `Reference` | `RefCounted` |
| `PoolByteArray` | `PackedByteArray` (and similar `Pool*Array` → `Packed*Array`) |
| `range(0, 5, 1)` | unchanged |

## `await` everywhere `yield` lived

```gdscript
# WRONG (3): yield(get_tree().create_timer(1.0), "timeout")
# RIGHT (4):
await get_tree().create_timer(1.0).timeout

# Wait for a signal:
await tween.finished
await body_entered           # current node's signal
```

Forgetting `await` is the most common subtle bug — the next line runs immediately, the timer fires later, and behavior splits.

## Tween — node → builder

```gdscript
# Godot 3: had a Tween node; you'd call interpolate_property
# Godot 4: per-call builder, returned by create_tween()
var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
t.tween_property(sprite, "position:y", -10.0, 0.3)
t.tween_property(sprite, "position:y",  0.0, 0.3)
await t.finished
```

For looping tweens, `create_tween().set_loops()`. Don't reuse a tween across calls — make a new one.

## Inputs are unchanged in spirit

`Input.is_action_just_pressed("ui_accept")` still works. `Input.get_axis("ui_left", "ui_right")` returns a float in [-1, 1] and is the idiomatic way to get a horizontal direction. Only the harness's pre-bound actions exist: ui_left/ui_right/ui_up/ui_down (WASD + arrows), ui_accept, ui_cancel, pause, fire (left mouse), interact (E).

## Resources — same idea, simpler typing

```gdscript
# Define a typed Resource
class_name PlayerStats
extends Resource
@export_range(50.0, 400.0, 5.0) var speed: float = 130.0

# Use it from a script
@export var stats: PlayerStats        # slot in the Inspector
```

The `.tres` saves the values; the script provides the schema. Some Exekite games pair `<id>_stats.gd` with a `stats.tres` — match that shape where the game you are editing already uses it.

## Anti-patterns — a checklist before claiming done

- [ ] No `KinematicBody*`, no `Sprite` (2D), no `AnimatedSprite` (2D).
- [ ] All `connect()` calls are the callable form: `signal.connect(method)`.
- [ ] No `yield(...)` — `await` only.
- [ ] No `OS.get_ticks_msec()` — `Time.*`.
- [ ] All `func`s have a return type (or `-> void`).
- [ ] No 4-arg `move_and_slide` — set velocity, call no-arg.
- [ ] All `export` annotations use `@export` form.
