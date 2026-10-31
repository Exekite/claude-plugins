---
name: generated-media-wiring
description: "For Exekite-hosted Godot games only. Typed ArtBank accessors and legacy AssetRegistry guard shapes. Use when wiring existing generated textures, SpriteFrames, model scenes or audio, or repairing code inside their guards. Preserve the procedural fallback and match the accessor to the resource kind. Also for moving a static 3D model or a code-built 3D character (holder bob, lean and turn; jointed limbs)."
---

# Wiring guarded art

Use this craft when integrating existing media or a model created through the
Exekite connection. The typed `create_3d_model`, `open_3d_model`, and
`save_3d_model` tools can author and register a retained model, source and
preview. Paid image, sound, and animation generation, when the user asks for
it, uses `estimate_cost` and then the matching paid asset tool; a code edit
does not request those providers. Procedural geometry and synthesized audio
remain valid assets.

Keep distinct procedural variants in named visual builder functions and sounds
in literal named slots such as `_sfx["gem"] = _wav(...)`. Simple enum `match`
branches calling distinct parameterless visual builders are discovered as
separate assets. For other supported factories, put
`# @asset-site entity gem Gem pickup` or
`# @asset-site audio gem_chime Gem chime` immediately above a top-level function
with no required parameters; an audio label may also precede a named sound
assignment. Entity factories need visible 3D geometry, audio factories an
AudioStream return type. These comments describe source sites, not registry
entries. Do not mint or edit platform `# @asset` identities, the manifest, or
`scripts/art_bank.gd`. A focused Assets edit changes only its selected function
or assignment; preserve sibling variants, dispatchers and shared helpers.

## Current projects: ArtBank

Read `scripts/art_bank.gd` to see the project's asset IDs. It is a generated
`class_name` with static methods, not an autoload. Do not edit it or add an
autoload. Match the method to the resource:

| Resource | Accessor | Consumer |
|---|---|---|
| Texture2D | `ArtBank.tex("id")` | Sprite2D/Sprite3D, texture drawing or material |
| SpriteFrames | `ArtBank.frames("id")` | AnimatedSprite2D/AnimatedSprite3D |
| AudioStream | `ArtBank.audio("id")` | Existing audio player or sound factory |
| PackedScene (GLB model) | `ArtBank.scene("id")` | Instantiate as Node3D under the existing visual holder |

Each returns null for a missing resource or a different resource kind. Keep
the existing procedural visual or synthesized audio as the null fallback.
If the project has no bank, keep its procedural implementation.

For characters, use the actual frame dimensions to fit the existing body and
feet. Check `has_animation()` before playing a clip; drive available clips
from movement and action states. Do not replace collision shapes or gameplay
with the new visual. A SpriteFrames is not a Texture2D, and asking `tex()` for
it silently falls back instead of showing the paid art.

For audio, preserve event timing, volume, bus and looping behavior. The
replacement is an AudioStream; widen a procedural factory's AudioStreamWAV
return annotation if necessary, retaining the synthesis as the fallback.

For a 3D model, check the PackedScene for null and the instantiated root for
Node3D. Keep the procedural model if either check fails. Fit the imported
mesh bounds to the existing visual footprint and ground height at runtime,
so a regenerated model with different dimensions still fits. Preserve the
physics body, collider, movement, camera and references used by visual effects.
A CharacterBody3D may be a car: do not assume a humanoid rig or animation
clips. Play animations only if the delivered model actually contains them.
Do not install a legacy addon or autoload to use `ArtBank.scene()`.

## Static models and jointed characters

Generated and Blender 3D models are static: no skeleton and no animation
clips. Move the visual holder from the existing movement state instead: a
small bob while moving, a slight forward lean, and a turn toward the travel
direction when the body itself does not turn. Never move the body or the
collider for this.

A character built in code that should walk needs joints. Give each limb its
own pivot Node3D placed AT the joint (hip, shoulder, neck) with the limb mesh
hanging below it, and swing the pivots from speed. A mesh centred on its
pivot spins around its middle instead. A model built from separate parts
works too: once the instance is in the scene tree, find each limb by name,
add a pivot Node3D at its joint, and `reparent()` the limb under it. It keeps
its place; done before the instance is in the tree, it jumps to the pivot.
This script is the visual holder under the body; call
`animate(velocity, delta)` from the body's physics step. For a static model,
keep only the bob, lean and turn.

```gdscript
extends Node3D
# Visual holder for a code-built character. The body keeps movement and collision.
# Torso and head are plain MeshInstance3D children; only limbs need pivots.

const SWING := 0.7  # limb swing at full speed, radians
const BOB := 0.06  # metres
const SIDES := [1.0, -1.0, -1.0, 1.0]  # left leg, right leg, left arm, right arm
@export var max_speed := 6.0
var _phase := 0.0
var _rest_y := 0.0
var _limbs: Array[Node3D] = []


func _ready() -> void:
	_rest_y = position.y
	_limbs.append(_limb(Vector3(-0.15, 0.9, 0.0), Vector3(0.14, 0.9, 0.14)))  # hips
	_limbs.append(_limb(Vector3(0.15, 0.9, 0.0), Vector3(0.14, 0.9, 0.14)))
	_limbs.append(_limb(Vector3(-0.4, 1.6, 0.0), Vector3(0.12, 0.7, 0.12)))  # shoulders
	_limbs.append(_limb(Vector3(0.4, 1.6, 0.0), Vector3(0.12, 0.7, 0.12)))


# The pivot sits at the joint and the mesh hangs below it.
func _limb(joint: Vector3, size: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position.y = -size.y * 0.5
	pivot.add_child(mesh)
	add_child(pivot)
	return pivot


# Call from the body's _physics_process. The visual faces -Z.
func animate(velocity: Vector3, delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var amount := clampf(speed / max_speed, 0.0, 1.0)
	_phase = fmod(_phase + delta * speed * 2.5, TAU)
	var blend := minf(1.0, 12.0 * delta)
	for i in _limbs.size():
		var target: float = sin(_phase) * SWING * amount * SIDES[i]
		_limbs[i].rotation.x = lerpf(_limbs[i].rotation.x, target, blend)
	position.y = _rest_y + absf(sin(_phase)) * BOB * amount
	rotation.x = lerpf(rotation.x, -0.12 * amount, blend)
	# Skip the turn when the body already rotates to face its movement.
	if speed > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), blend)
```

## Legacy projects: AssetRegistry guard shapes

Play only clips the resource actually contains
(`sprite_frames.has_animation()` / `AnimationPlayer.has_animation()`): a clip
that does not exist leaves the character frozen on whatever was playing
before, so if a movement state of yours has no matching clip (a glide, a
dash, a swim), play the closest clip that DOES exist instead of naming the
state. Keep each guarded id as a GUARDED swap site with the procedural visual
as the fallback. Use EXACTLY this shape for a still TEXTURE (the
AssetRegistry autoload is not guaranteed to exist, so never reference it
bare; and `get_texture` never returns null — it returns a magenta
placeholder, so for a texture `is_placeholder` is the correct "do I have real
art?" test; shapes 3 and 4 below need a DIFFERENT test, and using this one
there is what ships a magenta box):

    var _reg = get_node_or_null("/root/AssetRegistry")
    var _has_art: bool = _reg != null and not _reg.is_placeholder("hero_sprite")
    if _has_art:
        sprite.texture = _reg.get_texture("hero_sprite")
    else:
        pass  # keep drawing your procedural visual

The guard must read correctly in all three states: the autoload absent, the
id resolving to a placeholder (your procedural visual keeps rendering), and
real art present.

THE GUARD DEPENDS ON THE KIND. There are four shapes and they are NOT
interchangeable — using the wrong one ships a broken game with a green gate.

1. A TEXTURE on a Sprite2D/Sprite3D/material — the shape above
   (`is_placeholder` + `get_texture`).

2. IMMEDIATE-MODE 2D. If you draw with `draw_rect`/`draw_circle`/
   `draw_polygon` inside `_draw()`, there is no node to assign a texture to.
   Draw the texture instead of the shape, keeping the shape as the else:

       func _draw() -> void:
           var _reg = get_node_or_null("/root/AssetRegistry")
           if _reg != null and not _reg.is_placeholder("hero_sprite"):
               draw_texture_rect(_reg.get_texture("hero_sprite"), _body_rect, false)
           else:
               draw_rect(_body_rect, cloak_colour)   # the procedural fallback

3. AN ANIMATED 2D SPRITE (`sprite_frames`). The art arrives as a
   `SpriteFrames` resource — one animation per clip it carries — so it
   needs an `AnimatedSprite2D`, never a `Sprite2D`. `is_placeholder` is the
   WRONG test here, for the same reason as the rigged mesh below: it is
   kind-agnostic, so it answers "real art" for a SpriteFrames — but
   `get_texture` cannot return one and hands back the magenta checker, which
   is how a paid sheet renders as a magenta box. Ask for the frames and test
   for null:

       var _reg = get_node_or_null("/root/AssetRegistry")
       var _sf: SpriteFrames = null if _reg == null else _reg.get_sprite_frames("enemy_bonelord")
       if _sf != null:
           anim.sprite_frames = _sf          # anim is an AnimatedSprite2D
           anim.play("idle")
           procedural_body.visible = false   # your drawn version steps aside
           var _f0 := _sf.get_frame_texture("idle", 0)
           if _f0 != null and _f0.get_height() > 0:
               anim.scale = Vector2.ONE * (48.0 / float(_f0.get_height()))
       else:
           pass  # keep drawing your procedural character

   Frames arrive PRE-SIZED for the kind (24-128 px tall, not full-resolution
   renders). Scale only if your procedural body renders at a different size —
   set the target height to YOUR character's on-screen size (the example
   normalizes to 48 px; change or drop it to match). Drive the clips from the body's own state
   (`anim.play("walk")` when it moves, `"attack"` when it swings) — a sheet
   that only ever plays "idle" leaves its other clips unseen.

4. A RIGGED 3D CHARACTER (`glb_mesh` for a character). `is_placeholder` is
   the WRONG test here — it is deliberately kind-agnostic and returns false
   for ANY resource that loads, including a STATIC mesh that came back with
   no skeleton. Use `get_rigged_character`, which returns an EMPTY dictionary
   unless a real rig arrived:

       var _reg = get_node_or_null("/root/AssetRegistry")
       var _rig: Dictionary = {} if _reg == null else _reg.get_rigged_character("hero_model")
       if not _rig.is_empty():
           var _inst = _rig["scene"].instantiate()
           model.add_child(_inst)
           procedural_model.visible = false
           var _ap = _inst.find_child("AnimationPlayer", true, false)
           if _ap != null and "idle" in _rig["animations"]:
               # Provider clips are baked WITHOUT loop flags: an un-looped
               # idle plays once and freezes on its last frame — reads
               # exactly like the T-pose this guard exists to avoid. Force
               # looping on the locomotion clips (one-shots like attack or
               # death stay one-shot).
               for _cn in ["idle", "walk", "run"]:
                   if _ap.has_animation(_cn):
                       _ap.get_animation(_cn).loop_mode = Animation.LOOP_LINEAR
               _ap.play("idle")
       else:
           pass  # keep your procedural model — it is the fallback

   Replace only the VISUAL. Never move, resize or remove the entity's own
   CollisionShape3D: the collider is gameplay and the swap is cosmetic.

Never block gameplay on art: the game must play identically when a guard
falls back to the procedural visual.

## Why the legacy AssetRegistry guard shape matters

`get_texture()` NEVER returns null — a missing id resolves to the 16x16 magenta
checker at `res://assets/placeholders/_missing.png`. So a null check cannot tell
you whether real art arrived, and `is_placeholder()` is the only correct test.
That distinction is not academic: using the wrong guard for a kind ships a
broken game with a GREEN gate, because every tier sees a texture that loaded.

`is_placeholder` is also kind-agnostic — it answers "real art" for a
`SpriteFrames` that `get_texture` then cannot return. Match the guard to the
kind, every time.
