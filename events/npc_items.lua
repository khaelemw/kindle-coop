-- What an NPC leaves where it stood once its story has moved on (common_func 20006030, 14 in the
-- maps: shown by the world's NPC state, which a player sees as the host's) and what a killed NPC
-- drops (20006032, 3) end at once in a world not the player's own, so a joined player got
-- nothing. Their "taken" flags are each player's own (50006xxx). Unlike pickups' event items,
-- they don't turn the game's event sync off, so with the own-world line simply gone one player's
-- pickup ran the others' copies too (verified 2026-10-13: the joined player took Hawkwood's
-- Shield and the host's game played the pickup on the host and gave it the shield as well). So
-- that line becomes "Set Network Sync State" off, as the event items' first line: each player
-- takes its own, as alone.
--
-- Rows: map, event, the line made sync off: {line, bank, index, {its first argument bytes}},
-- numbered from 0 as the game's event files and the Kindle Events extension show them.
return {
  {"common_func", 20006030, {0, 1003, 13, {0, 1}}},
  {"common_func", 20006032, {0, 1003, 13, {0, 1}}},
}
