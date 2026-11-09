-- Bosses' events (common_func), each read from the game's event and changed checked, all or
-- nothing. Lines numbered from 0 as the game's event files and the Kindle Events extension show
-- them.
return function(lib)
  local edited = 0
  local COMMON_FUNC = "common_func"

  -- The event that lets a white phantom through a boss's fog (20005801): its action button waits
  -- on the boss being alive (the argument X0) and on the host having gone in (X12, the host's
  -- entry flag, set by the host's own fog event 20005800), so a phantom couldn't go first. The
  -- second condition comes out (each IF Event Flag filled from X12): a player goes through as the
  -- host does. The boss still starts when the host goes in (the host's game runs it).
  local script = lib.script(COMMON_FUNC, 20005801)
  if script then
    local steps = {}
    for _, param in ipairs(script.parameters) do
      -- (A parameter entry names its command from 1.)
      local line = param.command - 1
      local command = script.lines[line]
      if param.source == 12 and param.target == 4 and command.bank == 3 and command.index == 0 then
        steps[#steps + 1] = { cut = line, is = { 3, 0 } }
      end
    end
    if #steps > 0 then
      lib.edit(COMMON_FUNC, 20005801, steps, "players go through a boss's fog without waiting for the host")
      edited = edited + 1
    end
  end

  -- The event for a boss fog's wall and look (20005820): it turns the fog on when condition group
  -- -4 holds, an "or" of group -1 (not in its own world), group 1 (the fight's flag, the boss
  -- alive) and group 2 (a summoned player's multiplayer state, the boss dead); after, it waits
  -- for group 5 (not -5: in its own world; and neither 3 nor 4, the same two) to turn it off
  -- again. The lines that add the summoned-player reasons (-1 and 2 to -4, 4 to 5) and the "in its
  -- own world" one from 5 come out: every game's wall follows the host's rule.
  -- Each: IF Condition Group's bytes {group, state, of group} (0xFC = -4, 0xFF = -1, 0xFB = -5).
  local GROUP_LINES_OUT = { { 0xFC, 1, 0xFF }, { 0xFC, 1, 2 }, { 5, 0, 0xFB }, { 5, 0, 4 } }
  script = lib.script(COMMON_FUNC, 20005820)
  if script then
    local steps = {}
    for line = 0, script.line_count - 1 do
      local command = script.lines[line]
      for _, group_line in ipairs(GROUP_LINES_OUT) do
        local bytes = command.bytes
        if command.bank == 0 and command.index == 0 and bytes[1] == group_line[1] and bytes[2] == group_line[2] and bytes[3] == group_line[3] then
          steps[#steps + 1] = { cut = line, is = { 0, 0, group_line[1], group_line[2], group_line[3] } }
        end
      end
    end
    lib.edit(COMMON_FUNC, 20005820, steps, "a boss's fog wall is up for players when it's up for the host")
    edited = edited + 1
  end

  -- Near a boss (20005840/41, 18 bosses): a character of the host's type (0) in a world not its
  -- own (the session's host: no) comes within 5 m of the boss, and the game turns off its
  -- collision with the map (2004[59]: a Lua event and SetDisableMapHit; 20005841 back on further
  -- out). The base game never has that character (the host's type is the host's own world's), so
  -- they never run. A Kindle player is of the host's type for the event scripts (the catalogue's
  -- events.chr_type_test) and never in its own world: it'd fall through the floor at every boss.
  -- Their test (IF Character Type, 4[03]: group, entity 10000, type at byte 8) is of a type no
  -- character has (0xFE), as it is in practice in the base game.
  local NO_SUCH_TYPE = 0xFE
  for _, id in ipairs({ 20005840, 20005841 }) do
    script = lib.script(COMMON_FUNC, id)
    local type_tests = {}
    for line = 0, (script and script.line_count or 0) - 1 do
      if script.lines[line].bank == 4 and script.lines[line].index == 3 then type_tests[#type_tests + 1] = line end
    end
    local test = #type_tests == 1 and script.lines[type_tests[1]]
    -- Entity 10000 (the player: 0x2710, little-endian, in bytes[5..8]) and type 0 in bytes[9].
    local bytes = test and test.bytes
    if test and bytes[5] == 0x10 and bytes[6] == 0x27 and bytes[7] == 0 and bytes[8] == 0 and bytes[9] == 0 then
      local new_bytes = { table.unpack(bytes) }
      new_bytes[9] = NO_SUCH_TYPE
      lib.edit(COMMON_FUNC, id, {
        {
          replace = type_tests[1], is = { 4, 3, table.unpack(bytes, 1, 9) },
          bank = 4, index = 3, format = string.rep("B", #new_bytes), values = new_bytes, keep_params = true,
        },
      }, "the near-a-boss events stay off for players")
      edited = edited + 1
    else
      kindle.log.warn("event %s %d isn't as expected: left as the game has it", COMMON_FUNC, id)
    end
  end

  -- A boss's fog after its death (20005810, at 12 bosses' fogs: Vordt's m30 13005820 with its fog
  -- object 3001800 and action button 10000): in the host's own world, with the boss dead (X0) and
  -- the game in multiplayer (state 2 or 3), the fog's action button still offers "traverse" at
  -- the fog (gone by then), and taking it turns the host and sends every phantom home (2009[11]).
  -- Alone the game never offers it (no multiplayer state). At Vordt (2026-10-15): "the
  -- fog wall was invisible and passable, but if I stood in the right area I still had the prompt
  -- to traverse the fog", and going through kicked the joined player. A Kindle party plays as one player
  -- would: every line comes out, the event does nothing.
  script = lib.script(COMMON_FUNC, 20005810)
  if script then
    local steps, sends_home = {}, false
    for line = 0, script.line_count - 1 do
      local command = script.lines[line]
      sends_home = sends_home or (command.bank == 2009 and command.index == 11)
      steps[#steps + 1] = { cut = line, is = { command.bank, command.index } }
    end
    if sends_home then
      lib.edit(COMMON_FUNC, 20005810, steps, "a dead boss's fog sends nobody home")
      edited = edited + 1
    else
      kindle.log.warn("event %s %d isn't as expected: the host can still send players home through a dead boss's fog", COMMON_FUNC, 20005810)
    end
  end
  -- The Dancer's fight (m30 13005890) walks its player through the fog itself: the fog's action
  -- button (line 55, 3001890), the walk in (56), then, inside the arena (58), the fight's "entered"
  -- flag 13000880 and, on to line 69, the boss's health bar. Each player walks in on its own press
  -- (sync_off.lua: "sync off" before line 55), so a player who went in after another, through the
  -- phantom fog event (20005801, which waits on 13000880), left its game's copy waiting at the
  -- button: no health bar (a joined player, 2026-10-19). The wait also ends once 13000880 is on,
  -- skipping only the walk in; the event then waits for that game's own player inside the arena, as
  -- after its own walk. Each: {line, bank, index}, checked.
  local DANCER_MAP, DANCER_FIGHT, FIGHT_ENTERED, OR_GROUP = "m30_00_00_00", 13005890, 13000880, 0xF9
  local BUTTON_LINE, WALK_LINE = 55, 56
  script = lib.script(DANCER_MAP, DANCER_FIGHT)
  local button = script and script.lines[BUTTON_LINE]
  local walk = script and script.lines[WALK_LINE]
  if button and button.bank == 3 and button.index == 24 and button.bytes[1] == 0 and walk and walk.bank == 2004 and walk.index == 14
    and not lib.group_used(script, OR_GROUP) then
    local or_button = { table.unpack(button.bytes) }
    or_button[1] = OR_GROUP
    lib.edit(DANCER_MAP, DANCER_FIGHT, {
      -- The button's wait becomes the "or" group's, which the fight's flag also holds...
      { replace = BUTTON_LINE, is = { 3, 24, 0 }, bank = 3, index = 24, format = string.rep("B", #or_button), values = or_button },
      { insert = WALK_LINE, bank = 3, index = 0, format = "BBBBi", values = { OR_GROUP, 1, 0, 0, FIGHT_ENTERED }, layer_of = BUTTON_LINE },
      -- ...and the main wait waits on it.
      { insert = WALK_LINE, bank = 0, index = 0, format = "BBBB", values = { 0, 1, OR_GROUP, 0 }, layer_of = BUTTON_LINE },
      -- Gone in through another fog event: no walk of its own.
      lib.skip_if_flag_step(script, WALK_LINE, 1, 1, FIGHT_ENTERED, BUTTON_LINE),
    }, "a player who goes into the Dancer's fight after another gets its health bar")
    edited = edited + 1
  else
    kindle.log.warn("event %s %d isn't as expected: a player going in second has no health bar", DANCER_MAP, DANCER_FIGHT)
  end
  return edited
end
