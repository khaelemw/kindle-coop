-- What each player uses for itself in an event that ends or waits on "in its own world" and leaves
-- the game's event sync on, unlike for_players' events: with the line simply gone, one player's
-- use would run on every game (as with npc_items'). So that line becomes "sync off":
-- - Farron Keep's Estus Soup pot (m33 13305470: its glow and "Drink Estus Soup" button 9333 were
--   never on a joined player's game, seen 2026-10-16), each player drinking alone;
-- - the graves' "Offer flame" and "Read epitaph" (common_func 20005510, 21 in the Road of
--   Sacrifices, the Cathedral and the Catacombs; the event audit of 2026-10-16): the player lights
--   one and reads it on its own game; its flag reaches the host's as the player's flags do, whose
--   grave shows it lit from its next load;
-- - Anri's ceremony in Irithyll (m37 13705644: the Sword of Avowal offered at the altar, 3 Dark
--   Sigils, Anri's and Yuria's story steps 1349/1358 and 1565/1578, network flags): with sync on,
--   the host's game standing there with its own sword would run it too. Its jump past the trade
--   for a world not its own (line 26) is in for_players, so the player's own sword is taken and
--   its own sigils given, and the story steps reach the host's game (players move NPC stories
--   too, 2026-10-16);
-- - the Undead Settlement's cage carrier (m31 13105320; host_solo): its first jump for a session
--   (line 7, before its wait) becomes "sync off", so one player's "Examine" carries only it;
-- - a grave's epitaph read (common_func 20005511, beside 20005510): with a joined player's game
--   now past "in its own world" (single_player.lua), one player's button turned every player to
--   the grave and showed them all the epitaph; its own-world condition (line 12) becomes "sync
--   off" (the effect-reach sweep, 2026-10-19);
-- - an item a dying player loses (m33 13300761: goods 388 taken from a player who dies while
--   the NPC 3300720 fights): with the sync on, one player's death took the other's too; its
--   own-world end (line 0) becomes "sync off" (the same sweep);
-- - walking into a boss's fog (common_func 20005800 line 12, Wolnir's m38 13805857 line 4) and the
--   chapel's fog past Vordt (m30 13005890 line 54): with every player's game now running the
--   host's fog event, one player's press walked every player into the fog where it stood; each
--   player walks in on its own press, as alone, its network flag (the fog's "entered") still
--   reaching every game (the same sweep);
-- - what a player's own place does to it (the same sweep): the Undead Settlement's area that
--   sets an effect and animation on the player in it (m31 13105330), the Farron swamp's ground
--   that sets an effect on the player standing on it (m33 13305100) and Irithyll's areas that
--   set one on the player in them (m37 13705110): with the sync on, one player in the place gave
--   it to every player; each own-world end (line 0) becomes "sync off".
--
-- - a ladder kicked down (common_func 20005640, its own-world condition, line 5; objects.lua took
--   it out before): the kick turns "the player" to the ladder with its animation (60210), so with
--   the sync on one player's kick kicked every player (found sweeping after the thrones, shared_pulls,
--   2026-10-19). The kicker's game runs it alone; the others' wait ends on the ladder's network flag
--   and restarts into its "already down" branch (restarts.lua), the ladder down and climbable;
-- Rows: map, event, the line made sync off: {line, bank, index, {its first argument bytes}},
-- numbered from 0 as the game's event files and the Kindle Events extension show them.
return {
  {"m33_00_00_00", 13305470, {0, 1003, 13, {0, 1}}},
  {"common_func", 20005510, {12, 3, 26, {1, 0}}},
  {"m37_00_00_00", 13705644, {1, 3, 26, {1, 0}}},
  {"m31_00_00_00", 13105320, {7, 1003, 105, {1, 2}}},
  {"common_func", 20005511, {12, 3, 26, {1, 0}}},
  {"m33_00_00_00", 13300761, {0, 1003, 13, {0, 1}}},
  {"common_func", 20005800, {12, 3, 26, {1, 0}}},
  {"m38_00_00_00", 13805857, {4, 3, 26, {1, 0}}},
  -- (mp_seals takes out its line 54, the "go to 2 if not in its own world": inserted before 55.)
  {"m30_00_00_00", 13005890, {55, 3, 24, {0x00, 0x00, 0x00, 0x00, 0x22, 0xCE, 0x2D, 0x00}, before = true}},
  {"m31_00_00_00", 13105330, {0, 1003, 13, {0, 1}}},
  {"m33_00_00_00", 13305100, {0, 1003, 13, {0, 1}}},
  {"m37_00_00_00", 13705110, {0, 1003, 13, {0, 1}}},
  {"common_func", 20005640, {5, 3, 26, {1, 0}}},
}
