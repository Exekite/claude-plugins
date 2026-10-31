---
name: debugging-godot
description: "For Exekite-hosted Godot games only. Instrumenting a headless Godot run — print/push_error, reading the gate's quoted engine output, and the silent-failure classes (signal with no listener, layer/mask 0, node never added to the tree, _ready order, dangling await). Use when code parses and boots but behaves wrongly."
---

# Debugging Godot 4

Most Godot bugs aren't compile errors — they're silent ones. A signal that isn't connected. A collision mask of 0. A scene that loaded but wasn't added to the tree. The code looks right; nothing happens.

## Print and inspect

```gdscript
print("Player jumped, velocity = ", velocity)
print_debug("inventory state:", inventory)        # adds an "At:" line after it
push_warning("falling back to defaults")
push_error("save file corrupt — resetting")       # also flagged in editor
```

`print_debug` is the most useful: it's the same as `print` but APPENDS the
source location on its own indented line. Measured on 4.6.1,
`print_debug("x")` prints

```
x
   At: res://probe.gd:3:_init()
```

— after the message, not before it, and with the function name. So a grep for
your marker shows the message and not the location; grep with `-A 1`. It is
debug-build only (`OS.is_debug_build()`), which every gate and rig run is. Use
it liberally during a hunt; remove afterward.

## Where output actually goes

There is no editor here, so there are no docks, no breakpoints and no live
scene tree. The game runs headless and everything you learn comes from two
places:

- **stdout/stderr from the run.** `print()` and `push_error()` land there, and
  the gate's boot and playtest tiers capture them. An engine error looks like
  `SCRIPT ERROR: Invalid call. Nonexistent function 'x' in base 'Nil'.`
- **The gate's own verdict**, which names the tier that failed and quotes the
  engine text. That is the same output, already read for you.

So instrument, run, and read — there is nothing to step through.

## Common silent failures and how to catch them

### Signal not connected

```gdscript
signal coin_collected(amount: int)

func collect() -> void:
    coin_collected.emit(1)   # fires into the void if no listener
```

Catch at runtime:
```gdscript
print("connections: ", coin_collected.get_connections())
```

An empty array at the moment of emit is the bug — connect before the first emit, or emit deferred.

### Layer/mask = 0 (or wrong)

A body in layer 1 with mask 0 doesn't detect any collisions. An Area2D with no mask doesn't see any bodies.

Quick sanity check:
```gdscript
print(name, " layer=", collision_layer, " mask=", collision_mask)
```

### Node never added to tree

A scene `instantiate()`-ed but never `add_child`-ed never `_ready`s. Symptoms: signals you connected don't fire, `_process` never runs, nothing visible. Always pair `instantiate` with `add_child`.

```gdscript
var inst := scene.instantiate()
add_child(inst)               # ← THIS
inst.global_position = pos
```

### `_ready` order

`_ready` runs from leaves up. A parent's `_ready` runs after all its children's `_ready`s. If a parent connects to a child's signal in `_ready`, the child has already `_ready`-ed; if the child emits in `_ready`, the parent missed it.

Solution: have the parent connect from `_enter_tree` (which runs top-down, before any child's `_ready`), or have the child `call_deferred` its emit so the parent has wired up first.

### `await` consumed by the wrong thing

```gdscript
# BUG: waiting for the WRONG node's signal
await get_node("OtherTimer").timeout      # never fires; we wanted OUR timer

# FIX: store the timer reference
var t := Timer.new()
add_child(t)
t.start(1.0)
await t.timeout
```

Print the signal source before `await` if confused: `print("awaiting ", t, " timeout")`.

### Scene structure mismatch

`@onready var sprite: Sprite2D = $Sprite2D` fails silently (returns null) if the child node was renamed. Symptoms: null reference errors on the next line that uses `sprite`.

A renamed child makes `$Sprite2D` log `Node not found: "Sprite2D"` at runtime and leaves the var null — the boot tier's stderr shows it. When an @onready var is null, diff the node names in the `.tscn` against the paths in the script.

### Visible but no input

A plain `Control`'s default `mouse_filter` is `MOUSE_FILTER_STOP` — a full-rect panel left at the default silently consumes every click over it. `MOUSE_FILTER_PASS` lets clicks through; `MOUSE_FILTER_IGNORE` makes it transparent to input entirely. A button that "doesn't respond to clicks" usually has a sibling Control at the STOP default covering it.

Print `get_global_rect()` on the button and each sibling Control to find the one covering it.

### Pause behavior

For pause `process_mode` rules, read [startability-and-input-gates](../startability-and-input-gates/SKILL.md). One extra mode: `PROCESS_MODE_WHEN_PAUSED` runs a node ONLY while paused (pause-screen-only animations).

## Debug visualizations

There is no editor toggle here — when a shape seems misaligned or zero-area ("I set up the collision but it doesn't trigger"), print the CollisionShape2D's `shape.size`/`global_position`, or draw its outline with the `_draw()` overlay below.

For shipping debug overlays, draw to a `_draw()` callback on a CanvasItem:

```gdscript
extends Node2D

func _ready() -> void:
    set_process(true)

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var player := get_tree().get_first_node_in_group("player")
    if not player: return
    draw_circle(player.global_position - global_position, 4, Color.RED)
    draw_string(ThemeDB.fallback_font, player.global_position - global_position + Vector2(8, -8),
        "v=%s" % player.velocity, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
```

Disable in production via a feature tag or a simple `const DEBUG := false`.

## When something is slow

No profiler either. Measure in code, over a window rather than a frame:

```gdscript
var _t := 0.0
var _frames := 0

func _process(delta: float) -> void:
    _t += delta
    _frames += 1
    if _t >= 1.0:
        print("fps ~", _frames, "  nodes: ", get_tree().get_node_count())
        _t = 0.0
        _frames = 0
```

The usual culprits, in the order they are usually true: work done per-frame
that could be done once (building a texture, allocating an array), a `for` loop
over every node each frame, and `sin()`/`cos()` tables recomputed instead of
cached. `get_node()` in `_process` is cheap but not free — bind it with
`@onready` once.

## When the game will not boot at all

The recovery procedure that used to be here began "open `project.godot` in a
text editor and delete the `[autoload]` line". You may not write that file —
the operation refuses forbidden writes. Read the returned turn state rather
than assuming a refusal rolled back the draft. The version that works here:

1. Read the gate's error. It names the tier and quotes the engine.
2. Run the parse check over the files you touched. A cascade usually has ONE
   real cause: the file that declares the `class_name` everything else refers to.
3. If a scene will not load, read the `.tscn` as text — an `[ext_resource]`
   pointing at a path you renamed is visible on inspection.
4. Comment out the suspect node's script line in the `.tscn` and re-run, rather
   than deleting the node. A missing node breaks every `@onready` that referred
   to it and buries the original error under new ones.

## Anti-patterns in debugging

- `print` scattered without reading the result. The gate already quotes engine output — instrument the one suspect narrowly, run, and read what came back before adding more prints.
- Removing all `print_debug`s before testing the next case. Leave the diagnostic ones until the bug's confirmed dead.
- "It works in editor". Web export and headless Godot have different behavior — the shipped game runs single-threaded WebGL2 (`gl_compatibility`) in a browser tab; test assumptions against that target.
- Adding an "if debug:" branch that's `true` by default and ships to production. Use `OS.is_debug_build()` or a `const DEBUG`.
