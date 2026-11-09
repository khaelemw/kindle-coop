-- NPC story steps a player's arrival starts, as the host's arrival does (2026-10-16: a
-- joined player moves NPC stories too; lib.player_step): the lines that let only a player in its
-- own world start it come out, so a player reaching the place starts the step on its game, whose
-- network flags reach the host's; and the event's wait also ends when the step's flag is on, so
-- the other games make the same move then (not only at their next load).
-- - Siegward's move to the cell (m39 13900721): it ended at once in a world not its own; the host's
--   player reaching area 3902710 set step 1388 and took his copy 3900705 away, which stayed on a
--   player's game.
-- - An Ariandel NPC's move (m45 14500702, his copies 4500700 and 4500701 180 m apart): its wait
--   needed its player in area 4502700 and in its own world, and the step 1640 to 1641 was skipped
--   in a world not its own. Its event runs again at every load with a phantom present (its done
--   flag cleared), so with 1641 on he's put where the step left him then too.
--
-- Rows: map, event, the lines to take out {line, bank, index, {its first argument bytes}} (from 0,
-- as the game's event files and the Kindle Events extension show them), flag = the step's flag.
return {
  {"m39_00_00_00", 13900721, {0, 1003, 13, {0, 1}}, flag = 1388},
  {"m45_00_00_00", 14500702, {7, 3, 26, {15, 0}}, {13, 1003, 12, {10, 1}}, flag = 1641},
}
