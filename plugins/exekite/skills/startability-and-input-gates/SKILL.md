---
name: startability-and-input-gates
description: "For Exekite-hosted Godot games only. Title gates, menus, and pause/resume handlers. Use when writing or debugging the specific handler that starts, pauses, or resumes play — keycode and click-only gates strand the playability probe; covers the probe-reachable ui_accept form and clean scene handoff."
---

# Getting past the title screen

Exposed by a real birth (Race-C): the title gate read `event.keycode`, so
synthetic input could never start the game and **every playability probe was
blind** — they all reported on a title screen they could not leave. Detection
today: none — this agent has no raw-input lint. The playtest tier presses
`ui_accept` and, when a gate does not answer, its findings (no player, no
movement) are advisory warnings under `EXEKITE_PLAYTEST_STRICT=warn`, so a
stranded probe reports on a menu rather than failing the turn.

This is also the single highest-leverage rule in the platform contract: the
probes press `ui_accept`. A gate that does not answer to it makes every oracle
downstream vacuous.

## The rule

```gdscript
# WRONG — unreachable by the probe, and wrong on non-US layouts
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        _start()
```

```gdscript
# RIGHT — the probe supplies both action state and parsed action events.
# This polling form handles the action state; an event handler also works.
func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("ui_accept"):
        _start()
```

An event-handler gate (`if event.is_action_pressed("ui_accept")` in `_input`)
works too. The probe delivers its press BOTH ways — an `InputEventAction`
through `Input.parse_input_event` and the polled state through
`Input.action_press` — so a handler and a poll are each sufficient on their own.

This paragraph used to say an event gate was "invisible to the probe". It was
true when the probe called `action_press` alone: measured against real Godot
4.6.1, that gives `is_action_pressed` = true and `_input` = 0 calls, so an
event-only title never advanced and the run reported a game that would not
start. The probe sends both forms now, and re-sends until a player exists.

`ui_accept` is bound to **Space, Enter and the keypad Enter** by the
harness-written `project.godot` — you cannot add actions, so use the ones that
exist.

## Why `keycode` specifically fails

- `keycode` is the layout-mapped symbol. On AZERTY or Dvorak it is not the key
  under the player's finger; `physical_keycode` is. Actions handle this for you.
- The probe synthesizes ACTION presses, not scancodes. A keycode comparison
  never matches, so an automated run sits on the title forever and every later
  measurement — movement, camera, world — reports on a menu.

## Never gate on a mouse click alone

A click-only title is unreachable by the probe as well. If you want a clickable
button, keep the action as a parallel path:

```gdscript
func _ready() -> void:
    $StartButton.pressed.connect(_start)

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("ui_accept"):
        _start()                 # the probe's path, and the keyboard player's
```

## Make the transition actually happen

Two ways a correct gate still fails to start the game:

```gdscript
func _start() -> void:
    if _started:                 # the poll and a button press can both fire
        return
    _started = true
    get_tree().change_scene_to_file("res://scenes/Game.tscn")
```

- **No re-entry guard.** The poll, a button, and any extra `_input` path can
  each call `_start`, and two `change_scene_to_file` calls in one frame is
  undefined behaviour.
- **The same press leaking into gameplay.** `set_input_as_handled()` only
  consumes the EVENT path; it does not clear polled action state. A handoff
  within the same input frame can still see `is_action_just_pressed` as true.
  If title/resume and gameplay share an action, wait for its release before
  arming gameplay, or use a separate gameplay action. Reset this latch when
  entering or resuming gameplay:

```gdscript
var _accept_armed := false

func _gameplay_accept() -> bool:
    if not _accept_armed:
        _accept_armed = not Input.is_action_pressed("ui_accept")
        return false
    return Input.is_action_just_pressed("ui_accept")
```

When an overlay takes over, move keyboard focus from covered or disabled HUD
controls to an available overlay action. A focused HUD button can still consume
`ui_accept` behind the overlay: Retry must not also toggle a previously focused
mute button. Use one guarded transition owner for button and polling paths so
they cannot both start or restart the run. Arm shared gameplay actions only
after release, including after retry and resume.

## Keep gameplay frozen while menus stay active

Process modes inherit down the tree. An `ALWAYS` main node also keeps every
`INHERIT` player, enemy, hazard and game timer active while the tree is paused.
Keep the menu/resume handler separate, or explicitly make each gameplay branch
`PAUSABLE`. In this example, every gameplay node belongs under `Gameplay`;
title/pause UI belongs outside it and calls `_start_or_resume()` / `_pause()`:

```gdscript
# Main.gd — Gameplay contains all live gameplay, including its timers.
extends Node

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    $Gameplay.process_mode = Node.PROCESS_MODE_PAUSABLE
    get_tree().paused = true # Pre-spawned gameplay waits behind the title.

func _start_or_resume() -> void:
    get_tree().paused = false

func _pause() -> void:
    get_tree().paused = true
```

Hiding a title or disabling only the player's input does not freeze enemies,
hazards or timers. If the title does not pause the tree, defer gameplay creation
until Start or disable the entire gameplay branch until then. Signals and
direct method calls still run on paused nodes; guard gameplay-changing callbacks
that can be reached from active UI. See Godot's [process-mode semantics](https://docs.godotengine.org/en/4.6/tutorials/scripting/pausing_games.html).

## Verify it without a human

```gdscript
# In the title scene, temporarily:
func _ready() -> void:
    if not InputMap.has_action("ui_accept"):
        push_error("ui_accept is not bound — the probe can never start this game")
```

Then run the playtest gate and observe the title-to-play transition: the title
must accept input, gameplay must start, and the starting press must not also
trigger a gameplay action. Also hold movement on the title and while paused:
player, enemies, hazards and game timers must stay fixed while menu/resume input
still works. Resume must restore gameplay. A bound action alone does not prove
the handoff or the freeze.
