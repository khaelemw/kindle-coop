-- Items the event scripts hand out (common_func: a glow on an object, an item lot on the action
-- button), with no map item: they ended at once in a world not the player's own, so a joined
-- player got nothing. Their "taken" flags are 5xxxxxxx, each player's own (as map items'): with
-- "in its own world" out, each player takes its own. 20005521 is the same for an item in a
-- breakable object, once destroyed (the High Wall's, lot 3000170, 53000170; found by the event
-- audit of 2026-10-16).
--
-- Rows: map, event, then the lines to take out: {line, bank, index, {its first argument bytes}},
-- lines numbered from 0 as the game's event files and the Kindle Events extension show them.
return {
  {"common_func", 20005521, {6, 1003, 13, {0, 1}}},
  {"common_func", 20005525, {1, 1003, 13, {0, 1}}},
  {"common_func", 20005526, {1, 1003, 13, {0, 1}}},
  {"common_func", 20005527, {1, 1003, 13, {0, 1}}, {16, 3, 26, {1, 0}}},
}
