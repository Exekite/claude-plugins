---
name: collisions-and-areas
description: "For Exekite-hosted Godot games only. Godot 4 collision system — Area2D vs bodies, collision layers + masks, enter/exit signals, hitbox/hurtbox split. Use when an overlap misfires, things collide with the wrong things, or when unsure whether a pickup, hazard or hitbox is an Area2D or a solid body."
---

# Collisions and areas

Three concerns: **what kind of body is this**, **what does it collide with**, and **how does it react**.

## Body types — pick one per node

| Body | Used for | Auto-physics? | Collision response? |
|---|---|---|---|
| `StaticBody2D` | Walls, ground, immobile platforms | No | Other bodies bounce off |
| `CharacterBody2D` | Player, NPCs, anything you control | No (you set velocity) | Slides via `move_and_slide()` |
| `RigidBody2D` | Physics props, debris, dice | Yes (forces, gravity) | Engine-driven |
| `Area2D` | Triggers, hurtboxes, pickups, sensors | No | NONE — just detects overlap |

Picking the wrong body class is the #1 collision bug. **`Area2D` for "did X enter Y", everything else for solid presence.**

## CollisionShape2D / CollisionPolygon2D

Every body needs at least one collision shape as a child:

```
Coin (Area2D)
├── Sprite2D
└── CollisionShape2D       (with a CircleShape2D resource)
```

Common shapes: `CircleShape2D`, `RectangleShape2D`, `CapsuleShape2D` (good for character bodies), `WorldBoundaryShape2D` (infinite plane), `ConvexPolygonShape2D`, `ConcavePolygonShape2D` (concave only on `StaticBody2D`).

Shapes can be enabled/disabled per-frame:
```gdscript
$CollisionShape2D.set_deferred("disabled", true)   # safe inside a signal handler
```

The `set_deferred` form is required when toggling INSIDE a body_entered/area_entered handler — toggling synchronously confuses the physics step.

## Layers and masks

Two integers per body, each a bitfield over 32 named "physics layers":

- **Layer**: which layers does this body live in?
- **Mask**: which layers does this body scan for collisions?

An Area2D detects B when `A.mask & B.layer != 0`; B does not need to scan A.
Body collision response also depends on the body types and their movement.

**This platform's `project.godot` declares NO `[layer_names]`.** You cannot add
any — the harness owns that file and you may not write it. So layers are bare
numbers here, and the only place their meaning can live is your code.

Set them numerically, and say what each one means where you set it:

```gdscript
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 3

func _ready() -> void:
    # set_collision_layer_value / _mask_value take a 1-based INDEX, not a bitmask
    collision_layer = 0  # clear default layer 1 before choosing membership
    collision_mask = 0
    set_collision_layer_value(LAYER_PLAYER, true)
    set_collision_mask_value(LAYER_WORLD, true)
    set_collision_mask_value(LAYER_ENEMY, true)
```

`collision_layer = 3` (raw bitmask: layers 1 AND 2) and `set_collision_layer_value(3, true)`
(the index: adds layer 3, bit value 4) mean DIFFERENT things — for values 1 and 2
the values happen to coincide, but the helper preserves other set bits. Pick the index
helpers and stay with them.

A typical setup:

| Thing | Layer | Mask |
|---|---|---|
| World walls / ground | world | (nothing — it doesn't move) |
| Player | player | world |
| Enemy | enemy | world, player |
| Player hitbox (sword swing) | player_hitbox | enemy_hurtbox |
| Enemy hurtbox | enemy_hurtbox | (nothing — only hit detects it) |
| Coin pickup | pickup | player (the coin handles `body_entered`) |

Set layer/mask in code, or as `collision_layer` / `collision_mask` integer properties on the node's section in the `.tscn`:
```gdscript
collision_layer = 0b0010    # layer 2
collision_mask  = 0b0001    # scans layer 1
# Equivalent using 1-based indices, starting from cleared bits:
collision_layer = 0
collision_mask = 0
set_collision_layer_value(2, true)
set_collision_mask_value(1, true)
```

## Detecting overlaps with Area2D

Area2D has two pairs of signals:
- `body_entered(body: Node2D)` / `body_exited` — for `*Body2D` collisions
- `area_entered(area: Area2D)` / `area_exited` — for area-on-area

Connect in `_ready`:
```gdscript
extends Area2D

signal collected(amount: int)

func _ready() -> void:
    collision_layer = 0
    collision_mask = 0
    set_collision_layer_value(4, true)  # pickup
    set_collision_mask_value(2, true)   # player; match the player's layer
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if not body.is_in_group("player"):
        return
    collected.emit(1)  # the level owner counts; freeform games have no GameState autoload
    queue_free()
```

Enter signals fire once when an overlap begins. If contact damage should repeat
after invulnerability expires, check the continuing overlaps on physics ticks or
track enter/exit membership; waiting for another enter event leaves a player safe
inside the hazard. Route one contact representation through the damage handler so
body and hurtbox notifications cannot independently charge the same hit.

Damage feedback must reach the visible renderer: the CanvasItem that owns the
2D `_draw()` or sprite (or its ancestor), or the material of the visible 3D mesh.
Modulating an empty child does not change drawing on its parent. Observe a hit
and the feedback's reset; a timer named invulnerability does not prove a flash.

Group-based filtering (`is_in_group("player")`) decouples the area from a specific class. Add the player to the `"player"` group in its `.tscn`.

## Hitbox / hurtbox split

For combat, separate the thing that DEALS damage from the thing that TAKES damage:

- **Hitbox**: an Area2D on the attacker. Active during the attack frames.
- **Hurtbox**: an Area2D on the target. Active whenever the target is vulnerable.

The hitbox detects overlap with the hurtbox; the hurtbox notifies the parent.

```gdscript
# Hitbox.gd (Area2D, on attacker)
@export var damage: int = 10

func _ready() -> void:
    area_entered.connect(_on_area_entered)
    monitoring = false   # hitbox starts disabled; AnimationPlayer toggles it

func _on_area_entered(area: Area2D) -> void:
    if area is Hurtbox:
        area.take_hit(damage)
```

```gdscript
# Hurtbox.gd (Area2D, on target)
class_name Hurtbox
extends Area2D
signal hit_taken(damage: int)

func take_hit(amount: int) -> void:
    hit_taken.emit(amount)
```

The attacker's AnimationPlayer enables the hitbox via a method track (frame 12 of the swing) and disables it on frame 16. Outside those frames, the box is dormant.

## Querying without signals — direct intersect

Sometimes you want a one-shot "what's in this region right now?" instead of an enter signal:

```gdscript
var space := get_world_2d().direct_space_state
var query := PhysicsShapeQueryParameters2D.new()
query.shape = $CollisionShape2D.shape
query.transform = global_transform
query.collision_mask = collision_mask
var hits := space.intersect_shape(query, 32)   # max results
for hit in hits:
    print(hit.collider)
```

Useful for "find all enemies in a 100-pixel radius around the explosion" without creating a temporary Area2D.

## RigidBody2D — when you want the engine to drive

Forces, torque, gravity all auto-apply. You're typically not setting velocity directly.

```gdscript
extends RigidBody2D

func _ready() -> void:
    apply_central_impulse(Vector2(200, -300))   # initial pop
```

For a platform or door that moves on rails and pushes bodies, use `AnimatableBody2D` — set `position`; it sweeps correctly (see moving-things-that-collide).

## Per-instance shapes and reachable patrols

A scene's embedded Shape2D/Shape3D resource is shared between its instances unless
it is local to the scene. Mutating one instance's shape can silently resize every
wall while each wall still draws its own dimensions. Before changing a shape's
size or radius, mark its sub-resource `resource_local_to_scene = true` in the
`.tscn`, or assign an instance-owned copy:

```gdscript
extends StaticBody2D

@export var wall_size := Vector2(80, 40)

func _ready() -> void:
    var collision := $CollisionShape2D as CollisionShape2D
    var local_shape := collision.shape.duplicate() as RectangleShape2D
    local_shape.size = wall_size
    collision.shape = local_shape
```

Verify two differently sized instances retain different collision dimensions after
both enter the tree. Test movement against several points along the outer walls,
not just their centers; a narrow shared shape can block the center yet leave most
of the visible boundary open.

Patrol waypoints must connect through free space with clearance for the enemy's
collision radius. `move_and_slide()` does not navigate around a hedge: an enemy
that advances only when it reaches the target will stay blocked forever. Observe
one complete patrol loop against the actual wall shapes. A passed build gate and
one successful movement sample do not prove a loop or a win/lose condition.
Keep the patroller's world collision mask enabled when walls should block it;
fix the route and clearance instead of disabling collision to pass through a wall.

## Anti-patterns

- Using `Area2D` and trying to make it block movement. Areas don't block. You want `StaticBody2D` or a tile collision.
- Using `CharacterBody2D` for a pickup. You want `Area2D` — pickups don't block; they detect.
- Toggling `disabled` synchronously inside a body_entered handler. Use `set_deferred("disabled", true)`.
- Everything left on the default (layer 1, mask 1). Everything collides with everything and interactions cannot be filtered. Set layers/masks deliberately.
- Connecting `body_entered` for `Area2D` overlap with another `Area2D`. That fires `area_entered`, not `body_entered`. Read the body class.
- A single Area2D doing both pickup-detection AND hurtbox AND wall-trigger. Each role wants its own area (different mask, different signal handler).
