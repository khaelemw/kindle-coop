-- Co-op: the joined player plays as the host does, except what is each player's own. Kindle's
-- co-op is moving here from its own code one part at a time: its changes to the game's
-- event scripts (events/), which apply as each map's events load, and its logic (lit.lua, ...).
local lib = require("events.lib")

-- A table whose rows each go through `edit_row` (lib.shared_pull, lib.restart, ...).
local function row_by_row(edit_row)
  return function(rows, why) return lib.rows(rows, edit_row, why) end
end

-- Each table of events/: its file, how its rows change their events, and why.
local tables = {
  { file = "mp_seals", apply = lib.cut_rows, why = "areas the game seals in multiplayer are open" },
  { file = "for_players", apply = lib.cut_rows, why = "what a player gets alone, players get here too" },
  { file = "sync_off", apply = lib.sync_off_rows, why = "what a player uses alone, each player uses here for itself" },
  { file = "shared_pulls", apply = row_by_row(lib.shared_pull), why = "levers and flames any player works, every game shows" },
  { file = "restarts", apply = row_by_row(lib.restart), why = "what one game starts, every game sees at once" },
  { file = "shared_triggers", apply = row_by_row(lib.shared_trigger), why = "what one game starts, every game sees at once" },
  { file = "player_steps", apply = row_by_row(lib.player_step), why = "a player's arrival moves an NPC's story as the host's does" },
  { file = "host_solo", apply = lib.cut_rows, why = "what the host does alone it does with the party" },
  { file = "objects", apply = lib.cut_rows, why = "players break objects and kick ladders down as the host does" },
  { file = "pickups", apply = lib.cut_rows, why = "players pick up the items events hand out" },
  { file = "loot", apply = lib.cut_rows, why = "each player gets its own drop from lizards and enemies' death awards" },
  { file = "npc_items", apply = lib.sync_off_rows, why = "each player picks up what NPCs leave, its own" },
}
local counts = {}
for _, edits in ipairs(tables) do
  local count = edits.apply(require("events." .. edits.file), edits.why)
  counts[#counts + 1] = string.format("%d %s", count, edits.file)
end
-- Edits that read the game's event to find their lines, each with its reasons.
for _, file in ipairs({ "walls", "guest", "doors", "bosses", "npcs", "common", "transforms" }) do
  counts[#counts + 1] = string.format("%d %s", require("events." .. file)(lib), file)
end
kindle.log.info("event edits: %s", table.concat(counts, ", "))

-- Co-op's own logic, each part a file of its own.
require("host")
require("single_player")
require("flags")
require("lit")
require("death")
require("revive")
require("keep")
require("rest")
require("flow")
require("follow")
require("lobby")
require("presence")
require("menu")
