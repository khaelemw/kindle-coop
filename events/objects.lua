-- Objects a player works by hand, which counted only in the player's own world (common_func), so a
-- joined player's did nothing; "in its own world" comes out:
-- - an object the player breaks by hitting it (20005650).
-- (A ladder kicked down, 20005640: sync_off.lua.)
--
-- Rows: map, event, then the lines to take out: {line, bank, index, {its first argument bytes}},
-- lines numbered from 0 as the game's event files and the Kindle Events extension show them.
return {
  {"common_func", 20005650, {1, 3, 26, {1, 0, 0, 0}}},
}
