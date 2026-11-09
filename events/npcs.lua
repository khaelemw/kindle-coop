-- NPCs' events, each read from the game's event and changed checked, all or nothing. Lines
-- numbered from 0 as the game's event files and the Kindle Events extension show them.
return function(lib)
  local edited = 0
  local COMMON_FUNC = "common_func"

  -- The events that play the NPCs' gestures for a talk (common_func): the NPC turning to the player
  -- and its animation (20006005, 20006006), the player's (20006010) and an effect on the player
  -- (20006011), each waiting on a flag the talk sets and setting the flags the talk then waits on
  -- (the Fire Keeper's Level Up: flag 74000135, her gesture, 74000137 and 74000138, then the
  -- level up screen). Each ends at once in a world not the player's own ("end if not in own
  -- world", 1003[13]), so on a joined player's game its talk waited for ever (Level Up said "Then
  -- touch the darkness within me." and ended). Those lines come out: in a player's own world they
  -- do nothing, and the gestures only move the NPC and the player on that game.
  for _, id in ipairs({ 20006005, 20006006, 20006010, 20006011 }) do
    local script = lib.script(COMMON_FUNC, id)
    local steps = {}
    for line = 0, (script and script.line_count or 0) - 1 do
      if script.lines[line].bank == 1003 and script.lines[line].index == 13 then steps[#steps + 1] = { cut = line, is = { 1003, 13 } } end
    end
    if #steps > 0 then
      lib.edit(COMMON_FUNC, id, steps, "the talk gestures run in any world")
      edited = edited + 1
    end
  end

  -- The NPC's half of a talk gesture (common_func 20006006: the Fire Keeper's for Level Up, X4 the
  -- talk's signal 74000136, X8 "in the gesture" 74000138; two more NPCs at Firelink). As the talk's
  -- signal comes on it sets X8, turns the NPC to the player and waits for that turn to finish, then
  -- waits for the signal off with the NPC's SpEffect 155, or for its 150 (idle) again, plays the
  -- NPC's return animation and waits for it to finish, and clears X8. The talk opens Level Up once
  -- X8 is on and waits for it to be off before the next. All of it is the NPC's: its turn, its
  -- animations and its effects (from its behaviour), which only the host's game runs. In the base
  -- game the event ends at once in a world not the player's own; Kindle lets it run there so the
  -- talk gets X8 (above), and on a player's game it stopped on the NPC's waits with X8 on (each
  -- game's own flag, flags.lua TALKER_ONLY, saved with the character): Level Up opened once,
  -- then never again (a joined player, 2026-10-15). In a world not its own the event does only
  -- the talk's part: X8 off while no talk asks (one left on by a talk cut short is cleared as the
  -- area loads, as the base game's Firelink event 14005600 does at home), then X8 on with the
  -- signal and off with it, and again. In its own world it runs as before.
  local script = lib.script(COMMON_FUNC, 20006006)
  if script then
    -- Whether line `line`'s command takes the event's argument at byte `source`.
    local function takes_argument(line, source)
      for _, param in ipairs(script.parameters) do
        if param.command == line + 1 and param.source == source then return true end
      end
      return false
    end
    -- The first line whose command passes `test(command, line)`.
    local function first_line(test)
      for line = 0, script.line_count - 1 do
        if test(script.lines[line], line) then return line end
      end
    end
    -- The wait for the signal (IF Event Flag, main, on, X4), X8 on (Set Event Flag, state 1), the
    -- signal-off condition (IF Event Flag, group 1, off, X4), and X8 off then the restart.
    local signal_wait = first_line(function(command) return command.bank == 3 and command.index == 0 and command.bytes[1] == 0 and command.bytes[2] == 1 end)
    local gesture_on = first_line(function(command) return command.bank == 2003 and command.index == 2 and command.bytes[5] == 1 end)
    local signal_off_wait = first_line(function(command) return command.bank == 3 and command.index == 0 and command.bytes[1] == 1 and command.bytes[2] == 0 end)
    local gesture_off = first_line(function(command, line)
      local next_command = script.lines[line + 1]
      return command.bank == 2003 and command.index == 2 and command.bytes[5] == 0
        and next_command and next_command.bank == 1000 and next_command.index == 4
    end)
    local has_label_9 = first_line(function(command) return command.bank == 1014 and command.index == 9 end)
    local as_expected = signal_wait and gesture_on and signal_off_wait and gesture_off and signal_wait < gesture_on
      and takes_argument(signal_wait, 4) and takes_argument(gesture_on, 8) and takes_argument(signal_off_wait, 4)
      and takes_argument(gesture_off, 8) and not lib.inside_skip(script, signal_wait) and not has_label_9
    if as_expected then
      local tail = script.line_count
      -- The tail: label 9; (main) signal off; X8 off; (main) signal on; X8 on; (main) signal off;
      -- X8 off; restart. At its start: to the tail in a world not its own.
      lib.edit(COMMON_FUNC, 20006006, {
        { insert = tail, bank = 1014, index = 9, layer_of = gesture_on },
        lib.copy_step(script, signal_off_wait, tail, { [1] = 0 }),
        lib.copy_step(script, gesture_off, tail),
        lib.copy_step(script, signal_wait, tail),
        lib.copy_step(script, gesture_on, tail),
        lib.copy_step(script, signal_off_wait, tail, { [1] = 0 }),
        lib.copy_step(script, gesture_off, tail),
        lib.copy_step(script, gesture_off + 1, tail),
        { insert = signal_wait, bank = 1003, index = 12, format = "BBBB", values = { 9, 1, 0, 0 }, layer_of = gesture_on },
      }, "an NPC's talk gesture on a player's game follows the talk alone")
      edited = edited + 1
    else
      kindle.log.warn("event %s %d isn't as expected: a player's NPC talk gestures stay on after its first talk", COMMON_FUNC, 20006006)
    end
  end

  -- NPCs a game moves only when its own player gets there, and whose next step assumes it did.
  -- Siegward in the Undead Settlement: m31 13105741 swaps the lift-bottom Siegward (3100730) for the
  -- tower-top one (3100731) as THIS game's player reaches the lift's top (and sets 1382, which
  -- reaches the other games); 13105742, the Fire Demon's fight, then takes its "already swapped"
  -- branch (label 0, line 15) on 1382 and sets the tower-top one fighting, never enabling it. On a
  -- game whose player didn't ride the lift to its top (a joined player jumped off halfway,
  -- 2026-10-15) the tower-top Siegward stayed disabled: only the host saw him fight the Fire Demon.
  -- The branch now does the swap too (copies of its own lines 10..13, enable and backread 2004[05]
  -- and 2004[29], from the branch that sets 1382, without the warp): on the game that did the swap
  -- nothing changes.
  local UNDEAD_SETTLEMENT = "m31_00_00_00"
  script = lib.script(UNDEAD_SETTLEMENT, 13105742)
  local function line_is(line, bank, index)
    return script.lines[line] and script.lines[line].bank == bank and script.lines[line].index == index
  end
  local as_expected = script and line_is(15, 1014, 0)
  for line = 10, 13 do
    as_expected = as_expected and (line_is(line, 2004, 5) or line_is(line, 2004, 29))
  end
  if as_expected then
    local steps = { { check = 15, is = { 1014, 0 } } }
    for line = 10, 13 do steps[#steps + 1] = lib.copy_step(script, line, 16) end
    lib.edit(UNDEAD_SETTLEMENT, 13105742, steps, "an NPC one game moved, the others move as it goes on")
    edited = edited + 1
  else
    kindle.log.warn("event %s %d isn't as expected: an NPC another game moved stays where this game left it", UNDEAD_SETTLEMENT, 13105742)
  end

  -- NPC story steps the host's player starts: the line of its "in its own world" test that starts
  -- its wait (3[26] 1 0), the flag the host's game sets for the step, and the label of the event's
  -- own branch for a game not in its own world. That branch goes past the world's flags to the
  -- NPC's move, but the wait before it needs the player in its own world, so on a joined player's
  -- game the NPC stayed as it was until a load: Unbreakable Patches stood where the host's game had
  -- taken him away, and a joined player's hits on him did nothing (2026-10-16). In a world not
  -- its own the event now waits for the host's flag instead and takes that branch (before the
  -- test: "go to label 9 if in its own world", "wait for the flag", "go to the branch", label 9).
  -- Unbreakable Patches: the Cathedral's trap (its flags X0..X8; its branch for a game not in its
  -- own world plays the trap's cutscene with a warp, so the label after it) and his moves (1362,
  -- 1363), then Firelink (1364, 1365); and the Ringed City's NPCs.
  -- Rows: map, event, at = the test's line, flag = the host's flag (a number, or {arg = byte}: the
  -- event's argument there), branch = the label of the branch.
  local host_steps = {
    {"m35_00_00_00", 13500783, at = 1, flag = {arg = 0}, branch = 1},
    {"m35_00_00_00", 13500781, at = 1, flag = 1362, branch = 0},
    {"m35_00_00_00", 13500782, at = 1, flag = 1363, branch = 0},
    {"m40_00_00_00", 14000621, at = 18, flag = 1364, branch = 0},
    {"m40_00_00_00", 14000622, at = 1, flag = 1365, branch = 0},
    {"m51_00_00_00", 15105711, at = 1, flag = 1808, branch = 0},
    {"m51_00_00_00", 15105713, at = 1, flag = 1811, branch = 0},
    {"m51_00_00_00", 15105721, at = 1, flag = 1821, branch = 0},
  }
  for _, row in ipairs(host_steps) do
    local map, id, at = row[1], row[2], row.at
    script = lib.script(map, id)
    local test = script and script.lines[at]
    local has_branch = false
    for line = at, (script and script.line_count or 0) - 1 do
      has_branch = has_branch or (script.lines[line].bank == 1014 and script.lines[line].index == row.branch)
    end
    local flag_is_argument = type(row.flag) == "table"
    local params = script and flag_is_argument and lib.param_length(script, row.flag.arg)
      and { { target = 4, source = row.flag.arg, length = lib.param_length(script, row.flag.arg) } } or nil
    local step_as_expected = test and test.bank == 3 and test.index == 26 and test.bytes[1] == 1 and test.bytes[2] == 0 and has_branch
      and not lib.label_used(script, 9) and not lib.inside_skip(script, at) and (not flag_is_argument or params)
    if step_as_expected then
      lib.edit(map, id, {
        { check = at, is = { 3, 26, 1, 0 } },
        { insert = at, bank = 1003, index = 12, format = "BBBB", values = { 9, 0, 0, 0 }, layer_of = at },
        { insert = at, bank = 3, index = 0, format = "BBBBi", values = { 0, 1, 0, 0, flag_is_argument and 0 or row.flag }, params = params, layer_of = at },
        { insert = at, bank = 1000, index = 103, format = "BBBB", values = { row.branch, 0, 0, 0 }, layer_of = at },
        { insert = at, bank = 1014, index = 9, layer_of = at },
      }, "an NPC the host's story moves, moves on every game")
      edited = edited + 1
    else
      kindle.log.warn("event %s %d isn't as expected: an NPC the host's story moves stays as it was on a player's game until a load", map, id)
    end
  end
  return edited
end
