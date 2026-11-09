-- Walls and a talk only the host's world had (map events), each read from the game's event and
-- changed checked, all or nothing. Lines numbered from 0 as the game's event files and the Kindle
-- Events extension show them.
return function(lib)
  local edited = 0

  -- Map events that turn off walls only in the host's own world, so a joined player found them in
  -- its way. Firelink Shrine's entrance (m40 14005102): two fog wall objects (4001101, 4001102),
  -- invisible and solid as the map has them, which the event turns off as the map loads and, in
  -- the host's world, on again with their fog while it's in a session (it seals the shrine in
  -- vanilla co-op); it ended at once in a world not the player's own, leaving them on (an
  -- invisible wall at the shrine's entrance). Every game turns them off first: the "turn off"
  -- lines after its "end if not in its own world" (1003[13]; (De)activate Object 2005[03], state 0
  -- at byte 4) are copied before it. And that line becomes "sync off" (single_player.lua has every
  -- game run the event): its walls go up while a player stands on the shrine's floor (hit 4004100)
  -- and come down 18-20 s after it's off it, each game's by its own player's place; with the sync
  -- on, either player on that floor held them up on both games (seen: the host's walls stayed
  -- up long after; 2026-10-19).
  local script = lib.script("m40_00_00_00", 14005102)
  local end_if_not_own
  for line = 0, (script and script.line_count or 0) - 1 do
    if script.lines[line].bank == 1003 and script.lines[line].index == 13 then
      end_if_not_own = line
      break
    end
  end
  if end_if_not_own then
    local steps = { { replace = end_if_not_own, is = { 1003, 13 }, bank = 2000, index = 2, format = "i", values = { 0 } } }
    local line = end_if_not_own + 1
    local function turns_object_off(command)
      return command.bank == 2005 and command.index == 3 and command.bytes[5] == 0
    end
    while line < script.line_count and turns_object_off(script.lines[line]) do
      local command = script.lines[line]
      steps[#steps + 1] = { insert = end_if_not_own, bank = 2005, index = 3, format = string.rep("B", #command.bytes), values = command.bytes, layer_of = line }
      line = line + 1
    end
    lib.edit("m40_00_00_00", 14005102, steps, "walls the host's world turns off are turned off in any world")
    edited = edited + 1
  end

  -- The multiplayer fog walls, kept off. Past their first lines (up to the wall turned off and its
  -- fog taken away) each event waits for multiplayer state 3 or 2, puts the wall up (the fog wall
  -- objects o000400/o000401) with its fog, waits for neither, and starts again; alone it's never
  -- up. Those lines come out (the event as long as the game has it, a multiplayer state test,
  -- 3[06], among them). Found by the game data index:
  -- - common_func 20005780: 22 of them in ten maps;
  -- - m30 13005350: the High Wall chapel's fog (3001890) once its boss is dead (13000890);
  -- - m32 13205490: two at Archdragon Peak (3201785, 3201786) once 13200850 is set;
  -- - m37 13705350 and 13705351: Irithyll's (3701785) and, near it, its fog;
  -- - m38 13804829: the Old Demon King's (3801800), up on a game not in its own world and, the
  --   boss dead, in multiplayer states 2 and 3; alone the fight has no wall.
  -- Rows: map, event, keep = the lines kept, length = the event's length in the game's file.
  local walls_off = {
    {"common_func", 20005780, keep = 3, length = 12},
    {"m30_00_00_00", 13005350, keep = 4, length = 13},
    {"m32_00_00_00", 13205490, keep = 3, length = 14},
    {"m37_00_00_00", 13705350, keep = 2, length = 10},
    {"m37_00_00_00", 13705351, keep = 2, length = 16},
    {"m38_00_00_00", 13804829, keep = 3, length = 23},
  }
  for _, row in ipairs(walls_off) do
    local map, id = row[1], row[2]
    local wall_script = lib.script(map, id)
    local tests_multiplayer_state = false
    for line = row.keep, (wall_script and wall_script.line_count or 0) - 1 do
      local command = wall_script.lines[line]
      tests_multiplayer_state = tests_multiplayer_state or (command.bank == 3 and command.index == 6)
    end
    if wall_script and wall_script.line_count == row.length and tests_multiplayer_state then
      local steps = {}
      for line = row.keep, wall_script.line_count - 1 do
        steps[#steps + 1] = { cut = line, is = { wall_script.lines[line].bank, wall_script.lines[line].index } }
      end
      lib.edit(map, id, steps, "the multiplayer fog walls stay off")
      edited = edited + 1
    else
      kindle.log.warn("event %s %d isn't as expected: its multiplayer wall stays", map, id)
    end
  end

  -- Walls only the host's world raises and lowers, which every world now does as the host's. The
  -- Ringed City's below the Ringed Inner Wall (fog wall 5101850, solid as the map has it; m51
  -- 15105505): up with its fog until 15100200 (a network set, when 5100200 has SpEffect 5028, m51
  -- 15105232), then off; it ended at once in a world not the player's own, leaving a joined
  -- player an invisible wall there for good. Its "end if not in its own world" comes out. Every
  -- event that turns a fog wall object (o000400..o000402) on or off after an own-world check was
  -- checked (2026-10-15): these two, the chapel's (mp_seals) and Irithyll's Small Doll barrier
  -- (m37 13705540), which a joined player's game turns off.
  lib.cut_rows({
    {"m51_00_00_00", 15105505, {1, 1003, 13, {0, 1}}},
  }, "walls the host's world turns off are turned off in any world")
  edited = edited + 1

  -- The Cathedral of the Deep: m35 13505785 ends at once in the game's own world; in another it
  -- sets flag 13500785 once flags 1361 and 1375 are on, and an action button (3501700, "Talk", a
  -- talk script's) is off while it's on (its invalidFlag): the host could talk there, a joined
  -- player couldn't (found by the game data index, 2026-10-15). The event only sets the flag off
  -- now (its line 1), in any world.
  script = lib.script("m35_00_00_00", 13505785)
  if script and script.line_count > 2 then
    local steps = {
      { cut = 0, is = { 1003, 13, 0, 0, 0, 0 } },
      { check = 1, is = { 2003, 2, 0x71, 0x01, 0xCE, 0x00, 0, 0, 0, 0 } }, -- flag 13500785 off
    }
    for line = 2, script.line_count - 1 do
      steps[#steps + 1] = { cut = line, is = { script.lines[line].bank, script.lines[line].index } }
    end
    lib.edit("m35_00_00_00", 13505785, steps, "a talk the host can use in the Cathedral, a player can too")
    edited = edited + 1
  end
  return edited
end
