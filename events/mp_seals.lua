-- Multiplayer seals: (map, event, the lines to take out). Multiplayer states 2 and 3 (other
-- characters registered, read from the game's test +0x7A5760) hold whenever a player is
-- summoned, so the game's seals against invaders shut the party in too. Kindle has no invaders:
-- these come out, and what an NPC invader seals stays sealed as alone (all found by the game
-- data index but the chapel's). The multiplayer fog walls are Kindle's walls-off list.
-- - The High Wall of Lothric's chapel past Vordt (fog 3001890, m30 13005890): with summoned
--   players there ("skip 2 if the clients of type 0 number 0", then the fog on and its effect)
--   and in a multiplayer state ("skip 2 if the state is 4", then the same), and in its fight's
--   branch "go to 2 if not in its own world", past the fog's action button.
-- - The two multiplayer fog walls an NPC invader puts up too (common_func 20005781: the Undead
--   Settlement's before the sniper with Holy Knight Hodrick, 13105161; the Road of Sacrifices'
--   with its invader, 13305161): their multiplayer lines.
-- - The Undead Settlement's door before the sniper, behind that wall (ObjAct 314029; its "Open"
--   button, ActionButtonParam 3101510, is off while flag 13105511 is on: m31 13105510): off while
--   Hodrick invades and in multiplayer states 2 and 3.
-- - Halflight's fog wall (m51_01 15115848, a copy of common_func 20005820, Kindle's boss fog wall edit): up
--   also on a game not in its own world and, the boss dead, in multiplayer states 2 and 3; those
--   two reasons come out as from 20005820, so every game's wall follows the host's rule.
--
-- Rows: map, event, then the lines to take out: {line, bank, index, {its first argument bytes}},
-- lines numbered from 0 as the game's event files and the Kindle Events extension show them.
return {
  {"m30_00_00_00", 13005890, {25, 1003, 14, {2, 0, 0, 0}}, {26, 2005, 3, {0x22, 0xCE, 0x2D, 0x00, 1}}, {27, 2006, 4, {0x22, 0xCE, 0x2D, 0x00}}, {45, 1003, 5, {2, 4}}, {46, 2005, 3, {0x22, 0xCE, 0x2D, 0x00, 1}}, {47, 2006, 4, {0x22, 0xCE, 0x2D, 0x00}}, {54, 1003, 12, {2, 1}}},
  {"common_func", 20005781, {3, 3, 6, {0xFF, 3}}, {4, 3, 6, {0xFF, 2}}, {10, 3, 6, {0xFE, 3}}, {11, 3, 6, {0xFE, 2}}, {12, 0, 0, {1, 0, 0xFE}}},
  {"m31_00_00_00", 13105510, {2, 3, 6, {0xFF, 3}}, {3, 3, 6, {0xFF, 2}}, {8, 3, 6, {0xFE, 3}}, {9, 3, 6, {0xFE, 2}}, {10, 0, 0, {1, 0, 0xFE}}},
  {"m51_01_00_00", 15115848, {15, 0, 0, {0xFC, 1, 1}}, {17, 0, 0, {0xFC, 1, 3}}, {34, 0, 0, {14, 0, 11}}, {36, 0, 0, {14, 0, 13}}},
}
