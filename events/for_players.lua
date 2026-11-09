-- What a player gets alone, in a map's own events, that ended at once in a world not the
-- player's own (a white phantom's to the game): (map, event, the lines to take out). The
-- Consumed King's Garden's gesture (m30 13000901: a glow on an object, its action button, then
-- an NPC's talk gives the gesture): it already ends for a player who has the gesture (6079), so
-- with "in its own world" out each player gets its own. Two enemies' death awards likewise (see
-- Kindle's loot list): m30 13000380 (its taken flag 6780, each player's own with the 6000s) and m37 13705260
-- (53700990). And the unique items an event hands out at Firelink and in Irithyll Dungeon, each
-- with its game's event sync off (the presser's game alone runs it): the Ashen Estus Flask (m40
-- 14000130: taken 6010, its lot by the character's NG cycle 6021..6030, all among the
-- character's own 6000s now, coop.rs OWN_THOUSAND), the Way of White Circlet (m40 14005461: not
-- for a character that has it) and the Undead Bone Shard with the gesture (m39 13900900: lot flag
-- 53900900 and gesture 6073, a player's own; the event's own done flag is the world's, so one
-- the host took is the host's world's, and the player takes it in its own), and the Storm
-- Ruler's second copy in Yhorm's arena (m39 13905870, sync off: for a character that took the
-- first, its own 53900810, and has none now). And what an NPC's
-- story gives, which every player gets when one does, each its own (user, 2026-10-14), by its
-- lot's own pickup flag: Emma's Basin of Vows (m30 13005601, on her talk's flag 73000181), the
-- Mound-makers' covenant item (m31 13105721, taken 6710), the Twinkling Dragon Torso Stone (m33
-- 13305762), the Grand Archives' Titanite Slab for its three (m34_01 13410300), Leonhard's end
-- (m37 13700156: the Black Eye Orb taken, the Soul of Rosaria given) and the Sword of Avowal (m37
-- 13705647, on 73700330). None turns its event's sync off, so its conditions hold on every game
-- at once (and the NPCs' story flags are the host's world's, story_flags.rs). Found by the event
-- audit of 2026-10-16 (over the edited files: every award still behind an own-world test), each
-- by its lot's own pickup flag or its event's own done flag: the
-- High Wall dragon's Large Titanite Shard as it flees (m30 13005481, lot 31410000, 53000985; a
-- joined player got none), the Path of the Dragon's two rewards on Archdragon Peak (m32 13205910,
-- 53200900 and 53200910), the Cathedral's drop of 3500668 (m35 13500276, 6781), the Fire Keeper's
-- soul as she dies (m40 14005602, 50006020), and Ariandel's: the two knights' Titanite (m45
-- 14505200, 14505210, the event's done flag 14500200), 14505495 (done flag 14500495), the NPC's
-- gift on 1658 (14505703, 50006520), the Champion's Gravetender (14505812, 50004700) and
-- 14505880 (50006910). And the Shrine Handmaid's stock a world event unlocks, which every player
-- gets by its own flag (the 7s outside the NPC stories are each character's own): the Exile set
-- once the Farron Keep exiles are dead (m40 14005684 on 13300396..97, sets 70000119; a joined
-- player could buy none though the host could) and 70000118 (m40 14005571, on 1124, 9303, 9314).
-- And two bosses whose defeat event waits on "in its own world" with the death, unlike the other
-- 24 (every boss's sets its world flag and the player's own 63xx, Ludleth's transposition of its
-- soul, on every game): Archdragon Peak's 3200851 (m32 13200862, 6304) and Smouldering Lake's
-- 3800800 (m38 13800800, 6315); a player could take neither boss's soul to Ludleth.
-- And Wolnir's goblet (m38 13805809): its wait needed the player in its own world with the
-- goblet's button (9322), so a joined player's press did nothing (seen 2026-10-16).
-- The event leaves the game's event sync on, so a player's press holds on the host's game too and
-- both play the cutscene and warp; the lines after it (network flag 13805805, Wolnir's authority)
-- stay the host's. And the Estus Soup pots of the Undead Settlement (m31 13105930) and Irithyll
-- (m37 13705520): each event ended at once in a world not the player's own, before the pot's glow
-- and its "Drink Estus Soup" button (9600), so a joined player saw neither (seen
-- 2026-10-16). Their next line turns the game's event sync off, so each game runs it for its own
-- player and one player's drink doesn't play on the others (Farron Keep's pot leaves sync on:
-- Kindle's sync-off list). And Anri's ceremony's jump past the trade in a world not its own (m37
-- 13705644; its own-world condition is Kindle's sync-off list'). And, decided 2026-10-17
-- to the event audit's list (EVENT_AUDIT.md), each waiting or ending on "in its own world":
-- - the Ancient Wyvern's death (m32 13200811): after the defeat (every game) a player alone saw the
--   cutscene and was taken to the summit (3202809, its respawn point the bonfire there): in a world
--   not its own the event ended first, so the host went up and a player stayed below (the warp is
--   no load: the base game's phantoms ride Wolnir's goblet's the same way, so follow.rs doesn't);
-- - placing the Basin of Vows at the High Wall (m30 13005880: Dancer's cutscene and fight early),
--   the Cathedral's scrap of a painting (m35 13505752, story flag 73500339) and talking to Friede
--   (m45 14505810: her cutscene and fight): they leave the game's event sync on, so a player's
--   press holds on the host's game too and both go, as with the goblet;
-- - the NPC summon signs before the Crystal Sage and Friede (m33 13305171, m45 14505831): their
--   sync is off, so the presser's game asks alone; its network flag (13305160, 14505840) brings
--   the NPC in on every game (13305172, 14505832);
-- - the cage carrier in the Undead Settlement (m31 13105320): its cutscene and warp for its own
--   world's player (with Kindle's host-solo list's and Kindle's sync-off list' lines of it).
--
-- Rows: map, event, then the lines to take out: {line, bank, index, {its first argument bytes}},
-- lines numbered from 0 as the game's event files and the Kindle Events extension show them.
return {
  {"m30_00_00_00", 13000901, {0, 1003, 13, {0, 1}}},
  {"m30_00_00_00", 13000380, {0, 1003, 13, {0, 1}}},
  {"m37_00_00_00", 13705260, {4, 1003, 13, {0, 1}}},
  {"m40_00_00_00", 14000130, {1, 1003, 13, {0, 1}}, {4, 3, 26, {1, 0}}},
  {"m40_00_00_00", 14005461, {1, 1003, 13, {0, 1}}},
  {"m39_00_00_00", 13900900, {1, 1003, 13, {0, 1}}},
  {"m39_00_00_00", 13905870, {3, 1003, 13, {0, 1}}},
  {"m30_00_00_00", 13005601, {0, 1003, 13, {0, 1}}},
  {"m31_00_00_00", 13105721, {0, 1003, 13, {0, 1}}},
  {"m33_00_00_00", 13305762, {0, 1003, 13, {0, 1}}},
  {"m34_01_00_00", 13410300, {0, 1003, 13, {0, 1}}},
  {"m37_00_00_00", 13700156, {0, 1003, 13, {0, 1}}},
  {"m37_00_00_00", 13705647, {0, 1003, 13, {0, 1}}},
  {"m30_00_00_00", 13005481, {8, 1003, 12, {0, 1}}},
  {"m32_00_00_00", 13205910, {2, 1003, 13, {0, 1}}, {3, 3, 26, {1, 0}}},
  {"m35_00_00_00", 13500276, {5, 1003, 13, {0, 1}}},
  {"m40_00_00_00", 14005602, {0, 1003, 13, {0, 1}}},
  {"m45_00_00_00", 14505200, {29, 1003, 13, {0, 1}}},
  {"m45_00_00_00", 14505210, {26, 1003, 13, {0, 1}}},
  {"m45_00_00_00", 14505495, {0, 1003, 13, {0, 1}}, {2, 3, 26, {1, 0}}},
  {"m45_00_00_00", 14505703, {0, 1003, 13, {0, 1}}},
  {"m45_00_00_00", 14505812, {11, 1003, 13, {0, 1}}},
  {"m45_00_00_00", 14505880, {0, 1003, 13, {0, 1}}, {2, 3, 26, {1, 0}}},
  {"m40_00_00_00", 14005571, {0, 1003, 13, {0, 1}}},
  {"m40_00_00_00", 14005684, {0, 1003, 13, {0, 1}}},
  {"m32_00_00_00", 13200862, {5, 3, 26, {1, 0}}},
  {"m38_00_00_00", 13800800, {12, 3, 26, {1, 0}}},
  {"m38_00_00_00", 13805809, {16, 3, 26, {1, 0}}},
  {"m31_00_00_00", 13105930, {0, 1003, 13, {0, 1}}},
  {"m37_00_00_00", 13705520, {0, 1003, 13, {0, 1}}},
  {"m37_00_00_00", 13705644, {26, 1003, 12, {5, 1}}},
  {"m32_00_00_00", 13200811, {10, 1003, 13, {0, 1}}},
  {"m30_00_00_00", 13005880, {3, 1003, 13, {0, 1}}},
  {"m35_00_00_00", 13505752, {0, 1003, 13, {0, 1}}},
  {"m45_00_00_00", 14505810, {51, 3, 26, {1, 0}}},
  {"m33_00_00_00", 13305171, {3, 1003, 13, {0, 1}}, {7, 3, 26, {1, 0}}, {17, 3, 26, {2, 0}}},
  {"m45_00_00_00", 14505831, {1, 1003, 13, {0, 1}}, {4, 3, 26, {1, 0}}, {17, 3, 26, {2, 0}}},
  {"m31_00_00_00", 13105320, {30, 1003, 13, {0, 1}}},
}
