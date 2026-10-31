---
name: entity-lifecycle
description: "For Exekite-hosted Godot games only. queue_free hazards — a freed node lingering in an array/pool aborts _process mid-frame and can make the game unwinnable. Use when entities you free are also tracked in a collection, when a 'previously freed instance' error appears, or when pooled/despawned objects still collide or emit."
---

# Entity lifecycle

Exposed by a real birth (Temple-A): collected entities were `queue_free()`d but
kept in a live array. Every later frame called a method on a freed instance,
which throws, which aborts the rest of `_process` — so the win condition was
never reached and the game was **unwinnable**. Detection today: **none before
runtime**. Parse and scene both pass; only actually playing it shows the error.

## `queue_free()` does not clear your references

It frees the node at the end of the frame. Every array, dictionary and `var`
still holding it now holds a dangling reference, and touching one throws
`Invalid call. Nonexistent function 'x' in base 'previously freed'.`

```gdscript
# WRONG — the array still holds the freed node
func _collect(coin: Node) -> void:
    coin.queue_free()
    _score += 1
# next frame:
for c in _coins:          # `c` is freed; c.position throws
    c.position.y += sin(t)
```

```gdscript
# RIGHT — remove it from your bookkeeping in the same breath
func _collect(coin: Node) -> void:
    _coins.erase(coin)
    coin.queue_free()
    _score += 1
```

## `is_instance_valid()` is the guard, and it is not free

When you cannot guarantee ownership — anything reachable from a signal, a
timer, or another system — check before use:

```gdscript
if is_instance_valid(_target) and not _target.is_queued_for_deletion():
    _target.take_damage(1)
```

`is_instance_valid` is true for a node that is *queued* but not yet freed, which
is why the second half matters inside the same frame as the `queue_free`.

Prefer not needing it. A filter each frame is cheaper to reason about than a
guard at every use site:

```gdscript
_enemies = _enemies.filter(func(e): return is_instance_valid(e))
```

## Hide, do not free, when it comes back

Bullets, particles, pickups that respawn — freeing and re-instancing each time
costs allocation and gives you this whole class of bug for nothing.

```gdscript
func _despawn(b: Node2D) -> void:
    b.visible = false
    b.set_physics_process(false)
    b.global_position = Vector2(-9999, -9999)   # out of every area's reach
    _pool.append(b)
```

Turn processing OFF as well as visibility. A hidden node still runs
`_physics_process`, still collides, and still fires `body_entered` — an
invisible bullet that still kills the player is a very confusing bug.

## Freeing during iteration

Never free while iterating the same collection. Collect, then act:

```gdscript
var dead: Array[Node] = []
for e in _enemies:
    if e.hp <= 0:
        dead.append(e)
for e in dead:
    _enemies.erase(e)
    e.queue_free()
```

## Signals outlive the emitter's usefulness

Bound-method connections are cleaned up automatically when either side is
freed — you do not need `_exit_tree()` disconnects for
`sig.connect(self.method)`. LAMBDA connections are the trap:
`sig.connect(func(): self.do())` is not owned by `self`, survives its free,
and throws when the body touches the freed capture. Prefer bound methods for
anything the emitter outlives, or disconnect the lambda in `_exit_tree()`.

## The check that makes this visible

An unwinnable game is the expensive outcome, so assert the invariant rather than
hoping:

```gdscript
func _process(_d: float) -> void:
    for e in _enemies:
        if not is_instance_valid(e):
            push_error("a freed node survived in _enemies — the loop will abort here")
            return
```

`push_error` reaches stderr, which the boot and playtest tiers read.
