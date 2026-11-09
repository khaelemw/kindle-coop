-- The game's events play as single player's, with a friend there (2026-10-19: "it
-- should play exactly like the original"; nothing filtered out but OWN_INPUTS below). Two of the events' tests tell a
-- session apart, and Kindle asks a mod about each where the game makes it:
--
-- - "In its own world" (events.own_world_test): taken 480 times; on a joined player's game each
--   ended or waited there, so what the host's world did (characters, objects, flags, sights and
--   sounds, and what a player gets) happened on the host's game alone. A joined player's game now
--   answers as the host's; with the session's flags (the host's) in use, it comes to what the
--   host's does.
-- - The multiplayer state (events.multiplayer_state_test): in a session the game's events skipped
--   boss intro cutscenes, raised the multiplayer fog walls, sent players home at a dead boss's fog
--   and kept a guest's game from starting its own progress events. Every game now answers as a
--   game alone does (and a game alone is answered as it would be anyway).
--
-- Noted, not left out (the effect-reach sweep, local notes REACH_PERSONAL.tsv): where an event
-- keeps the game's network sync on, a condition one player meets holds on every game, so what it
-- does to "the player" happens to each game's own player: the NPC talk gestures (common_func
-- 20006000-20006008: the player turned to the NPC), a dialog, an item taken, an award, a cutscene
-- with a warp. Watch for those in play.
local net, game = kindle.net, kindle.game

-- Left as the game has it for now: the Path of the Dragon (m39 13905900). Its tests stay the
-- game's. The Dancer's cutscene and warp (common 710, after Aldrich and Yhorm fall: 9314, 9318)
-- is answered as the others (2026-10-19): it ended at once on a joined player's game
-- (line 0) and waited on "in its own world" (line 4), so the player got neither. It keeps
-- the game's network sync on, so whoever walks into the area first starts it on every game: each
-- plays the cutscene and warps its own player to the High Wall, as Wolnir's goblet does (for_players).
local USERS_TO_FIX = { [13905900] = true }

-- Events that set the world's flags from flags each player keeps as its own (the 6000s, the
-- pickups' 5s, the merchants' 7s: flags.lua): run on a player's game, they computed the world's
-- flag from that player's own progress, not the host's. Their tests stay the game's, so the host's
-- game decides those flags for everyone, as in the original. Event 9020 (the Painted World's way
-- in, from 6952) keeps the game's network sync on: on two games on one PC the host's run and the player's
-- fought, the player's game setting 14500161 off and on again 23 times a second, each set sent
-- to the host (2026-10-19). Found by sweeping the own-world events with world effects for
-- conditions on such flags, literal or passed as a parameter: common 9006, 9011, 9015, 9020, 9104,
-- 9120 and common_func 20005493 (two characters turned hostile on the player's own 50006250),
-- 20005494 (network flags from the player's pickups), 20006020 (Firelink's 70000100s, the stock
-- from ashes the player gave).
local OWN_INPUTS = {
  [9006] = true, [9011] = true, [9015] = true, [9020] = true, [9104] = true, [9120] = true,
  [20005493] = true, [20005494] = true, [20006020] = true,
}

-- Events where the world's game decides what the world's NPCs do, which a joined player's game
-- should only show (80): each jumps past its own lines in a world not its own ("GOTO IF not in its
-- own world"), and the lines it jumps past set the NPCs' state with network-connected flags, from
-- what that game sees: the NPC's story flags, whether the NPC is loaded near the player (Character
-- Backread Status), its HP, the player's own world. In the original the world owner's game decides
-- and the others show it (with the event's sync on, the owner's condition holds on every game, and
-- the others jump to what follows). Answered as the host's, a joined player's game decided too,
-- from where its own player stood, and sent its answer to every game: NPCs left or came back as
-- a joined player stood on Firelink's roof, and Ludleth (m40 14005640) was gone from the joined player's
-- Firelink (2026-10-19). Their test stays the game's. Found by listing every own-world jump that
-- passes over network-connected sets (local re/tools/goto_sweep.py), leaving out the boss fogs
-- (20005800, Wolnir's, the Dancer's: each player walks in itself) and the events this mod edits
-- for the NPCs' stories (events/npcs.lua, player_steps.lua) and Anri's ceremony.
local WORLD_DECIDERS = {
  -- common_func
  [20006003] = true,
  -- m30_00_00_00
  [13005600] = true, [13005620] = true,
  -- m31_00_00_00
  [13105600] = true, [13105620] = true, [13105640] = true, [13105660] = true, [13105680] = true,
  [13105700] = true, [13105710] = true, [13105720] = true, [13105740] = true,
  -- m33_00_00_00
  [13305700] = true, [13305720] = true, [13305740] = true, [13305746] = true, [13305760] = true,
  -- m34_01_00_00
  [13415600] = true, [13415620] = true, [13415640] = true,
  -- m35_00_00_00
  [13505600] = true, [13505700] = true, [13505720] = true, [13505740] = true, [13505750] = true,
  [13505760] = true, [13505780] = true, [13500786] = true,
  -- m37_00_00_00
  [13705620] = true, [13705630] = true, [13705640] = true, [13700643] = true, [13705645] = true,
  [13705660] = true,
  -- m38_00_00_00
  [13805700] = true, [13805701] = true, [13805703] = true, [13805706] = true,
  -- m39_00_00_00
  [13905700] = true, [13905720] = true,
  -- m40_00_00_00
  [14005500] = true, [14005520] = true, [14005540] = true, [14005542] = true, [14005560] = true,
  [14005570] = true, [14005580] = true, [14005586] = true, [14005600] = true, [14005620] = true,
  [14005640] = true, [14005660] = true, [14005680] = true, [14005683] = true, [14005700] = true,
  [14005720] = true, [14005740] = true, [14005750] = true, [14005760] = true, [14005780] = true,
  -- m45_00_00_00
  [14505700] = true, [14505710] = true, [14505712] = true, [14505730] = true, [14505740] = true,
  [14505750] = true, [14505770] = true, [14505780] = true,
  -- m50_00_00_00
  [15005444] = true, [15005700] = true, [15005702] = true, [15005720] = true,
  -- m51_00_00_00
  [15105700] = true, [15105710] = true, [15105712] = true, [15105720] = true, [15105722] = true,
  [15105730] = true, [15105740] = true,
  -- m51_01_00_00
  [15115700] = true,
}

game.on_decide("events.own_world_test", function(event_id)
  if net.role() ~= "player" or USERS_TO_FIX[event_id] or OWN_INPUTS[event_id] or WORLD_DECIDERS[event_id] then return nil end
  local state = net.state()
  if state ~= "joining" and state ~= "joined" then return nil end
  return "own_world"
end)

game.on_decide("events.multiplayer_state_test", function(event_id)
  if USERS_TO_FIX[event_id] then return nil end
  return "single_player"
end)
