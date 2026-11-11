---
name: hud-and-overlay-layout
description: "For Exekite-hosted Godot games only. Anchored HUD and menu layout, phone readability after viewport scaling, physical control bounds, and touch-first prompt text. Use for title, pause, win/lose and retry UI as well as in-game counters. Includes a working responsive CanvasLayer example."
---

# HUD and overlay layout

Valid node positions do not establish readable UI. Check geometry and input in
Godot, then inspect the exported game for visual contrast and phone usability.

## The ordering trap

`set_anchors_preset()` REWRITES `offset_left/top/right/bottom`. Set an anchor
preset after positioning and your position is discarded. And `position` is
PARENT-relative, never anchor-relative — it only mimics anchor-relative
placement while the node is outside the tree (the parent rect reads zero there,
so the offsets absorb the value), which is why build-then-add code appears to
work. On a node already inside a laid-out tree, `position = Vector2(-120, 12)`
means 120px left of the parent's LEFT edge. Use `offset_left` / `offset_top` /
`offset_right` / `offset_bottom` for anchor-relative placement — they are
anchor-relative in and out of the tree.

```gdscript
# WRONG — the preset overwrites everything you just set
label.position = Vector2(20, 20)
label.set_anchors_preset(Control.PRESET_TOP_LEFT)

# RIGHT — anchor first, then offset from that anchor
label.set_anchors_preset(Control.PRESET_TOP_LEFT)
label.offset_left = 20
label.offset_top = 20
```

`set_anchors_preset(preset, true)` — the second argument is `keep_offsets` —
keeps them instead. Use it when you have already positioned the node.

## Anchor to the corner the value belongs to

A HUD that anchors everything top-left drifts off a wide screen. Anchor each
element where it should stay:

```gdscript
func _build_hud() -> CanvasLayer:
    var layer := CanvasLayer.new()          # a CanvasLayer does NOT scroll with the camera
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # or it eats every click
    layer.add_child(root)

    var score := Label.new()
    score.set_anchors_preset(Control.PRESET_TOP_LEFT)
    score.offset_left = 16
    score.offset_top = 12
    root.add_child(score)

    var lives := Label.new()
    lives.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    lives.offset_left = -120                # negative — measured from the RIGHT edge
    lives.offset_top = 12
    root.add_child(lives)
    return layer
```

Anchored to the right, `offset_left` is measured from that edge — so it is
negative. A positive value there puts the label off-screen, which is exactly
the class this skill exists for.

## Put the HUD on a CanvasLayer, always

A `Control` parented into the gameplay tree moves with the camera. In a
scrolling game it leaves the screen the moment the player walks right. A
`CanvasLayer` is in screen space and does not move.

## Verifying without a viewport

You cannot see it. You can still assert it, and the assertion is cheap:

```gdscript
func _ready() -> void:
    await get_tree().process_frame          # sizes are not final until one frame has passed
    var vp := get_viewport_rect()
    for c in _hud_controls:
        var r := c.get_global_rect()
        assert(vp.encloses(r), "HUD element %s is outside the viewport: %s vs %s" % [c.name, r, vp])
```

A failed `assert` emits a `SCRIPT ERROR:` line, which the playtest tier
surfaces as a runtime-error warning — the off-screen element becomes a visible
engine error. `push_error` works too, and this paragraph used to say it did
not: measured on Godot 4.6.1, `push_error("x")` prints

```
ERROR: x
   at: push_error (core/variant/variant_utility.cpp:1024)
```

— `ERROR:` at column 0, not `USER ERROR:`, and `^ERROR:` is one of the three
patterns the extractor matches (`gate/checks/boot.ts` `GENERIC_ERROR_RE`). The
old advice steered authors away from the one call that reaches the gate.
Remove the check, or keep it behind a constant, once the layout is settled.

Container-managed rectangles may not be final in `_ready()`. Await deferred
layout before asserting them; explicitly sized controls can already have a
nonzero rectangle, so checking only for nonzero size is insufficient.

## Keep text and buttons usable after phone scaling

A 1280×720 game fitted into a 390px-wide phone has only about 390×219px of
visible game content. A 16-unit font becomes 4.88px and a 48-unit Start button
becomes 14.63px high. Anchoring alone cannot fix this.

Read `responsive_overlay.md` in **this skill's directory** for a complete,
native-tested example. Copy and adapt it into the game's own scripts: its title,
counts and action names are examples. Never reference the skill's `/opt/...`
path from exported game code, and do not register it as a platform autoload.

The example puts one manually sized Control directly under a CanvasLayer. Give
that root TOP_LEFT anchors, not FULL_RECT, and update its size and scale together
on `get_viewport().size_changed`. Its child anchors and containers then lay out
against the smaller usable UI rectangle:

```gdscript
var stretch := get_viewport().get_screen_transform().get_scale().abs()
var pixel_ratio := maxf(1.0, DisplayServer.screen_get_scale())
var css_scale := minf(stretch.x, stretch.y) / pixel_ratio
var ui_scale := maxf(1.0, 1.0 / maxf(0.001, css_scale))
ui_root.scale = Vector2.ONE * ui_scale
ui_root.size = get_viewport().get_visible_rect().size / ui_scale
```

Use at least 16-unit text and 44×44-unit button hit areas under this root.
Reflow the content to its new size; enlarging a desktop layout alone makes it
overflow. On a short phone viewport, use a short title, one goal sentence and
Start; compact the HUD to counters plus Pause/Mute. The example pause menu puts
Resume above a row containing Mute and Retry, so all three fit even in 180px of
height. Put desktop keyboard instructions in a separate help view or omit them
on touch devices. Apply this layout to **every** title, pause, win, lose and retry
screen, including the longest counter values and Unmute label.

Menu buttons retain keyboard focus and a visible focus style. Release a hidden
screen's focus before rebuilding it, restore the matching button when only its
label changes, and focus the active primary action on a new menu. HUD buttons
may use FOCUS_NONE so Space does not activate a previously clicked Mute button.
Coalesce menu rebuilds with `call_deferred()`: removing the emitting button
during its `pressed` callback can interrupt Godot's ongoing GUI input dispatch.
The game controller still needs one owner for each menu activation and a
release-to-arm latch before gameplay consumes that same Start/Retry key; this
UI example does not implement a gameplay ability latch.

After container layout settles, validate **physical** bounds for each screen.
The example's `physical_rect(control)` applies the viewport and canvas transforms
and divides by display density. Compare those rectangles with the similarly
transformed viewport rectangle, require every button's width and height to be
at least 44px, and check the font's transformed size is at least 16px. Check
portrait, landscape and resizing while a menu is already open. Native headless
density is a model; verify the exported browser canvas at its actual CSS size
and device pixel ratio, including trusted taps and keyboard menu navigation.

See Godot's [viewport transform chain](https://docs.godotengine.org/en/4.6/tutorials/2d/2d_transforms.html)
and [display scale](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-screen-get-scale).

## Touch players see buttons, not keys

On a touchscreen (`DisplayServer.is_touchscreen_available()`), the platform's
touch overlay draws a joystick and the buttons the game registered with
`configure_actions`. Every instruction the game shows must then name what the
player can touch: the joystick ("Drag to walk") and each button by its label
("Hold CAST to cast", "Tap SHOO"). Never name a key ("Hold SPACE", "E",
"P pause", "A/D"). Keep both texts and pick one at runtime:

```gdscript
func _hint(keys: String, touch: String) -> String:
	return touch if DisplayServer.is_touchscreen_available() else keys

hint_label.text = _hint("Hold SPACE to cast", "Hold CAST to cast")
```

Give each touch button one short word (CAST, SHOO, PAUSE). The overlay fits a
longer label by shrinking or wrapping it, which costs legibility.

## Readable controls and populated state

Changing a Button's `font_color` does not change its background. Dark text on the
default dark button is nearly invisible even though its rect is valid. Choose the
foreground and StyleBox background together, including hover, pressed, disabled
and focus states; a bright primary button needs a real bright background style.
Inspect the rendered title and pause screens, not just their node positions.

Check the first playable frame before taking damage or collecting anything:
health, score and cooldown must already show their current values. Wire signals
and then render state explicitly (see `signals-and-events`). Verify changed values
still fit: adding the initially missing hearts must not push the objective off-screen.
A gate pass does not establish visual contrast or initial HUD completeness.

Draw critical HUD icons such as hearts with geometry, or use a font whose glyph
coverage you verified in the exported game. Unverified Unicode hearts and other
symbols can render as empty boxes even when the health number is correct.

## The other two ways UI vanishes

- **`modulate.a` left at 0**, or a fade-in tween that never starts. The node is
  present, sized and positioned; nothing draws.
- **A parent with `visible = false`**. Visibility is inherited, so a hidden
  container hides a perfectly placed child. Check the chain, not the node.
