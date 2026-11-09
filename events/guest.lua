-- No game is a guest, read from the game's event and changed checked, all or nothing.
return function(lib)
  -- Flag 201, "this game is in a world not its own": the game's common event 200 sets it in such a
  -- world (in its own it ends), and 14 action buttons are off while it's on (ActionButtonParam
  -- invalidFlag 201: 7200, 7201, 8320, 8340, 8350, 9200, 9370-9372, 9391, 9400, 9401, 9410, 9411,
  -- for ~30 ObjActs: doors, levers, lifts across the game, the High Wall's first door among them).
  -- Nothing else reads it (all params checked, 2026-10-14; no event waits on it). A joined player
  -- had no prompt at those (a joined player at the High Wall's first door: "no prompt
  -- whatsoever"). A player is no guest: its "end if in its own world" (1003[13] 0 0 0 0) comes out
  -- and its "set flag 201 on" (2003[02]) sets it off instead, in any world.
  local script = lib.script("common", 200)
  local end_if_own, set_201
  for line = 0, (script and script.line_count or 0) - 1 do
    local command = script.lines[line]
    local bytes = command.bytes
    local is_end_if_own = command.bank == 1003 and command.index == 13 and #bytes == 4
      and bytes[1] == 0 and bytes[2] == 0 and bytes[3] == 0 and bytes[4] == 0
    local sets_201_on = command.bank == 2003 and command.index == 2 and #bytes == 8 and bytes[1] == 201 and bytes[5] == 1
      and bytes[2] + bytes[3] + bytes[4] + bytes[6] + bytes[7] + bytes[8] == 0
    if not end_if_own and is_end_if_own then end_if_own = line end
    if not set_201 and sets_201_on then set_201 = line end
  end
  if not (end_if_own and set_201) then
    kindle.log.warn("event common 200 isn't as expected: a player is a guest for some action buttons")
    return 0
  end
  lib.edit("common", 200, {
    { replace = set_201, is = { 2003, 2, 201, 0, 0, 0, 1 }, bank = 2003, index = 2, format = "BBBBBBBB", values = { 201, 0, 0, 0, 0, 0, 0, 0 }, keep_params = true },
    { cut = end_if_own, is = { 1003, 13, 0, 0, 0, 0 } },
  }, "no game is a guest for the action buttons")
  return 1
end
