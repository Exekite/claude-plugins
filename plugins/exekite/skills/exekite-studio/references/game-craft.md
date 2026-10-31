# Gameplay and asset integration

Preserve the user's genre, controls, visual direction, and intended platform. For a new game, choose a playable core loop with visible feedback, a clear objective, and a way to restart or continue. Make important state changes readable through motion, layout, color, sound when available, and brief instructions. Prefer a coherent small game over disconnected systems added merely to exercise tools.

## Observe the actual game

Read the project's current input map, scenes, and runtime facts. Use `lookup_godot_api` and `get_godot_guide` for Exekite's pinned engine when the API matters. Do not replace those facts with assumptions from a different Godot version.

Use `run_scripted_playtest` for bounded input-action timelines and property samples. Its timeline uses input-map action names and frame numbers; its selectors use actual `/root/...` node paths. `act_in_game` instead uses simultaneous key names and durations in milliseconds. These two input formats are not interchangeable.

For a visible session, call `start_game_test`, retain its `game_test_id`, and inspect actual observations with `observe_game` and `inspect_game_state`. Use screenshots alongside state, movement, and logs. A capture whose evidence carries `blankFrame` (all black or one uniform color) shows nothing yet: capture again or inspect the scene before judging its visuals. A static screenshot proves neither responsiveness nor winning/losing behavior. Exercise the behavior the user asked to change and check a relevant failure or boundary condition. Pause/frame inspection is native-specific. A Web result is relevant only when its exported revision matches the candidate being discussed.

Report what happened and distinguish it from what you infer. Use the returned evidence to fix the game before claiming its behavior works. End the session with `stop_game_test`; submit or roll back the surrounding turn according to the task.

## Use assets in the game

Inspect the existing asset library and requested game element before creating a replacement. Preserve stable asset identifiers and take/checkpoint guards. Read or preview the current asset when that will clarify the change. Generated or uploaded bytes are not integrated gameplay merely because the provider or upload succeeded.

The sprite-sheet recipe currently generates side-view `walk`, `jump`, `attack`, `idle`, `run`, `hurt` and `death` animations. Choose only the needed names. For a platformer, `idle`, `run` and `jump` are supported; `fall` is not a separate generation name. Inspect the returned jump frames before choosing suitable airborne frames for the descending state. Implement that reuse in authored gameplay or animation wiring without editing platform-managed generated files, and say that falling reuses generated jump art. Test ascent, descent and landing; do not infer the actual frame poses or a successful transition from the recipe prompt alone.

A generated sound effect or music track is one clip of 1 to 47 seconds, the provider's limit. For longer background music, generate a clip of up to 47 seconds and loop it in the game rather than asking for a longer clip.

For requested asset-service work, complete this sequence:

1. Inspect `list_game_assets` and `get_game_asset`, then the relevant source and current revision. Identify the requested element, its existing fingerprint or asset identifier, and a supported recipe from the live schema. Do not replace the requested sprite or animation with a hand-drawn approximation just because the game began procedurally.
2. Land or roll back your source turn before the separate asset transaction; the asset lands a new game revision, so a draft parked across it cannot resume. Call `estimate_cost` with the selected operation and its exact generation parameters, excluding operation and estimate identifiers as the schema directs.
3. Right away, call `add_game_asset` for generation or `edit_game_asset_image` for an existing image edit with that `estimate_id` and a stable operation key; do not pause to discuss the price. The charge comes off the user's existing Exekite balance, at most the quote's maximum, and nothing if the generation fails. Wait for the actual job result; retain its asset identifier, registered paths, take and resulting revision. If a quote or provider fails, diagnose that refusal and report it instead of treating procedural substitution as completion. Inspect the original job and charges before any paid retry.
4. Read the resulting asset entry and affected source, then start the wiring right away. A completed generation's reservation stays held until its charge settles, but it refuses the wiring writer only when the balance left after it is not positive (`get_balance` shows held funds and pending settlement). On a wallet-reservation refusal, keep the generated asset and follow the [authoring recovery steps](authoring.md); do not regenerate it or duplicate an uncertain source write. Once admitted, open or continue the permitted edit turn against the resulting revision and wire the returned registered asset into gameplay using the supported typed accessors. Preserve the procedural fallback for unavailable media; the fallback is not a replacement for successful wiring.
5. Playtest the changed game and observe the requested asset in use, including its animation when applicable. Game Test has no sound output (its results say audio.output none), so verify a sound by state: `inspect_game_state` reads its AudioStreamPlayer's playing and stream properties at the moment it should play; then ask the user to listen in a preview (`create_preview_link`). Stop the test, submit the wiring turn, and report the accepted revision, the actual observations and what the generation cost. A generated file or an asset-only preview is not the finished task.

Paid generations run one at a time. After one succeeds, game changes can start at once, and the next generation can start when the balance left after the held reservation and pending charges covers its quote; otherwise it waits for the earlier charge to settle (normally 5–10 minutes). A quote lasts 15 minutes and covers one generation, so quote each asset just before generating it rather than quoting a whole set at once. A request for a finite asset set does not authorize unbounded variations, unrelated media, or spending above a limit the user set. If Exekite refuses with `BALANCE_EMPTY`, nothing was charged: report it and do not retry or split the request to get around it.

Typed Blender operations can create, transform, duplicate, bevel, set materials on, or delete supported objects without arbitrary Python. Keep a model focused on one game asset. Use returned model identifiers and checkpoint hashes for edits and saves; preview its actual geometry and material. Use the returned registration/model path in game code rather than guessing an asset path. Changes remain subject to the surrounding authoring turn's final gate and rollback.

Use `begin_file_upload` for the declared purpose and exact file size/hash, then the corresponding typed attachment/import tool. Treat upload URLs as short-lived capabilities, not public sharing links. Keep credentials out of uploaded files.

Use the same read, wiring-turn and playtest steps after asset attachment. A separate model preview or upload receipt does not establish that the game uses it.

For release preparation, inspect the selected Ship workspace, validate its listing and assets, and report the actual blockers. A verified source revision, an exported package, and an approved store submission are separate results. Only provide public sharing or publication requested by the user; otherwise use a temporary preview link, which anyone holding it can open until it expires.
