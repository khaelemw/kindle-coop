-- Hollows that turn into a beast (common_func: the High Wall's Pus of Man, 20005417; 20005415 the
-- same way): a hollow and a beast, the beast disabled until the hollow transforms. Each game runs
-- the event for its own player (the hollow stirs when that player comes near or hits it), and once
-- the hollow has transformed it sets the network flag "transformed" (argument X28) and enables the
-- beast. The flag reaches the other games, but the event reads it only as the area loads: on a game
-- whose own player wasn't near, the event went on waiting for its player and the beast stayed
-- disabled, invisible (a joined player near one, the host saw nothing). Each of the event's three
-- waits (IF Condition Group, main <- group G) also ends on the flag now (a condition group of its
-- own, -7, -8, -9: G, or the flag), and then goes to the event's "already transformed" branch
-- (label 0) when the flag is on. Read from the game's event and changed checked, all or nothing.
return function(lib)
  local edited = 0
  local COMMON_FUNC = "common_func"
  -- The condition groups the three waits add (-7, -8, -9), and the "transformed" flag: the event's
  -- argument at byte 28, filled into byte 4 of the commands that test it.
  local GROUPS = { 0xF9, 0xF8, 0xF7 }
  local TRANSFORMED_FLAG = { { target = 4, source = 28, length = 4 } }
  for _, id in ipairs({ 20005415, 20005417 }) do
    local script = lib.script(COMMON_FUNC, id)
    local wait_lines = {}
    for line = 0, (script and script.line_count or 0) - 1 do
      local command = script.lines[line]
      if command.bank == 0 and command.index == 0 and command.bytes[1] == 0 and command.bytes[2] == 1 then wait_lines[#wait_lines + 1] = line end
    end
    local as_expected = #wait_lines == #GROUPS
    for line = 0, (as_expected and script.line_count or 0) - 1 do
      for _, group in ipairs(GROUPS) do as_expected = as_expected and script.lines[line].bytes[1] ~= group end
    end
    if as_expected then
      local steps = {}
      for position = #wait_lines, 1, -1 do
        local wait_line, group = wait_lines[position], GROUPS[position]
        lib.append(steps, {
          -- The wait now waits on `group`: its own group, or the flag; then to the "already
          -- transformed" branch (label 0) when the flag is on.
          { replace = wait_line, is = { 0, 0, 0, 1 }, bank = 0, index = 0, format = "BBBB", values = { group, 1, script.lines[wait_line].bytes[3], 0 } },
          { insert = wait_line + 1, bank = 3, index = 0, format = "BBBBi", values = { group, 1, 0, 0, 0 }, params = TRANSFORMED_FLAG, layer_of = wait_lines[1] },
          { insert = wait_line + 1, bank = 0, index = 0, format = "BBBB", values = { 0, 1, group, 0 }, layer_of = wait_lines[1] },
          { insert = wait_line + 1, bank = 1003, index = 101, format = "BBBBi", values = { 0, 1, 0, 0, 0 }, params = TRANSFORMED_FLAG, layer_of = wait_lines[1] },
        })
      end
      lib.edit(COMMON_FUNC, id, steps, "a hollow's beast is out on every game once one game has it")
      edited = edited + 1
    else
      kindle.log.warn("event %s %d isn't as expected: its beast stays its own game's", COMMON_FUNC, id)
    end
  end
  return edited
end
