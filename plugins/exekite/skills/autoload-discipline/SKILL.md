---
name: autoload-discipline
description: "For Exekite-hosted Godot games only. Authored games have ZERO autoloads — the harness strips project.godot's [autoload] section and you cannot add one. Use when an error involves a /root/Name lookup, when tempted by a global singleton for shared state, or when a legacy edit-lane project carries platform autoloads."
---

# Autoload discipline

Autoloads (Godot calls them "singletons" in the docs) are nodes added to the
root tree for the lifetime of the running game. They survive scene changes and
are addressable as `/root/<Name>`.

**Rewritten 2026-08-16.** The previous version of this file described the
scaffold-era world (a user-owned `GameState` at `autoload/game_state.gd`, an
`autoload/exekite_*.gd` tree). That world no longer exists: games are authored
by the freeform lane, `project.godot` is harness-owned, and no authored game
has an `autoload/` directory.

## The facts for an authored (freeform) game

- **`project.godot` is harness-owned and forbidden to you. Never edit it.**
  The harness writes it and strips the `[autoload]` section entirely, so a
  repair can NEVER add, rename, or remove an autoload — no autoload can exist
  at all.
- A game born by THIS agent has **zero autoloads** — the harness writes
  `project.godot` and strips the `[autoload]` section entirely
  (`src/engine/birth.ts`), and you cannot add one. A `/root/<Name>` reference
  in such a game is an INVENTED singleton: remove the reference and put the
  state on the root game script — do not guard it.
- Only a legacy project born by the frozen Python agent (edit lane) may carry
  platform autoloads — notably `AssetRegistry` (the user's paid generated
  art; load the `generated-media-wiring` skill before touching it) and shell
  entries like `TouchControls`. Guard those lookups.
- **Anything under `addons/` is the platform.** Do not edit, delete, or
  "normalize" it to fix an error. If an error stanza points into `addons/`,
  the real cause is almost always in the game code that CALLS it.

## Cross-scene state without an autoload

Cross-scene state lives on the root game script — the ownership rule, the
pass-down/signal-up patterns, and carrying state across a scene change are in
the `signals-and-events` skill. A static helper (`class_name Util` with static
funcs) covers stateless shared code — no node needed.

Never "fix" a state bug by inventing an autoload: the registration line lives
in harness-owned `project.godot`, a forbidden path — the write itself is
rejected.

## Looking up platform autoloads — always guarded (legacy projects only)

For anything `AssetRegistry`-shaped, load the `generated-media-wiring` skill —
it owns the four guard shapes and the kind-matching rules. For any other
legacy platform autoload (e.g. `TouchControls` in a Python-born project), use
`get_node_or_null("/root/<Name>")` and degrade gracefully when it is absent.

There are no other platform autoloads to look up — `/root/ExekiteLive`,
`/root/ExekiteJSBridge` and the rest of the `Exekite*` set were scaffold-era
and DO NOT EXIST; any code or advice referencing them is stale.

## Anti-patterns

- Adding an autoload in a repair (impossible — `project.godot` is off-limits).
- Editing anything under `addons/` to silence an error.
- An unguarded `get_node("/root/<PlatformName>")` — use `get_node_or_null`.
- An autoload-shaped fix for shared functions — use a `class_name` static
  helper instead.
