-- The game's common events, each read from the game's event and changed checked, all or nothing.
-- Lines numbered from 0 as the game's event files and the Kindle Events extension show them.
return function(lib)
  local edited = 0
  local COMMON = "common"
  local GESTURE_GIFTS = { 9520, 9525, 9530, 9540 }

  -- The gestures an NPC teaches (common 9520, 9525, 9530, 9540: NPCs the host summoned, near their
  -- bosses): the event waits for its flag (the NPC summoned, or met), has the NPC make the gesture
  -- (an AI command), waits for the NPC's effect of it, then gives the gesture once (Award Gesture
  -- Item, 2003[77], and the player's own 6000s flag). Common event 0 starts them after its end for
  -- a guest (below) and each ends at once in a world not its own (9540 also waits on "in its own
  -- world"), so only the host learnt them; the NPC is the host's game's, so its gesture's effect
  -- isn't a joined player's to wait on either. In a world not its own each now goes from its flag
  -- straight to the gift (the NPC's gesture is the host's game's to make): its "end if not in its
  -- own world" (line 0) and "in its own world" conditions (3[26] x 0) come out, and after its
  -- first wait (a main-group condition) "go to label 9 if not in its own world" goes to a label 9
  -- before the gift's "end if it has it" (1003[02]).
  for _, id in ipairs(GESTURE_GIFTS) do
    local script = lib.script(COMMON, id)
    local first = script and script.lines[0]
    local as_expected = first and first.bank == 1003 and first.index == 13 and first.bytes[1] == 0 and first.bytes[2] == 1
      and not lib.label_used(script, 9)
    local steps, cut = {}, {}
    if as_expected then
      steps[1], cut[0] = { cut = 0, is = { 1003, 13, 0, 1 } }, true
      for line = 1, script.line_count - 1 do
        local command = script.lines[line]
        if command.bank == 3 and command.index == 26 and command.bytes[2] == 0 then
          steps[#steps + 1], cut[line] = { cut = line, is = { 3, 26, command.bytes[1], 0 } }, true
        end
      end
      -- The lines kept, in order (the event as it will be, for the waits and the gift): kept[k] is
      -- the game's line number of the k-th line kept.
      local kept = {}
      for line = 0, script.line_count - 1 do
        if not cut[line] then kept[#kept + 1] = line end
      end
      local wait, gift
      for position, line in ipairs(kept) do
        local command = script.lines[line]
        if not wait and (command.bank == 0 or command.bank == 3) and command.bytes[1] == 0 then wait = position end
        if not gift and command.bank == 2003 and command.index == 77 then gift = position end
      end
      local before_gift = gift and gift > 1 and script.lines[kept[gift - 1]]
      as_expected = wait and gift and before_gift and before_gift.bank == 1003 and before_gift.index == 2 and wait + 1 < gift - 1
        and not lib.inside_skip(script, kept[wait + 1]) and not lib.inside_skip(script, kept[gift - 1])
      if as_expected then
        steps[#steps + 1] = { insert = kept[gift - 1], bank = 1014, index = 9, layer_of = kept[wait] }
        steps[#steps + 1] = { insert = kept[wait + 1], bank = 1003, index = 12, format = "BBBB", values = { 9, 1, 0, 0 }, layer_of = kept[wait] }
        lib.edit(COMMON, id, steps, "every player learns the gestures the NPCs teach")
        edited = edited + 1
      end
    end
    if not as_expected then kindle.log.warn("event %s %d isn't as expected: only the host learns that NPC's gesture", COMMON, id) end
  end

  -- A boss's soul: common event 970, one per boss (X0 the boss's defeat flag, X4 the soul's item
  -- lot), awards the lot on its own game as the flag comes on (2003[36], the award with the
  -- multiplayer checks off). The game's common event 0 starts the 26 of them, and the NPCs'
  -- gesture gifts (above), after "end if multiplayer state 1" (1003[06] 0 1: a guest,
  -- EcTestMultiplayState +0x7A5760, Session_IsGuest), so a joined player's game never did, and a
  -- player got no boss soul (a joined player, 2026-10-15). The rest after that line stays the
  -- host's: area and boss achievements and the "killed in own world" records (130, 250, 6100: each
  -- with its own own-world test) and the world's progress (the 9000s). Their starts (2000[00] of
  -- 970 and the gifts) move up, past the game's other end there (1003[02], flag 2052) and before
  -- the guest's: a host's game starts the same events with the same two ends, and a player's game
  -- starts its own boss souls and gifts. Each player's lot has its own taken flag. (Event 0 has
  -- only starts and ends, and no argument entries.)
  local script = lib.script(COMMON, 0)
  local function line_is(line, bank, index)
    return script.lines[line].bank == bank and script.lines[line].index == index
  end
  local end_if_guest
  for line = 0, (script and script.line_count or 0) - 1 do
    if not end_if_guest and line_is(line, 1003, 6) and script.lines[line].bytes[1] == 0 and script.lines[line].bytes[2] == 1 then
      end_if_guest = line
    end
  end
  local as_expected = end_if_guest and #script.parameters == 0
  local after_ends = end_if_guest and end_if_guest + 1
  while as_expected and after_ends < script.line_count and line_is(after_ends, 1003, 2) do after_ends = after_ends + 1 end
  -- The lines that start (2000[00]) one of `event_ids`.
  local function start_lines(event_ids)
    local lines = {}
    for line = 0, script.line_count - 1 do
      local started = line_is(line, 2000, 0) and script.lines[line].args[2]
      for _, event_id in ipairs(event_ids) do
        if started == event_id then lines[#lines + 1] = line end
      end
    end
    return lines
  end
  for line = 0, (as_expected and script.line_count or 0) - 1 do
    as_expected = as_expected and (line_is(line, 2000, 0) or line_is(line, 1003, 6) or line_is(line, 1003, 2))
  end
  local soul_starts, gift_starts = as_expected and start_lines({ 970 }), as_expected and start_lines(GESTURE_GIFTS)
  as_expected = as_expected and #soul_starts > 0 and soul_starts[1] >= after_ends and #gift_starts > 0 and gift_starts[1] >= after_ends
  if as_expected then
    local steps = { { cut = end_if_guest, is = { 1003, 6, 0, 1 } } }
    for _, lines in ipairs({ soul_starts, gift_starts }) do
      for _, line in ipairs(lines) do steps[#steps + 1] = { cut = line, is = { 2000, 0 } } end
    end
    for _, lines in ipairs({ soul_starts, gift_starts }) do
      for _, line in ipairs(lines) do steps[#steps + 1] = lib.copy_step(script, line, after_ends) end
    end
    steps[#steps + 1] = lib.copy_step(script, end_if_guest, after_ends)
    lib.edit(COMMON, 0, steps, "each player's game starts its own boss souls and the NPCs' gesture gifts")
    edited = edited + 1
  else
    kindle.log.warn("event %s 0 isn't as expected: a player gets no boss souls or NPC gestures", COMMON)
  end
  return edited
end
