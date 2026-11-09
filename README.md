# Co-op (beta)

A [Kindle](#kindle) mod for Dark Souls III (version 1.15.2).

Play the whole game together. Friends join the host's world and play it as the host does: the
same bosses, NPCs, items to find, levers, doors and cutscenes as single player, with each player's
own character, souls, items, levels and Estus. Players connect to each other directly, with a code
the host shares; no FromSoftware or Steam server is involved.

**This is a beta.** It has been played through areas of the game by two players, and it has known
problems (below). Keep a copy of your saves (Kindle makes one in `Game\kindle\backups` each time
the game starts with mods).

## What every player needs

- Dark Souls III 1.15.2 with Kindle, and this mod switched on (below).
- The host's DLCs, if the host's world uses them (with the Randomizer mod, the host's run says
  which).
- The host, to play over the internet: its PC reachable from the other players (see
  [The host's network](#the-hosts-network)). On the same home network nothing is needed.

## Playing together

**As a party, from the title screen** (the usual way):

1. The host: at the title screen choose **Co-op**, then **Open a party**. The party's code is
   copied: send it to the others (a chat message, for example).
2. Each player: copy the host's code, then at the title screen choose **Co-op**, then **Join the
   copied party**. The Co-op screen lists who's in.
3. The host: once everyone's in, **Start the party**. Everyone goes into the host's world together.
   Each player has one character per host world, kept by the host with its world: the first time,
   a player makes one with **New Game**; after that, that character loads.

**Joining a game already going:** the host opens the pause menu, **Mods**, the **Co-op** tab, **Host
a session**, and sends the session code that's copied. A player loads its own character, copies
the code and chooses **Join with the copied code** in its own Co-op tab.

The Co-op tab also shows **Players and ping** (each player's ping is also on the HUD under your
bars: green under 80 ms, orange under 150, red above), the codes to copy again, and **Leave**.

## How the party plays

- **The world is the host's.** Bosses killed, NPCs' stories, shortcuts and doors are the host's
  world's. A boss beaten in the host's world isn't beaten in a player's own world.
- **Each player's own:** its character, souls, items, levels, Estus, ember, and what it buys in
  shops. Items lying in the world and what NPCs give, each player picks up for itself.
- **Travel:** only the host travels from a bonfire, and the party goes with it.
- **Going down:** a player who'd die is downed instead. A standing teammate revives it by holding
  the action button beside it for 5 seconds. After 30 seconds downed, the player is out: it
  watches a teammate until the party rests.
- **Resting:** the party rests together. A player who sits waits until every player still in sits
  at the same bonfire; then everyone rests, the enemies come back, and players who were out come
  back beside the bonfire.
- **Everyone down:** the party dies as one player would: YOU DIED, back at the last bonfire, each
  player's souls left where it fell.

## The host's network

On one home network, codes work as they are. Over the internet the host's PC must be reachable:

1. Forward TCP port **27860** on the host's router to the host's PC, and allow Dark Souls III
   through Windows Firewall.
2. In `Game\kindle\kindle.toml`, under `[coop]`, set `public_address` to the host's internet
   address (what a "what's my IP" page shows), or a dynamic DNS name that follows it. Then the
   codes the host copies work over the internet.

Only the host needs this. On Linux (Proton), start the game from Steam with the launch option
`WINEDLLOVERRIDES="dinput8=n,b" %command%` so that Kindle loads.

## Known problems (beta)

- Now and then a join never finishes loading: the player waits in its own world. Leave the session
  and join again.
- A cutscene a player starts may show the host's character in it.
- Report problems with both players' `Game\kindle\logs\kindle.log` from the session.

## Installing it

Install Kindle first ([khaelemw/kindle](https://github.com/khaelemw/kindle)). Then download `coop.zip` from this repo's Releases and unzip it into the game's `Game\kindle\mods` folder, so you have `Game\kindle\mods\coop\mod.toml`.

Co-op is off until you switch it on: at the title screen, choose **Mods**,
open the **Mods** tab and turn **Co-op** on. Then the title screen has **Co-op**. Kindle
Launcher's mod list does the same while the game is closed.

## Removing it

Switch it off in **Mods**, or delete `Game\kindle\mods\coop`. Characters a player made in a host's
world stay with the host's party saves and come back if the mod does.

## Kindle

Kindle is a Lua modding runtime for Dark Souls III: mods are folders of Lua scripts, switched on
and off in game. This mod is plain Lua: `main.lua` and the files it loads, one per part of the
game it changes, with `events\` holding its changes to the game's event scripts.
