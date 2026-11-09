-- Doors and a barrier, read from the game's events and changed checked, all or nothing. Lines
-- numbered from 0 as the game's event files and the Kindle Events extension show them.
return function(lib)
  local edited = 0

  -- A plain "set flag" (2003[02], 8 bytes) made the network-connected set (2003[62], the same
  -- arguments and argument entries).
  local function network_set_step(script, line)
    local command = script and script.lines[line]
    if not (command and command.bank == 2003 and command.index == 2 and #command.bytes == 8) then return nil end
    return { replace = line, is = { 2003, 2 }, bank = 2003, index = 62, format = "BBBBBBBB", values = command.bytes, keep_params = true }
  end

  -- A door opened (common_func 20005611) and a locked door unlocked (20005613) set their flag with a
  -- plain "set flag", the game's own only: a door a joined player opened was open on its screen
  -- alone. It becomes the network-connected set, which reaches the other players (from a player,
  -- through the host: flags.lua). The locked door also ends at once, and counts the unlock only,
  -- in its own world: those come out, so a player opens it with its own key as the host does
  -- (user, 2026-10-12).
  local COMMON_FUNC = "common_func"
  local door = network_set_step(lib.script(COMMON_FUNC, 20005611), 8)
  if door then
    lib.edit(COMMON_FUNC, 20005611, { door }, "doors opened and unlocked are shared, by any player")
    edited = edited + 1
  else
    kindle.log.warn("event %s %d isn't as expected: its flag stays the game's own", COMMON_FUNC, 20005611)
  end
  local locked_door = network_set_step(lib.script(COMMON_FUNC, 20005613), 6)
  if locked_door then
    lib.edit(COMMON_FUNC, 20005613, {
      locked_door,
      { cut = 0, is = { 1003, 13, 0, 1, 0, 0 } },
      { cut = 2, is = { 3, 26, 1, 0, 0, 0 } },
    }, "doors opened and unlocked are shared, by any player")
    edited = edited + 1
  else
    kindle.log.warn("event %s %d isn't as expected: its flag stays the game's own", COMMON_FUNC, 20005613)
  end

  -- Irithyll's Small Doll barrier: whoever has a Small Doll first opens it for every player (user,
  -- 2026-10-18; both players will have fought for the doll). m37, both events with their sync off
  -- (each game runs them for its own player); 13700540 is the world's "barrier passed", a flag the
  -- game shares.
  -- 13705540 (the wall): 0 sync off, 1 "go to label 0 if not in its own world", 2 "go to label 0 if
  -- 13700540", 3 the wall (3701540) up, 4 wait until this player has a Small Doll (goods 2005),
  -- 5 set 13700540 (plain: this game only), 6 label 0, 7 the wall off. A joined player's game
  -- skipped the barrier. Now: line 1 out (every game checks the world's flag, as the host's does);
  -- the wait ends on this player's doll or on 13700540 (another player's doll; condition group -1);
  -- the set is network-connected, so it reaches the others.
  -- 13705541 (the message): 0 sync off, 1 "end if not in its own world", 2 "end if 13700540", then
  -- the wall's action button (9310) with no doll in group 1 shows "a Small Doll is needed". Now:
  -- line 1 out (a joined player is told why too), and group 1 also needs 13700540 off (the
  -- message isn't shown once someone has opened it).
  local IRITHYLL, PASSED, DOLL, ANY_OF = "m37_00_00_00", 13700540, 2005, 0xFF -- condition group -1
  local wall = lib.script(IRITHYLL, 13705540)
  local wall_lines = wall and wall.lines
  local wall_as_expected = wall_lines
    and wall_lines[1].bank == 1003 and wall_lines[1].index == 12
    and wall_lines[2].bank == 1003 and wall_lines[2].index == 101 and wall_lines[2].args[2] == PASSED
    and wall_lines[4].bank == 3 and wall_lines[4].index == 4 and wall_lines[4].bytes[1] == 0 and wall_lines[4].args[2] == DOLL
    and not lib.group_used(wall, ANY_OF)
  local passed_set = wall_as_expected and network_set_step(wall, 5)
  if passed_set then
    local doll_bytes = { table.unpack(wall_lines[4].bytes) }
    doll_bytes[1] = ANY_OF
    lib.edit(IRITHYLL, 13705540, {
      { cut = 1, is = { 1003, 12 } },
      { check = 2, is = { 1003, 101 } },
      { replace = 4, is = { 3, 4, 0 }, bank = 3, index = 4, format = string.rep("B", #doll_bytes), values = doll_bytes, keep_params = true },
      { insert = 5, bank = 3, index = 0, format = "BBBBi", values = { ANY_OF, 1, 0, 0, PASSED }, layer_of = 4 },
      { insert = 5, bank = 0, index = 0, format = "BBBB", values = { 0, 1, ANY_OF, 0 }, layer_of = 4 },
      passed_set,
    }, "Irithyll's barrier opens for every player once one has a Small Doll")
    edited = edited + 1
  else
    kindle.log.warn("event %s %d isn't as expected: Irithyll's barrier stays the game's", IRITHYLL, 13705540)
  end
  local message = lib.script(IRITHYLL, 13705541)
  local message_lines = message and message.lines
  if message_lines and message_lines[1].bank == 1003 and message_lines[1].index == 13
    and message_lines[4].bank == 3 and message_lines[4].index == 4 and message_lines[4].bytes[1] == 1 then
    lib.edit(IRITHYLL, 13705541, {
      { cut = 1, is = { 1003, 13 } },
      { check = 4, is = { 3, 4, 1 } },
      { insert = 5, bank = 3, index = 0, format = "BBBBi", values = { 1, 0, 0, 0, PASSED }, layer_of = 4 },
    }, "Irithyll's barrier opens for every player once one has a Small Doll")
    edited = edited + 1
  else
    kindle.log.warn("event %s %d isn't as expected: Irithyll's barrier message stays the game's", IRITHYLL, 13705541)
  end
  return edited
end
