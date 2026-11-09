-- What the host does alone that the game keeps from a host with players (multiplayer state 4 =
-- one registered character, read from the game's test +0x7A5760, 2026-10-15), or does only after
-- sending every phantom home: (map, event, the lines to take out). A Kindle party plays as one
-- player would, and its players follow the host's travel (coop/follow.rs), so these come out
-- (all found by the game data index):
-- - the Small Lothric Banner to the Undead Settlement (m30 13005550: "skip 2 if alone", else "it
--   can't be used in multiplayer" and end): the host (2026-10-15) could raise it only once the
--   joined player was gone;
-- - the Cinders of a Lord on Firelink's thrones (m40 14000121, four starts): only alone;
-- - the Painted World of Ariandel from the Cathedral's painting (m35 13505100): "skip if no
--   phantoms", else every phantom sent home, before its cutscene and warp;
-- - the Dreg Heap from the Kiln (m41 14105510) and from the Painted World (m45 14505160): only
--   alone, and every phantom sent home first;
-- - Archdragon Peak by the Path of the Dragon at Irithyll Dungeon's dragon remains (m39
--   13905900): it ended in multiplayer states 2 and 3;
-- - the Undead Settlement's cage carrier (m31 13105320): in multiplayer states 2 and 3 its
--   "Examine" was never waited on (it jumped to waiting for the session's end); those jumps and the
--   wait's state conditions come out (2026-10-17: yes), the first jump becoming "sync off"
--   (Kindle's sync-off list), so the one who examines it rides it alone.
--
-- Rows: map, event, then the lines to take out: {line, bank, index, {its first argument bytes}},
-- lines numbered from 0 as the game's event files and the Kindle Events extension show them.
return {
  {"m30_00_00_00", 13005550, {7, 1003, 5, {2, 4}}, {8, 2007, 1, {0x3A, 0xBE, 0x98, 0x00}}, {9, 1000, 4, {1, 0, 0, 0}}},
  {"m40_00_00_00", 14000121, {8, 3, 6, {1, 4}}},
  {"m35_00_00_00", 13505100, {8, 1003, 14, {1, 1, 0, 0}}, {9, 2009, 11, {0, 0, 0, 0}}},
  {"m41_00_00_00", 14105510, {8, 3, 6, {2, 4}}, {11, 2009, 11, {0, 0, 0, 0}}},
  {"m45_00_00_00", 14505160, {19, 3, 6, {4, 4}}, {22, 2009, 11, {0, 0, 0, 0}}},
  {"m39_00_00_00", 13905900, {12, 1003, 6, {1, 2}}, {13, 1003, 6, {1, 3}}},
  {"m31_00_00_00", 13105320, {8, 1003, 105, {1, 3}}, {11, 3, 6, {0xFD, 2}}, {12, 3, 6, {0xFD, 3}}, {15, 0, 0, {0xFC, 1, 0xFD}}, {17, 1000, 107, {1, 1, 0xFD}}},
}
