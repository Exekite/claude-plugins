---
name: gdscript-style
description: "For Exekite-hosted Godot games only. GDScript house style — naming, type-hint policy, script section ordering, node-reference forms, signal-up/call-down. Use when a specific convention question arises (naming a signal, ordering sections, choosing $-path vs %unique-name access) or when reviewing GDScript for style drift."
---

# GDScript style

Godot's idioms reward explicit typing and small, focused scripts. This is the house style for Exekite projects.

## Naming

| Thing | Style | Example |
|---|---|---|
| Class names (`class_name X`) | `PascalCase` | `PlayerStats`, `EnemyBehavior` |
| Variables, functions, parameters | `snake_case` | `jump_velocity`, `apply_damage(amount)` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_LIVES`, `LEVEL_1_PATH` |
| Signals | past-tense `snake_case` | `coins_changed`, `player_died`, `body_entered` |
| Private fields/methods (convention only) | `_underscore_prefix` | `_coyote_t`, `_apply_gravity()` |
| Node paths in scenes | `PascalCase` | `Sprite2D`, `JumpSound`, `CollisionShape2D` |

## Type hints — always

```gdscript
# WRONG
var speed = 100
func move(amount):
    position.x += amount

# RIGHT
var speed: float = 100.0
func move(amount: float) -> void:
    position.x += amount
```

Why: explicit types catch errors at parse time (Godot's static checker is real), drive autocomplete, and double as documentation. The cost is one colon per declaration; pay it.

For locals, `:=` lets the type infer:

```gdscript
var dir := Input.get_axis("ui_left", "ui_right")  # inferred float — only the
# pre-bound actions exist (ui_left/ui_right/ui_up/ui_down, ui_accept,
# ui_cancel, pause, fire, interact)
var t := create_tween()                                # inferred Tween
```

### `:=` only works when the right-hand side has a known type

This is the single most common way an authored game fails to parse. When the
expression yields `Variant`, `:=` is a **parse error** — it does not quietly fall
back to an untyped variable, and the script (plus every script that depends on
it) fails to load:

```
Parse Error: Cannot infer the type of "f" variable because the value doesn't have a set type.
```

Three sources of `Variant` produce almost all of these:

```gdscript
# 1. Indexing an UNTYPED array or dictionary
var notes = [523.25, 659.25]      # untyped Array
var f := notes[0]                 # WRONG — element type is Variant
var f: float = notes[0]           # RIGHT (or type the array: var notes: Array[float] = [...])

# 2. A member of a loosely-typed node
var game := get_parent()          # inferred Node — `player` is not a Node member
var target := game.player.position    # WRONG — unknown member is Variant
var target: Vector2 = game.player.position  # RIGHT

# 3. Anything returning Variant
var v := ProjectSettings.get_setting("x")   # WRONG
var v: int = ProjectSettings.get_setting("x")  # RIGHT
```

Rule of thumb: **type your array and dictionary literals** (`var melody: Array[float] = [...]`),
and the moment a value comes out of a container, a `get_parent()`, or an untyped
API, write the type explicitly instead of `:=`.

## Script structure — top-down ordering

The convention:

1. `class_name` (if any)
2. `extends`
3. Top-level docstring (`##` lines)
4. Signals
5. Enums
6. Constants
7. `@export` vars (Inspector-visible tunables)
8. `@onready` vars
9. Internal state vars (`_underscore_prefixed`)
10. `_ready`, `_enter_tree`, `_exit_tree`
11. `_process`, `_physics_process`, `_input`, `_unhandled_input`
12. Public methods
13. Private methods (`_underscore_prefixed`)
14. Signal handlers (`_on_<source>_<signal>`)

You don't have to be religious about it, but be consistent within a file.

## Node references — two good ways, no bad ways

```gdscript
# (a) @onready + relative path — for stable, scene-internal nodes
@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_bar: ProgressBar = $UI/HPBar

# (b) @onready + % unique name — for nodes whose path may move within a scene
#     (requires `unique_name_in_owner = true` on that node's [node] entry in
#     the .tscn — without it, %Name resolves to null at runtime)
@onready var camera: Camera2D = %Camera
```

AssetRegistry-guarded art in a Python-born game is the `generated-media-wiring` skill's domain — do not invent `/root/` lookups; freeform games have no autoloads.

Avoid `get_node("Some/Long/Brittle/Path")` with string concatenation. If a path needs to be dynamic, use `find_child(name, true, false)`, but interrogate whether the design needs to be that loose first.

## Signal-up, call-down

The community rule: a child node never reaches into a parent or sibling and calls a method on them. Instead, the child **emits** a signal; the parent **listens** and routes.

```gdscript
# Coin (Area2D, child of level)
signal coin_collected(amount: int)
func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        coin_collected.emit(1)

# Level (parent — owns the score, since freeform games keep cross-scene
# state on the root game script, not on an autoload)
func _ready() -> void:
    for coin in $Coins.get_children():
        coin.coin_collected.connect(_on_coin_collected)

func _on_coin_collected(amount: int) -> void:
    score += amount
    hud.set_score(score)
```

When that's overkill (a direct parent→child call), call down directly — the rule is signals UP, calls DOWN.

## Returns: explicit `-> void` over implicit

```gdscript
# Acceptable but discouraged
func _ready():
    pass

# Idiomatic
func _ready() -> void:
    pass
```

Functions that return values: type the return.

```gdscript
func clamp_health(amount: int) -> int:
    return clampi(amount, 0, max_health)
```

## Comments

Lead with `##` (double-hash) for class/method documentation that the editor surfaces in tooltips. Use `#` for inline.

```gdscript
## Player tunables. Edit values in the inspector (or any .tres instance);
## the player controller reads them every physics tick.
class_name PlayerStats
extends Resource
```

Don't comment things that the type and name already say. `# decreases hp` above `func take_damage(amount: int) -> void:` is dead weight.

## Anti-patterns

- Untyped function parameters or return types in shipped code.
- `:=` on a value whose type Godot cannot infer — an untyped array/dictionary element, an unknown member on a `get_parent()` result, or any `Variant`-returning call. It is a parse error, not a fallback.
- `get_node()` with a long path string instead of `$RelativePath` or `%UniqueName`.
- Side effects at the top of the file (lines outside `func`s) — initialization belongs in `_ready` or `_init`.
- `_process(delta)` doing physics-affecting work — that belongs in `_physics_process(delta)`.
- 200-line scripts with no class boundary. If you can name a slice "this is what the X system does", it's probably a separate script.
