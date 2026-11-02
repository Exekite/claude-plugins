# Exekite for Claude

Exekite is a game studio you use through Claude. Claude writes a game's design, game code and scenes; Exekite stores the game, runs automated checks and playtests in an isolated workspace, keeps each verified revision, and prepares preview links, source exports and release builds. Generated sprites, images, sound, music and 3D models are made only for a game in your Exekite account, as inputs to its build.

This repository holds the [Exekite plugin](https://github.com/exekite/claude-plugins/tree/main/plugins/exekite): the Exekite connector, `https://mcp.exekite.com/mcp`, and 15 skills that teach Claude the Exekite workflow and game development.

## What you need

- An Exekite account. Creating and editing games requires an Exekite plan that includes game creation; listing, reading and playing your existing games do not.
- Claude Code, or a Claude plan that lets you add custom connectors on claude.ai.

## Claude Code

Add this marketplace and install the plugin:

```
/plugin marketplace add exekite/claude-plugins
/plugin install exekite@exekite
```

Then run `/mcp`, select the Exekite server and choose Authenticate. Your browser opens Exekite's consent page: sign in, choose which games Claude may use (all current and future games, which creating a new game needs, or selected games only) and which permissions it gets, and return to Claude Code.

If you added Exekite earlier with `claude mcp add`, remove that entry with `claude mcp remove exekite`, in the project where you added it unless you added it with `--scope user`. Claude Code connects to Exekite only once, and it prefers an entry you added yourself to the plugin's.

To get a new version, run `claude plugin update exekite@exekite` in your shell, or choose Update now on Exekite in the Installed tab of `/plugin`, then run `/reload-plugins` or start a new session. To get new versions automatically, turn on auto-update for the exekite marketplace in the Marketplaces tab of `/plugin`. To remove the plugin, run `/plugin uninstall exekite@exekite`.

## claude.ai

You can add Exekite as a plugin, which brings the connector and the 15 skills together, or add the connector and the skills separately. Choose one: the plugin already contains the skills.

### As a plugin

1. Open Customize → Plugins, choose Add, then Add marketplace, and enter `exekite/claude-plugins`. Find Exekite under Discover, select it and choose Add.
2. Open the plugin's Connectors tab, add the Exekite connector and choose Connect. Exekite's consent page opens: check that it names the Exekite account you mean to use, choose the games and permissions, and allow.

New versions reach your account when the marketplace syncs: choose Check for updates in Customize → Plugins, or turn on Sync automatically for the marketplace.

### The connector and the skills separately

1. Add the connector. If Exekite is listed in Claude's connectors directory, open Customize → Connectors, select Discover, search for Exekite and choose Connect to Claude on its page. Otherwise add it as a custom connector: open Customize → Connectors, choose Add, then Add custom connector (in some versions, Custom, then Web), name it Exekite, enter `https://mcp.exekite.com/mcp`, keep the sign-in settings Claude detects, choose Add, then choose Connect.
2. Exekite's consent page opens: check that it names the Exekite account you mean to use, choose the games and permissions, and allow.
3. Add the skills. Download the skill ZIPs from this repository's latest release and upload each one under Customize → Skills. Start with `exekite-studio.zip`, the workflow skill. The others are game-development skills it refers to by name.

### Settings, plans and limits

Skills, the plugin's included, need code execution, which you turn on under Settings → Capabilities; on a Team or Enterprise plan it is an organization setting that an Owner controls.

On a Team or Enterprise plan, an organization Owner adds connectors for everyone (on Enterprise, so can a member whose custom role allows it), and each member then connects their own Exekite account. Until Exekite is added, other members see Request, or a note to ask an organization Owner, where the connect button would be; for a custom connector the note reads "Ask an organization owner to add this for your team". Ask an Owner to add Exekite under Organization settings → Connectors, then choose Connect on Exekite under Customize → Connectors, or on the plugin's Connectors tab. In the directory, an Owner's button reads Connect for your team, which adds Exekite for everyone; the Owner then connects their own account with Connect to Claude. An Owner also decides whether members may add plugins and skills themselves. A Free plan allows one custom connector.

Claude asks before each Exekite tool by default. In the connector's tool permissions you can set the Read-only group to Always allow, so Claude does not stop before reads of your account, projects, jobs and saved records. Reading a game's files, design, assets, tuning or release settings runs in that game's workspace, starting it if needed, and counts as build time, so Claude lists those reads with the write tools, in the Write/delete group. Always allow on that group stops those prompts too, but it covers Exekite's write, paid and publish tools as well; Always allow on single tools stops the prompts for those tools alone, and the rest of that group keeps asking.

A first build can take more tool calls than one Claude reply allows. If Claude says it reached its tool-use limit, reply "continue" and it carries on with the same change.

## Claude Desktop

Chats in Claude Desktop use the plugins, connectors and skills of your Claude account, so set Exekite up as in the claude.ai section (Customize is in the sidebar). The Code tab's local sessions also receive the connectors you connected on your Claude account; add plugins there with + → Add plugins. In a terminal, follow the Claude Code steps.

## Generated art and sound

When you ask for generated sprites, images, sound, music or 3D models for a game, Claude gets a price quote for that exact request and generates it. The charge comes off your existing Exekite balance and is never more than the quoted maximum; a generation that fails costs nothing. Claude then tells you what was generated and what it cost, wires it into the game and tests the build. Building, checking and playtesting a game count as build time on your Exekite account. Art and sound written in code use no paid generation.

## Permissions and disconnecting

Exekite never asks for your password or a token in chat. If Claude needs a permission you did not grant, it tells you; reconnect Exekite and choose that permission on the consent page. A reconnection is a new connection, which does not see the earlier connection's open changes or price quotes.

You can see and disconnect each assistant in Exekite Studio under Account → Connected assistants; a password reset or change disconnects every assistant. Removing the connector or the plugin in Claude does not end its access on Exekite's side, so disconnect it in Studio too.

## Privacy and support

Exekite is provided by Exepad LLC. See the [privacy policy](https://exekite.com/privacy), the [terms](https://exekite.com/terms) and [support](https://exekite.com/contact).

## License

The files in this repository are under the MIT license, except the Exekite name and logo, which are trademarks of Exepad LLC (see LICENSE). Using Exekite requires an Exekite account and is governed by the [Exekite terms](https://exekite.com/terms).
