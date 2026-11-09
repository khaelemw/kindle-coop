-- Map events one game's player starts and every game must see (lib.shared_trigger): the lines that
-- let only the host's player start it come out, its "done" flag is set network-connected (it
-- reaches every game, and from a player the host), and the other games' wait ends on that flag,
-- restarting the event into its own "already done" branch. A lever (own_action: started by its
-- player's action button, then that player is warped to it and pulls it): the game syncs an
-- event's conditions across the session (an action button pressed on one game holds on every
-- game) unless the event turns that off; with "in its own world" out, one player's pull ran every
-- game's copy, each moving its own player to the lever (seen with an NPC's item, 2026-10-13). So
-- its first cut becomes "Set Network Sync State" off instead (as the game's own item events have):
-- the puller's game runs it, the others see the lever pulled by its flag. The two High Wall rows
-- have no lines out: their test of the host's type passes for players (coop.rs, the character
-- type test).
--
-- Rows: map, event, the lines to take out {line, bank, index, {its first argument bytes}} (from 0,
-- as the game's event files and the Kindle Events extension show them), wait = which of the
-- event's main waits (from 0), flag = its "done" flag (a number, or {arg = byte}: the event's
-- argument there), own_action.
return {
  {"m30_00_00_00", 13005480, wait = 0, flag = 13000480},
  {"m30_01_00_00", 13015551, wait = 0, flag = 13010580},
  {"m33_00_00_00", 13305421, {4, 3, 26, {1, 0}}, wait = 0, flag = 13300421},
  {"m37_00_00_00", 13700470, {1, 3, 26, {1, 0}}, wait = 0, flag = 13700472, own_action = true},
  {"m37_00_00_00", 13705532, {2, 3, 26, {1, 0}}, wait = 0, flag = 13700532},
  {"m37_00_00_00", 13705535, {1, 3, 26, {1, 0}}, wait = 0, flag = 13700535},
  {"m45_00_00_00", 14505540, {8, 3, 26, {1, 0}}, wait = 0, flag = {arg = 0}, own_action = true},
  {"m50_00_00_00", 15005500, {18, 3, 26, {1, 0}}, wait = 0, flag = 15000500},
}
