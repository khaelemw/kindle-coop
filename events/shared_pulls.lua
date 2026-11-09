-- Things a player works with its button that every game must then show, each a network flag the
-- press sets (a joined player could use none: "in its own world" in the wait with the button;
-- the event audit of 2026-10-16; lib.shared_pull). The presser's game runs the event alone: its
-- own-world line becomes "Set Network Sync State" off, so a press never holds on another game
-- (which would warp and animate that game's player too, as a lever's did, 2026-10-13). On the
-- other games the wait also ends once the flag is in the state the press sets, and they skip only
-- the presser's own lines after it (its warp to the thing and its animation), doing the rest as
-- the game does:
-- - Farron Keep's three flames (m33 13300412, four starts: the flame's flag X4, then the count
--   13300410 that the Abyss Watchers' door waits on, 13305410, and the flame's cutscene). A game
--   whose flame's flag is already on as the event starts takes its "already out" branch, as its
--   own done flag would send it (a player joining after the host put one out).
-- - The Catacombs' lever (m38 13805202): pushed one way it sets 13800200, the other way clears it.
-- - The Cinders of a Lord on Firelink's thrones (m40 14000121, four starts: the throne's flag X0,
--   9211..9214). With the event's sync on, one player's offering held on every game, so every
--   player turned to the throne, played the offering and had that Cinder taken (a joined player,
--   2026-10-19). The presser alone does now; the others see the Cinder placed (the object and its
--   flame, lines 20-22). Its flag is a plain set (line 18), made network-connected.
-- - The Cathedral's ladder kicked down (m35 13500490): the kick turns the kicker to the ladder with
--   its animation (60210); with sync on, every player kicked with it (the same as the thrones, found
--   sweeping for them). The others see the ladder fall and can climb it. Its flag is a plain set
--   (line 12), made network-connected. (The common ladders, common_func 20005640: sync_off.lua.)
--
-- Rows: map, event, waits = {{which (of the event's main waits, from 0), gate (its own-world
-- line before it: {line, bank, index, {bytes}}, from 0 as the extension shows them), own (the
-- presser's own lines after it), flag (a number, or {arg = byte}), state (the press leaves the
-- flag in)}}, done_at_start, network_sets (lines whose plain "set flag" becomes network-connected).
return {
  {"m33_00_00_00", 13300412, waits = {
    {which = 0, gate = {9, 3, 26, {1, 0}}, own = 2, flag = {arg = 4}, state = 1},
  }, done_at_start = true},
  {"m38_00_00_00", 13805202, waits = {
    {which = 0, gate = {1, 3, 26, {1, 0}}, own = 2, flag = 13800200, state = 1},
    {which = 1, gate = {11, 3, 26, {2, 0}}, own = 2, flag = 13800200, state = 0},
  }},
  {"m40_00_00_00", 14000121, waits = {
    {which = 0, gate = {0, 1003, 13, {0, 1}}, own = 7, flag = {arg = 0}, state = 1},
  }, network_sets = {18}},
  {"m35_00_00_00", 13500490, waits = {
    {which = 0, gate = {5, 3, 26, {1, 0}}, own = 2, flag = 13500490, state = 1},
  }, network_sets = {12}},
}
