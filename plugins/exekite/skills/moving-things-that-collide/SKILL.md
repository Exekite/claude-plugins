---
name: moving-things-that-collide
description: "For Exekite-hosted Godot games only. Non-player movers (enemies, projectiles, vehicles) — why position += v * delta on a plain Node2D/Node3D phases through walls, which body type sweeps, the mandatory CollisionShape child, and ray line-of-sight. Use when a mover ignores geometry or when picking its body class."
---

# Things that move and must not pass through walls

Exposed by every temple arm and Race-B: enemies and rivals were translated by
setting `position` directly on a plain `Node3D`. They phased through geometry,
had no line-of-sight, and floated through the level. Detection today: **none** —
the game boots, the scene loads, nothing errors. It just looks wrong.

## Setting `position` is teleporting

```gdscript
# WRONG on anything that should collide
position += direction * speed * delta
```

That moves the transform. It does not sweep, so nothing is between the old
position and the new one — walls included. It is correct only for things that
SHOULD pass through everything: floating damage numbers, background parallax,
camera rigs.

## Pick the body type by what the thing must do

| The thing | Node | How it moves |
|---|---|---|
| Player, enemy, NPC — scripted movement that collides | `CharacterBody2D`/`3D` | set `velocity`, call `move_and_slide()` |
| Crate, debris — physics owns it | `RigidBody2D`/`3D` | `apply_impulse()`, never set position |
| Platform, door — moves on rails, pushes bodies | `AnimatableBody2D`/`3D` | set `position`; it sweeps correctly |
| Trigger volume, pickup, hitbox | `Area2D`/`3D` | `body_entered` signal |
| Decoration | `Node2D`/`Node3D`, `MeshInstance3D` | anything |

**Every one of them needs a `CollisionShape2D`/`3D` child with an actual
`shape` assigned.** A body with no shape collides with nothing and reports no
error — which is the second half of this failure class.

```gdscript
func _make_enemy() -> CharacterBody3D:
    var body := CharacterBody3D.new()
    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.4
    shape.height = 1.8
    col.shape = shape                      # WITHOUT this the body is a ghost
    body.add_child(col)
    body.add_child(MeshInstance3D.new())   # the visible part is separate
    return body
```

## Moving one

```gdscript
func _physics_process(delta: float) -> void:
    var to_player := (_player.global_position - global_position)
    var dir := to_player.normalized()

    if not is_on_floor():
        velocity.y -= GRAVITY * delta      # 3D: -Y is down
    velocity.x = dir.x * SPEED
    velocity.z = dir.z * SPEED
    move_and_slide()                       # sweeps; stops at walls
```

`move_and_slide()` reads and writes `velocity` and needs no arguments in Godot
4. In `_physics_process`, never `_process` — physics runs on its own clock and
mixing them gives frame-rate-dependent movement.

## Line of sight is a ray, not a distance check

Distance alone makes an enemy see through walls.

```gdscript
func _can_see(target: Node3D) -> bool:
    var space := get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(global_position, target.global_position)
    q.exclude = [get_rid()]                # or it hits itself immediately
    var hit := space.intersect_ray(q)
    return hit.is_empty() or hit.collider == target
```

The 2D form is the same with `get_world_2d()` and
`PhysicsRayQueryParameters2D`. `exclude` is not optional — a ray starting inside
your own collider hits it on the first step.

## Two traps that look like this one

- **Layer/mask set to 0.** The body has a shape and still passes through
  everything, because it scans for nothing. Set both explicitly.
- **Scaling a collision shape by scaling the node.** Godot warns for non-uniform
  scale on physics bodies and the collision does not match what you see. Size
  the `shape` resource instead.
