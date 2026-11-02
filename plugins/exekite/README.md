# Exekite for Claude

Build and test games with Claude. Claude writes each game's design, game code and scenes; Exekite stores the game, runs automated checks and playtests in an isolated workspace, keeps every verified revision, and prepares preview links, source exports and release builds.

The plugin adds the Exekite connector (`https://mcp.exekite.com/mcp`) and 15 skills: the `exekite-studio` workflow and 14 game-development skills covering syntax, scene layout, signals, object lifetimes, collisions, moving bodies, resources, tile maps, HUD layout, start and pause input, debugging and asset wiring.

## Install

In Claude Code:

```
/plugin marketplace add exekite/claude-plugins
/plugin install exekite@exekite
```

Then run `/mcp`, select the Exekite server and sign in. On Exekite's consent page you choose which games Claude may use and which permissions it gets. Try: "Make a small keyboard-controlled arcade game with geometric art."

For claude.ai and Claude Desktop, follow the [install guide](https://github.com/exekite/claude-plugins#readme).

## What you need

An Exekite account. Creating and editing games requires an Exekite plan that includes game creation; listing, reading and playing your existing games do not. Building, checking and playtesting a game count as build time on your Exekite account. Store submission, signing, agreements, notarization and project deletion stay with you in Exekite Studio.

## Generated art and sound are part of a game build

Exekite builds complete, playable games. Generated sprites, images, sound, music and 3D models are inputs to a game build: each is made for a game in your Exekite account and wired into that game, and Exekite offers no standalone image, video or audio generation. When you ask for one, Claude gets a price quote for that exact request and generates it. The charge comes off your existing Exekite balance and is never more than the quoted maximum; a generation that fails costs nothing. Claude then tells you what was generated and what it cost, wires it into your game and tests the build. Claude may show its own permission prompt before a paid tool runs, depending on your settings. Art and sound written in code use no paid generation.

## Play and watch

After building or changing a game, Claude prepares a preview link so you can play it. A preview link is temporary and unlisted: anyone holding it can open it until it expires, one hour by default. To watch Blender or Game Test while Claude works, or to inspect a model or asset, Claude gives you a companion link that opens in your browser after you sign in to Exekite. Publishing a game on its public exekite.games page happens only when you ask for it.

## Data and control

Claude sends the arguments of each Exekite tool call to Exekite and receives the results. Depending on the action, this includes game design, source files, uploaded assets, screenshots, runtime observations, job state, and account and project metadata. Exekite uses Cloudflare to store and run projects, revisions and operation records. A generation you ask for can send the asset description and the source media it needs to fal, Exekite's media provider; it does not start another game-authoring model. The Claude app you use handles the conversation and the returned results under its own policies.

Exekite never asks for your password or a token in chat. You can disconnect Claude at any time in Exekite Studio under Account → Connected assistants, which ends that connection's access and its unexpired preview links without deleting your games; a password reset or change disconnects every assistant. Upload links last 15 minutes and download links 5 minutes. Creating a public share changes who can open that game's build, and Claude creates one only when you ask.

See the [privacy policy](https://exekite.com/privacy), [terms](https://exekite.com/terms) and [support](https://exekite.com/contact).

## License

The files in this plugin are under the MIT license, except the Exekite name and logo, which are trademarks of Exepad LLC (see LICENSE). Using Exekite requires an Exekite account and is governed by the [Exekite terms](https://exekite.com/terms).
