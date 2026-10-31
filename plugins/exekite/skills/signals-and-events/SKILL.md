---
name: signals-and-events
description: "For Exekite-hosted Godot games only. Godot 4 signal mechanics — callable-form connect, bind, one-shot, deferred — and the signal-up/call-down rule. Use when a connection misfires or targets a node spawned later, when several unrelated systems need one event without a global bus, or when state must survive a scene change."
---

# Signals and events

Signals are how Godot decouples the thing that did something from the thing that reacts. Used well, they keep code testable and free of references that don't need to exist.

## Declaring and emitting

```gdscript
# In any node script:
signal coin_collected(amount: int)
signal player_died

func collect(value: int) -> void:
    coin_collected.emit(value)        # 4.x: signal_name.emit(args)

func _on_hit_zero_hp() -> void:
    player_died.emit()                # no-arg signal — same syntax
```

Typed signal arguments are recommended; they document intent and surface bad emits.

## Connecting (callable form)

The Godot 4 connect API takes a `Callable`, not a string:

```gdscript
# RIGHT (4.x)
button.pressed.connect(_on_button_pressed)
coin.coin_collected.connect(_on_coin_collected)

# WRONG (3.x style, doesn't compile in 4)
# button.connect("pressed", self, "_on_button_pressed")
```

Disconnecting:
```gdscript
button.pressed.disconnect(_on_button_pressed)
```

Bind extra arguments at connect time:
```gdscript
# Pass `slot` as a final arg every time the signal fires:
inventory_slot.clicked.connect(_on_slot_clicked.bind(slot))
```

One-shot connection (auto-disconnects after firing once):
```gdscript
tween.finished.connect(_after_tween, CONNECT_ONE_SHOT)
```

Deferred (runs at idle, not synchronously inside the emit):
```gdscript
sig.connect(_handler, CONNECT_DEFERRED)
```

## Connections declared in the scene file

A `.tscn` can declare connections as text — this is what editor-made connections serialize to:

```
[connection signal="pressed" from="UI/StartButton" to="." method="_on_start_pressed"]
```

`from`/`to` are node paths relative to the scene root (`.` is the root); the target method must exist in the target's script or the scene fails to load. Use `[connection]` stanzas for static, scene-internal wiring; use script `connect()` for anything that depends on runtime state (spawned children, cross-scene wiring).

## Signal-up, call-down — the discipline

**Signal-up**: a child node never reaches into its parent and calls a method. The child emits; the parent listens.

```gdscript
# Coin (child of level)
signal collected(amount: int)
func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        collected.emit(1)

# Level (parent)
func _ready() -> void:
    for c in $Coins.get_children():
        c.collected.connect(_on_coin_collected)

func _on_coin_collected(amount: int) -> void:
    score += amount  # the root game script owns cross-scene state (no GameState autoload in freeform games)
```

**Call-down**: a parent reaching into a known child via a typed reference is fine.

```gdscript
@onready var hud: HUD = $HUD
func _on_player_died() -> void:
    hud.show_game_over()
```

The asymmetry: the child doesn't need to know who owns it; the parent does know what's beneath it.

## When direct calls are fine

Signals aren't always right. Direct calls beat signals when:

- The dependency is one-way and obvious (call the root game script's `die()` from the player (passed-down reference)). In freeform games the ROOT GAME SCRIPT owns shared state (there is no GameState autoload); don't fan out via a signal just to pretend it doesn't.
- There's exactly one consumer and there always will be (HUD listening to player health — sure, signal works, but a direct call is also fine).

## Fan-out across unrelated systems (no autoload exists)

There is **no `EventBus`, no `GameState`, no shell** in an authored game. The
harness writes `project.godot` with the entire `[autoload]` section stripped, and
you may not write `addons/`, so every global singleton name you might have seen
elsewhere is an undeclared identifier here — a parse error the gate catches.

When several unrelated systems need the same event, put the bus on your ROOT
game script and let listeners find it by group. One node, no globals:

```gdscript
# Main.gd — the root of scenes/Main.tscn
extends Node2D

signal game_event(name: StringName, payload: Variant)

func _enter_tree() -> void:
    add_to_group("game_root")

func post(name: StringName, payload: Variant = null) -> void:
    game_event.emit(name, payload)
```

```gdscript
# Any node, however deep, without a reference passed down to it
func _ready() -> void:
    var root := get_tree().get_first_node_in_group("game_root")
    if root != null:
        root.game_event.connect(_on_game_event)

func _on_game_event(name: StringName, payload: Variant) -> void:
    match name:
        &"player_died": ...
        &"coin_picked": var amount: int = payload.get("amount", 1)
```

Register the root group in `_enter_tree`, before its children's `_ready`
handlers look it up. Registering in the root's `_ready` is too late: children
run `_ready` first and silently miss the connection.

`get_first_node_in_group` returns `null` when nothing is in the group, so the
guard above is not optional — a scene opened on its own for testing has no root.

**Prefer a passed-down reference when you have one.** The group lookup is for
nodes that are spawned deep and cannot be handed anything. A direct typed
reference is faster to read and impossible to get wrong.

## Disconnecting on tree exit

A method-callable connection is severed automatically when either endpoint is
freed — a listener that dies with its scene needs no manual disconnect.
Disconnect explicitly only when (a) the listener leaves the tree but stays
ALIVE (reparented or pooled — it keeps receiving events), or (b) the connection
is a lambda, which has no bound object and is never auto-cleaned:

```gdscript
func _exit_tree() -> void:
    var root := get_tree().get_first_node_in_group("game_root")
    if root != null and root.game_event.is_connected(_on_game_event):
        root.game_event.disconnect(_on_game_event)
```

Connections from a node to its own children, or to nodes that share its
lifetime, don't need this — they are all freed together.

## Signals across a scene change

A signal emitted on a node that is about to be freed is gone the moment the
scene unloads. With no autoload to outlive the scene, carry the state instead of
the event: keep it on the root game script and change scenes through it, or pass
it into the next scene after `change_scene_to_file` via a value the new scene
reads on `_ready`.

## Initialize state after connecting

Signals carry changes; they do not replay the current value for a new listener.
Children run `_ready()` before their parent, so a health signal emitted there is
already over when the parent's `_ready()` connects it. Render the initial state
explicitly after wiring the listener:

```gdscript
# In the parent that owns Player and HUD:
func _ready() -> void:
    $Player.health_changed.connect($HUD.update_health)
    $HUD.update_health($Player.health, $Player.max_health)
```

Use the same pattern for score, cooldown and inventory. Verify the HUD before the
first pickup or hit; a correct update handler can coexist with an empty initial HUD.
For state that survives scene reloads, read its owner again when rebuilding the UI.
For example, initialize a mute toggle from
`AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))`; a new scene's
`false` default does not unmute the global audio bus.

## Anti-patterns

- The Godot 3 string-based `connect("signal", target, "method")` form. Doesn't compile in 4. Always use the callable form.
- Reaching for a global singleton — `EventBus`, `GameState`, `AudioManager` and the rest are STRIPPED from `project.godot`. Any of them used as a global is an undeclared identifier at parse time.
- Forgetting `.connect()` after declaring a signal. The signal is a no-op until something connects.
- Connecting in `_ready()` to a child that doesn't exist yet (e.g. spawned dynamically later in `_ready`). Move the connect to right after the `add_child` call.
- Untyped args on your OWN local signals. `signal hit(damage)` is legal but `signal hit(damage: int)` documents intent and catches bad emits.
- Expecting a signal to survive a scene change. The emitter is freed with its scene; carry the STATE on the root game script instead of trying to carry the event.
