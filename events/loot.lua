-- What an enemy gives as it dies, each player its own (common_func): a crystal lizard's drop
-- (20005341, 80 in the maps: its kill flag set, then "end if not in own world" before the award)
-- and enemies' death awards with their own "taken" flags (20005350, 20005351: they end at once in a
-- world not the player's own). The award is 2003[36], "Award Items (Including Clients)": the game's
-- award with its multiplayer checks off (+0x7C10F0, r8b 0), given on the game that runs it and
-- sent nowhere; so a joined player got none (the host's lizard Raw Gem in the internet session
-- of 2026-10-11), and Kindle forwarded the host's. With the own-world line out each game awards
-- its own player as the enemy dies (the death holds on every game), once: the lizard's kill flag
-- ends the event, the others' taken flags are 5xxxxxxx, each player's own.
--
-- Rows: map, event, then the lines to take out: {line, bank, index, {its first argument bytes}},
-- lines numbered from 0 as the game's event files and the Kindle Events extension show them.
return {
  {"common_func", 20005341, {8, 1003, 13, {0, 1}}},
  {"common_func", 20005350, {0, 1003, 13, {0, 1}}},
  {"common_func", 20005351, {0, 1003, 13, {0, 1}}},
}
