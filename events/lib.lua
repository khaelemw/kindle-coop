-- Co-op's helpers for changing the game's event scripts, on kindle.events.edit: each change is
-- checked against the game's own lines (bank, index and first argument bytes) and made all or
-- nothing; one that doesn't match is left out and logged, the event staying as the game has it.
-- Lines are numbered from 0 as the game's event files and the Kindle Events extension show
-- them, in every table, whatever an earlier table changed in the same event (kindle.events
-- numbers commands from 1, as the event is before each edit).
--
-- Names used throughout: a `script` is one event as the game has it (lib.script: its `lines`
-- from 0, `line_count`, `parameters`); a `command` is one of its lines (bank, index, `bytes` its
-- argument bytes, `args` read as integers, layer); a `step` is one change in an edit
-- (kindle.events.edit's, by the game's line numbers); a `row` is one entry of a table in events/.
local events = kindle.events

local lib = {}

-- ── one edit, by the game's line numbers ──────────────────────────────────────────────────

-- What earlier edits here did to each event ("map:id" -> record), by the game's numbering: lines
-- taken out (`cut`), and the lines new commands went in before (`inserted_before`).
local edit_records = {}

local function record_of(map, id)
  local key = map .. ":" .. id
  edit_records[key] = edit_records[key] or { cut = {}, inserted_before = {} }
  return edit_records[key]
end

-- The command number now (from 1, as kindle.events counts) of the game's line `line` of map's
-- event id, after the earlier edits here.
local function command_number(map, id, line)
  local number = line
  local record = edit_records[map .. ":" .. id]
  if record then
    for _, cut_line in ipairs(record.cut) do
      if cut_line < line then number = number - 1 end
    end
    for _, before_line in ipairs(record.inserted_before) do
      if before_line <= line then number = number + 1 end
    end
  end
  return number + 1
end

--- One edit of an event, all or nothing, its steps naming the game's lines (from 0):
---   {cut = line, is = {bank, index, bytes...}}
---   {check = line, is = ...}
---   {replace = line, is = ..., bank =, index =, format =, values =, params =}
---   {insert = line (before it), bank =, index =, format =, values =, params =, layer_of = line}
--- (kindle.events.edit's, with lines for command numbers).
-- The events this mod turns the game's network sync off in (a step replacing or inserting
-- "Set Network Sync State" off): flags.lua still sends what a player's game sets in them to the
-- host, as before the edit (the edit keeps a player's own doing on its game, not the world's flags).
lib.made_sync_off = {}

function lib.edit(map, id, steps, why)
  for _, step in ipairs(steps) do
    if step.bank == 2000 and step.index == 2 and step.values and step.values[1] == 0 then lib.made_sync_off[id] = true end
  end
  local numbered_steps = {}
  for position, step in ipairs(steps) do
    local numbered = {}
    for key, value in pairs(step) do numbered[key] = value end
    if step.cut then
      numbered.cut, numbered.remove = nil, command_number(map, id, step.cut)
    elseif step.check then
      numbered.check = command_number(map, id, step.check)
    elseif step.replace then
      numbered.replace = command_number(map, id, step.replace)
    elseif step.insert then
      numbered.insert = command_number(map, id, step.insert)
    end
    if step.layer_of then numbered.layer_of = command_number(map, id, step.layer_of) end
    numbered_steps[position] = numbered
  end
  events.edit(map, id, numbered_steps, why)
  local record = record_of(map, id)
  for _, step in ipairs(steps) do
    if step.cut then table.insert(record.cut, step.cut) end
    if step.insert then table.insert(record.inserted_before, step.insert) end
  end
end

-- A step's check from a table's line {line, bank, index, {bytes}}: {bank, index, bytes...}.
local function expected(table_line)
  return { table_line[2], table_line[3], table.unpack(table_line[4] or {}) }
end

--- Takes lines out of an event, all of them or none: cuts = {{line, bank, index, {bytes}}, ...},
--- each line as numbered in the game's event, its command and first argument bytes checked.
function lib.cut(map, id, cuts, why)
  local steps = {}
  for position, cut in ipairs(cuts) do
    steps[position] = { cut = cut[1], is = expected(cut) }
  end
  lib.edit(map, id, steps, why)
end

-- "Set Network Sync State" off (2000[02] 0) in the place of a table's line, checked.
local function sync_off_step(table_line)
  if table_line.before then
    -- Inserted before the line (another edit already took out the line that would have been
    -- replaced), at its layer.
    return { insert = table_line[1], layer_of = table_line[1], bank = 2000, index = 2, format = "i", values = { 0 } }
  end
  return { replace = table_line[1], is = expected(table_line), bank = 2000, index = 2, format = "i", values = { 0 } }
end

--- Makes a line of an event "Set Network Sync State" off (2000[02] 0): the game then runs the
--- event for its own player alone (a press on one game doesn't hold on the others). table_line =
--- {line, bank, index, {bytes}}, the line that's there now, checked.
function lib.sync_off(map, id, table_line, why)
  local steps = { sync_off_step(table_line) }
  if table_line.before then table.insert(steps, 1, { check = table_line[1], is = expected(table_line) }) end
  lib.edit(map, id, steps, why)
end

--- Each row's line made sync off (rows: {map, event, line}, as lib.sync_off's); how many.
function lib.sync_off_rows(rows, why)
  for _, row in ipairs(rows) do
    lib.sync_off(row[1], row[2], row[3], why)
  end
  return #rows
end

--- Each row's lines out (rows: {map, event, cut, cut, ...}, as lib.cut's); how many events.
function lib.cut_rows(rows, why)
  for _, row in ipairs(rows) do
    lib.cut(row[1], row[2], { table.unpack(row, 3) }, why)
  end
  return #rows
end

-- ── reading the game's event ──────────────────────────────────────────────────────────────

--- The game's event (kindle.events.script) with its lines from 0: script.lines[0 .. line_count - 1],
--- each with bank, index, bytes, args, layer; nil if the map has no such event.
function lib.script(map, id)
  local script = events.script(map, id)
  if not script then return nil end
  script.lines = {}
  for number, command in ipairs(script.commands) do script.lines[number - 1] = command end
  script.line_count = #script.commands
  return script
end

-- "IF Condition Group" (0[00]): bytes {group, state, of group}; the main group is 0.
local IF_GROUP = { bank = 0, index = 0 }
local MAIN_GROUP = 0

local function is_if_group(command)
  return command.bank == IF_GROUP.bank and command.index == IF_GROUP.index
end

--- The line of an event's main wait number `which` (from 0): IF Condition Group, main group, on.
function lib.main_wait(script, which)
  local found = 0
  for line = 0, script.line_count - 1 do
    local command = script.lines[line]
    if is_if_group(command) and command.bytes[1] == MAIN_GROUP and command.bytes[2] == 1 then
      if found == which then return line end
      found = found + 1
    end
  end
end

--- Whether the event uses condition group `group` (a command's first byte, or an IF Condition
--- Group's third).
function lib.group_used(script, group)
  for line = 0, script.line_count - 1 do
    local command = script.lines[line]
    if command.bytes[1] == group or (is_if_group(command) and command.bytes[3] == group) then return true end
  end
  return false
end

-- Commands that skip a number of lines (their first byte), by bank and index.
local SKIPS = {
  [1000] = { [1] = true, [3] = true, [5] = true, [7] = true },
  [1003] = { [1] = true, [3] = true, [5] = true, [7] = true, [9] = true, [14] = true, [112] = true, [202] = true },
  [1005] = { [1] = true },
}
--- Whether a command put in before line `at` would be inside a skip's lines (moving where it lands).
function lib.inside_skip(script, at)
  for line = 0, at - 1 do
    local command = script.lines[line]
    local skips = SKIPS[command.bank] and SKIPS[command.bank][command.index]
    if skips and at <= line + command.bytes[1] then return true end
  end
  return false
end

--- The length of the event's argument at byte `source` (from its parameter entries), or nil.
function lib.param_length(script, source)
  for _, param in ipairs(script.parameters) do
    if param.source == source then return param.length end
  end
end

-- ── flags in commands ─────────────────────────────────────────────────────────────────────

-- A flag in a command: a number (written in it) or {arg = byte} (the event's argument there).
-- The value written in the command (0 when the argument fills it).
local function flag_value(flag)
  return type(flag) == "number" and flag or 0
end

-- The parameter entry filling a flag at byte `target` of a command, or nil (and false if the
-- event has no such argument).
local function flag_params(script, flag, target)
  if type(flag) ~= "table" then return nil end
  local length = lib.param_length(script, flag.arg)
  if not length then return false end
  return { { target = target, source = flag.arg, length = length } }
end

--- The steps by which the main wait at line `wait_line` also ends when `flag` is in `state` (1
--- on, 0 off), through condition group `group`, which the event mustn't use (two commands follow
--- the wait). nil and why if the event isn't as expected.
function lib.or_flag_steps(script, wait_line, flag, state, group)
  if lib.group_used(script, group) then return nil, "group " .. group .. " is used" end
  if lib.inside_skip(script, wait_line + 1) then return nil, "the wait is inside a skip" end
  local params = flag_params(script, flag, 4)
  if params == false then return nil, "no argument at " .. flag.arg end
  local wait = script.lines[wait_line]
  return {
    -- The wait now waits on `group`...
    { replace = wait_line, is = { 0, 0, MAIN_GROUP, 1 }, bank = 0, index = 0, format = "BBBB", values = { group, 1, wait.bytes[3], 0 } },
    -- ...which also holds when the flag is in `state`, and the main group waits on it.
    { insert = wait_line + 1, bank = 3, index = 0, format = "BBBBi", values = { group, state, 0, 0, flag_value(flag) }, params = params, layer_of = wait_line },
    { insert = wait_line + 1, bank = 0, index = 0, format = "BBBB", values = { MAIN_GROUP, 1, group, 0 }, layer_of = wait_line },
  }
end

--- "END IF Event Flag" (1003[02]) on `flag` (on), restarting the event, put in before line `at`.
function lib.restart_if_flag_step(script, at, flag, layer_of)
  return {
    insert = at, bank = 1003, index = 2, format = "BBBBi", values = { 1, 1, 0, 0, flag_value(flag) },
    params = flag_params(script, flag, 4) or nil, layer_of = layer_of,
  }
end

--- "SKIP IF Event Flag" (1003[01]): skip `line_count` lines if `flag` is in `state`, put in before
--- line `at`.
function lib.skip_if_flag_step(script, at, line_count, state, flag, layer_of)
  return {
    insert = at, bank = 1003, index = 1, format = "BBBBi", values = { line_count, state, 0, 0, flag_value(flag) },
    params = flag_params(script, flag, 4) or nil, layer_of = layer_of,
  }
end

--- A copy of the game's line `line` put in before line `at`, with its argument entries and its
--- layer; `changed_bytes` changes some of its argument bytes ({[byte number from 1] = value}).
function lib.copy_step(script, line, at, changed_bytes)
  local command = script.lines[line]
  local values = { table.unpack(command.bytes) }
  for byte, value in pairs(changed_bytes or {}) do values[byte] = value end
  local params = {}
  for _, param in ipairs(script.parameters) do
    -- (A parameter entry names its command from 1.)
    if param.command == line + 1 then params[#params + 1] = { target = param.target, source = param.source, length = param.length } end
  end
  return {
    insert = at, bank = command.bank, index = command.index, format = string.rep("B", #values), values = values,
    params = #params > 0 and params or nil, layer_of = line,
  }
end

-- Commands that jump to a label (their first byte), by bank and index; 1014[label] is the label.
local GOTOS = {
  [1000] = { [101] = true, [103] = true, [105] = true, [107] = true },
  [1003] = { [12] = true, [15] = true, [101] = true, [103] = true, [105] = true, [107] = true, [109] = true },
}
--- Whether the event uses label `label` (1014[label], or a jump to it).
function lib.label_used(script, label)
  for line = 0, script.line_count - 1 do
    local command = script.lines[line]
    local is_label = command.bank == 1014 and command.index == label
    local jumps_to = GOTOS[command.bank] and GOTOS[command.bank][command.index] and command.bytes[1] == label
    if is_label or jumps_to then return true end
  end
  return false
end

-- Appends the items of `more` to `list`; the list.
function lib.append(list, more)
  for _, item in ipairs(more) do list[#list + 1] = item end
  return list
end

-- ── what one game's player does, every game sees ──────────────────────────────────────────

-- The condition groups the waits below add (the game's events use none of them).
local OR_GROUPS = { 0xF9, 0xF8 }

local function warn(map, id, what)
  kindle.log.warn("event %s %d isn't as expected (%s): left as the game has it", map, id, what)
end

-- The cut lines of a row ({map, event, cut, cut, ..., named fields}).
local function cuts_of(row)
  local cuts = {}
  for position = 3, #row do cuts[#cuts + 1] = row[position] end
  return cuts
end

--- A player's arrival moves an NPC's story as the host's does: row = {map, event, cut..., flag =}:
--- the cut lines come out (they let only a player in its own world start it), and the event's
--- first main wait also ends when the step's flag is on (the other games then make the move).
function lib.player_step(row, why)
  local map, id, cuts = row[1], row[2], cuts_of(row)
  local script = lib.script(map, id)
  local wait_line = script and lib.main_wait(script, 0)
  if not wait_line then return warn(map, id, "no main wait") end
  local steps = {}
  for _, cut in ipairs(cuts) do
    if lib.inside_skip(script, cut[1]) then return warn(map, id, "line " .. cut[1] .. " is inside a skip") end
    steps[#steps + 1] = { cut = cut[1], is = expected(cut) }
  end
  local more, err = lib.or_flag_steps(script, wait_line, row.flag, 1, OR_GROUPS[1])
  if more then
    lib.append(steps, more)
  else
    kindle.log.warn("event %s %d: %s; the other games make its move at their next load", map, id, err)
  end
  lib.edit(map, id, steps, why)
end

--- What one game starts, every game sees at once: row = {map, event, wait =, flag =}: the event's
--- main wait `wait` also ends when `flag` comes on (another game did it), and the event then
--- restarts, taking its own "already done" branch, as on a reload.
function lib.restart(row, why)
  local map, id = row[1], row[2]
  local script = lib.script(map, id)
  local wait_line = script and lib.main_wait(script, row.wait or 0)
  if not wait_line then return warn(map, id, "no main wait") end
  local steps, err = lib.or_flag_steps(script, wait_line, row.flag, 1, OR_GROUPS[1])
  if not steps then return warn(map, id, err) end
  steps[#steps + 1] = lib.restart_if_flag_step(script, wait_line + 1, row.flag, wait_line)
  lib.edit(map, id, steps, why)
end

-- Whether line `line` sets `flag` (written in it, or from the event's argument).
local function sets_flag(script, line, flag)
  local command = script.lines[line]
  if command.bank ~= 2003 or command.index ~= 2 then return false end
  if type(flag) == "number" then return command.args[1] == flag end
  for _, param in ipairs(script.parameters) do
    if param.command == line + 1 and param.target == 0 and param.source == flag.arg then return true end
  end
  return false
end

--- One game's player starts it, every game sees it: row = {map, event, cut..., wait =, flag =,
--- own_action =}: the lines that let only the host's player start it come out, its "done" flag
--- is set network-connected (it reaches every game, and from a player the host), and the other
--- games' wait ends on that flag (lib.restart). own_action: a lever started by its player's action
--- button, then that player warped to it: its first cut becomes "sync off" instead, so the
--- puller's game runs it and the others see the lever pulled by its flag.
function lib.shared_trigger(row, why)
  local map, id, cuts = row[1], row[2], cuts_of(row)
  local script = lib.script(map, id)
  local wait_line = script and lib.main_wait(script, row.wait or 0)
  if not wait_line then return warn(map, id, "no main wait") end
  for _, cut in ipairs(cuts) do
    if cut[1] >= wait_line or lib.inside_skip(script, cut[1]) then return warn(map, id, "line " .. cut[1] .. " isn't before the wait") end
  end
  local set_line
  for line = wait_line + 1, script.line_count - 1 do
    if sets_flag(script, line, row.flag) then
      set_line = line
      break
    end
  end
  if not set_line then return warn(map, id, "no line sets its flag") end
  local steps, err = lib.or_flag_steps(script, wait_line, row.flag, 1, OR_GROUPS[1])
  if not steps then return warn(map, id, err) end
  steps[#steps + 1] = lib.restart_if_flag_step(script, wait_line + 1, row.flag, wait_line)
  local set_command = script.lines[set_line]
  -- The plain "set flag" (2003[02]) made the network-connected one (2003[62]).
  steps[#steps + 1] = {
    replace = set_line, is = { 2003, 2, table.unpack(set_command.bytes) },
    bank = 2003, index = 62, format = string.rep("B", #set_command.bytes), values = set_command.bytes, keep_params = true,
  }
  for position = #cuts, 1, -1 do
    local cut = cuts[position]
    if row.own_action and position == 1 then
      steps[#steps + 1] = sync_off_step(cut)
    else
      steps[#steps + 1] = { cut = cut[1], is = expected(cut) }
    end
  end
  lib.edit(map, id, steps, why)
end

--- Something a player works with its button that every game must then show (a network flag the
--- press sets): row = {map, event, waits = {{which, gate, own, flag, state}, ...}, done_at_start}.
--- The presser's game runs the event alone: each wait's own-world gate (a line before it)
--- becomes "sync off", so a press never holds on another game; on the other games the wait also
--- ends once `flag` is in `state` (the press's), and they skip only the presser's own `own`
--- lines after it. done_at_start: a game whose first wait's flag is already set as the event
--- starts takes its "done" branch (the line after line 0).
function lib.shared_pull(row, why)
  local map, id = row[1], row[2]
  local script = lib.script(map, id)
  if not script or #row.waits > #OR_GROUPS then return warn(map, id, "no such event") end
  local wait_lines = {}
  for position, wait in ipairs(row.waits) do
    local wait_line = lib.main_wait(script, wait.which)
    if not wait_line or wait.gate[1] >= wait_line or wait_line + wait.own >= script.line_count or lib.inside_skip(script, wait_line + 1) then
      return warn(map, id, "wait " .. wait.which)
    end
    wait_lines[position] = wait_line
  end
  local steps = {}
  for position = #row.waits, 1, -1 do
    local wait, wait_line = row.waits[position], wait_lines[position]
    steps[#steps + 1] = sync_off_step(wait.gate)
    local more, err = lib.or_flag_steps(script, wait_line, wait.flag, wait.state, OR_GROUPS[position])
    if not more then return warn(map, id, err) end
    lib.append(steps, more)
    -- Only the presser, whose flag isn't in that state yet, runs its own lines.
    steps[#steps + 1] = lib.skip_if_flag_step(script, wait_line + 1, wait.own, wait.state, wait.flag, wait_line)
  end
  if row.done_at_start then
    steps[#steps + 1] = lib.skip_if_flag_step(script, 0, 1, 1, row.waits[1].flag, 0)
  end
  -- An event whose press sets its flag with a plain "set flag" (2003[02]: this game's own) has it
  -- set network-connected (2003[62]), so it reaches the other games.
  for _, line in ipairs(row.network_sets or {}) do
    local command = script.lines[line]
    if not (command and command.bank == 2003 and command.index == 2) then return warn(map, id, "line " .. line .. " isn't a plain set") end
    steps[#steps + 1] = {
      replace = line, is = { 2003, 2, table.unpack(command.bytes) },
      bank = 2003, index = 62, format = string.rep("B", #command.bytes), values = command.bytes, keep_params = true,
    }
  end
  lib.edit(map, id, steps, why)
end

--- Each row through `edit_row` (lib.player_step, lib.restart, ...); how many rows.
function lib.rows(rows, edit_row, why)
  for _, row in ipairs(rows) do edit_row(row, why) end
  return #rows
end

lib.sync_off_step = sync_off_step
lib.expected = expected

return lib
