-- Nobody dies alone, as with Seamless Co-op: while a player is in a host's world, or a host has
-- players with it, its character can't go below 1 HP (the game's no-death flag) and a hit or fall
-- that takes it to 1 counts as going down. Downed (revive.lua), a teammate can revive it for
-- BLEED_OUT; bled out, or with revives off, it's out: hidden, untouchable and following a teammate
-- who is still standing, whom its camera looks on at, until the party rests at a bonfire
-- (rest.lua), where it comes back beside the others. When nobody is standing, the party has died
-- as one player dies alone (2026-10-15): the host's flag goes off and the game's own
-- death runs (YOU DIED, back at its last bonfire); its players see YOU DIED, stay out until the
-- host's world reloads, follow it there (follow.lua) and arrive as a death leaves a character,
-- with full HP, FP and Estus, their souls left where they went down. Without this the game sends a
-- dead phantom home, and a dead host's players too; a player's own death sent it home and joined
-- it again, its character keeping the death's state into the host's world (it walked in "Idle").
local party = require("party")
local catalogue = require("catalogue")
local follow = require("follow")
local net, game, world, player, input, ui, events, params, hks, log =
  kindle.net, kindle.game, kindle.world, kindle.player, kindle.input, kindle.ui, kindle.events, kindle.params, kindle.hks, kindle.log

local BLEED_OUT = 30 -- seconds downed before out
local REVIVE_HP = 0.3 -- of max HP, revived
local REVIVE_LIMIT = nil -- revives each rest (nil: no limit)
-- A player who fell out of the world is landed by a teammate and stood up at most this often
-- before it goes out anyway.
local FALL_LANDINGS = 3
local FOLLOW_ABOVE = 3.0 -- how far above the watched player an out player's character is held
local LANDING_FRAMES = 10 -- frames a player back from out is held where it lands
local LAND_BESIDE = 1.5 -- m to the side of a teammate a player lands, and how far up
local LAND_ABOVE = 0.2
-- Back at the party's rest: how far from a sitting teammate it lands, how long after standing it
-- sits down, how long it tries, and how often it presses the rest prompt.
local SIT_BESIDE, SIT_AFTER, SIT_WAIT, SIT_PRESS_EVERY = 0.6, 0.4, 5, 1.2
local THIS_PLAYER = 10000 -- the player's entity id in event commands
local SET_MAP_HIT = { bank = 2004, index = 31 }
local CAMERA_DROP_STEP = 0.2
local YOU_DIED_BANNER = 2
local NO_PROMPT = -1 -- ui.action_prompt with no action prompt up

-- The character the no-death flag is on (its handle); landings tried since it went down; where it
-- lands ({x, y, z, frames left}) and the facing it takes then (a sitting teammate's); when it sits
-- back down, and when that last pressed the rest prompt; a fatal fall the no-death flag kept off
-- (what told it: a death floor's hit, or the behaviour script's fall death after falling long).
local no_death_on, landings_tried, landing, landing_facing, sit_at, sit_pressed_at, fatal_fall =
  nil, 0, nil, nil, nil, nil, false
-- The standing player an out player watches (its handle), and left and right as last held.
local watched_handle, held_left, held_right = nil, false, false
-- LockCamParam rows' own heights (row id -> height), and by how much they're lowered now; how high
-- an out player's character really is over the player it watches (as last seen).
local camera_heights, camera_drop = nil, 0
local camera_drop_wanted = 0

local function now() return kindle.time() end

local function notice(text) ui.toast(text) end

-- This game's player and the other players' characters now (once a frame): the player's handle,
-- and {handle, hp, x, y, z, ...} of each other player. (world.players: world.characters reads
-- every character of the area, 2 ms a frame.)
local function characters()
  local my_handle, others = nil, {}
  for _, character in ipairs(world.players()) do
    if character.is_player then
      my_handle = character.handle
    elseif character.other_player then
      others[#others + 1] = character
    end
  end
  return my_handle, others
end

local function animation_of(handle)
  local ok, animation = pcall(world.animation, handle)
  return ok and animation or nil
end

local function stand_up() pcall(player.play_animation, "W_Idle") end

local function set_map_hit(on)
  pcall(events.run, SET_MAP_HIT.bank, SET_MAP_HIT.index, "iB", THIS_PLAYER, on and 0 or 1)
end

-- Out (down until the party rests) or back: the character hidden, untouchable and floating, the
-- player looking on (the camera, the menus and popups; no acting).
local function set_out(my_handle, on)
  if on and not party.out then
    -- Where it went down: at the party's death its souls stay there.
    pcall(game.call, "bloodstain.mark")
  end
  party.out = on
  pcall(input.block_actions, on)
  pcall(world.set_visible, my_handle, not on)
  pcall(player.set_invulnerable, on)
  pcall(player.set_no_damage, on)
  pcall(player.set_gravity, not on)
  -- Its collision with the map off while out: held over the watched player, it meets no ceiling (in
  -- a house the game kept it lower, and the camera jumped as the player walked, 2026-10-15).
  set_map_hit(not on)
end

-- Downed or up again: on the ground, unable to act or to be hurt, and visible.
function party.set_downed(on)
  party.downed_since = on and now() or nil
  party.revived, party.reviver = false, nil
  pcall(input.block_actions, on)
  pcall(player.set_invulnerable, on)
  pcall(player.set_no_damage, on)
  if on then
    pcall(player.play_animation, party.DOWN_POSE)
  else
    ui.status(nil)
    stand_up()
  end
end

local function revive_allowed()
  return REVIVE_LIMIT == nil or party.revives_used < REVIVE_LIMIT
end

game.on("player.fall_death_blocked", function()
  if not party.out then fatal_fall = "a death floor" end
end)

-- The player's behaviour script has a fall death of its own: falling FALL_DEATH_SECONDS (its
-- env FALLING_FOR, 315, asked with 12) kills the character outright, whatever
-- the no-death flag. It ends a fall that hits no death floor on the way down (off the Cemetery
-- of Ash's cliff: the game's death ran under the flag, and back at the party's rest the player's
-- screen stayed grey, 2026-10-18). While the player can't die it's a fatal fall as a death
-- floor's is: the script is told "not yet", and the player goes down.
local FALL_DEATH_SECONDS = 12
hks.on_env(hks.env.FALLING_FOR, function(call)
  if call.result ~= 1 or call.args[1] ~= FALL_DEATH_SECONDS or not no_death_on or party.out then return nil end
  if not (call.character and call.character.is_player) then return nil end
  fatal_fall = "falling " .. FALL_DEATH_SECONDS .. " s"
  return 0
end)

-- Which standing player an out player watches: left and right (the D-pad or left stick, the
-- arrow keys or A and D; the game doesn't see them while the player is out) switch to the previous
-- or next one; one who goes down too is swapped for the first still standing.
local function watched_player(standing)
  local left, right = input.held("left"), input.held("right")
  local pressed_left, pressed_right = left and not held_left, right and not held_right
  held_left, held_right = left, right
  local index = 1
  for position, character in ipairs(standing) do
    if character.handle == watched_handle then index = position end
  end
  if (pressed_left or pressed_right) and #standing > 1 then
    -- The next one round the list, or the previous one (Lua's lists count from 1).
    if pressed_right then
      index = (index % #standing) + 1
    else
      index = ((index - 2) % #standing) + 1
    end
    local name
    for _, member_id in ipairs(net.members() or {}) do
      local member = net.player(member_id)
      if member and member.handle == standing[index].handle then name = member.name end
    end
    notice("Watching " .. ((name and name ~= "") and name or "another player"))
  end
  watched_handle = standing[index].handle
  return standing[index]
end

-- The game's camera looks at a point above the player's character, at a height from its settings
-- (LockCamParam's chrOrgOffset_Y, by row). Out, the hidden character floats over the standing
-- player it watches, so every row's height is lowered by how high it is over that player: the
-- camera looks on at the standing player as at its own character (the right stick or the mouse
-- still turn it). Given back when the player is no longer out.
local function camera_frame(drop)
  drop = party.out and drop or 0
  local unchanged = party.out and camera_heights and math.abs(drop - camera_drop) < CAMERA_DROP_STEP
  if (not party.out and not camera_heights) or unchanged then return end
  if not camera_heights then
    camera_heights = {}
    for _, row_id in ipairs(params.rows("LockCamParam")) do
      local row = params.get("LockCamParam", row_id)
      if row then camera_heights[row_id] = row.chrOrgOffset_Y end
    end
  end
  for row_id, height in pairs(camera_heights) do
    local row = params.get("LockCamParam", row_id)
    if row then pcall(function() row.chrOrgOffset_Y = height - drop end) end
  end
  camera_drop = drop
  if not party.out then camera_heights = nil end
end

-- The other players who are out (party.outs) are hidden on this game, shown again after.
local function hide_frame(my_id)
  if not player.loaded() then return end
  local to_hide = {}
  for member_id in pairs(party.outs) do
    if member_id ~= my_id then
      local member = net.player(member_id)
      if member then to_hide[member.handle] = true end
    end
  end
  for handle in pairs(party.hidden) do
    if not to_hide[handle] then pcall(world.set_visible, handle, true) end
  end
  for handle in pairs(to_hide) do pcall(world.set_visible, handle, false) end
  party.hidden = to_hide
end

-- Out: the interact button is kept from the game while an action prompt is up and the Esc menu
-- isn't open (the hidden character would take things, read messages or rest). Not while a dialog is
-- open or an item popup is up: its OK is shown as an action prompt too, and an out player couldn't
-- close the item a teammate's kill gave it (2026-10-15).
local function out_interact_frame()
  if not party.out then return end
  local prompt_up = (catalogue.field("ui.action_prompt") or NO_PROMPT) ~= NO_PROMPT
  local blocked = prompt_up and not catalogue.field("ui.esc_menu_open") and not catalogue.field("ui.item_popup") and not catalogue.field("ui.menu_open")
  pcall(input.block_interact, blocked)
end

local function respawn_frame()
  local in_world = player.loaded()
  local my_handle, others = nil, {}
  if in_world then my_handle, others = characters() end
  local role, together = net.role(), false
  if role == "player" then
    together = net.state() == "joined"
  elseif role == "host" then
    together = my_handle ~= nil and #others > 0
  end
  if not together or not my_handle or my_handle ~= no_death_on then
    -- Not (or no longer) in a session with others, or another character: undone.
    if no_death_on and my_handle == no_death_on then
      pcall(player.set_no_death, false)
      if party.out then
        set_out(my_handle, false)
        pcall(player.set_hp, player.max_hp())
      end
    end
    party.out, fatal_fall = false, false
    if party.downed_since then
      if my_handle then
        party.set_downed(false)
      else
        party.downed_since = nil
        ui.status(nil)
      end
    end
    pcall(input.block_actions, false)
    no_death_on = nil
    -- No session at all, nor following the host into one: no return to its bonfire.
    if role == nil and not follow.following() then party.wiped = false end
    if not together then return end
  end
  if not my_handle then return end
  local hp, max_hp = player.hp(), player.max_hp()
  if party.dying then
    if hp > 1 then party.dying = false else return end
  end
  if not no_death_on then
    pcall(player.set_no_death, true)
    no_death_on = my_handle
  end
  -- Back at the host's bonfire after the party died: out no more (the follow's leave ended it) and
  -- the follow's load done.
  if not party.out and not follow.following() and party.wiped then
    party.wiped = false
    pcall(player.set_hp, max_hp)
    pcall(player.set_fp, player.max_fp())
    pcall(player.refill_estus)
    log.info("back at the bonfire with the host, as after a death: full HP, FP and Estus")
  end
  -- Just back: held where it came back for a few frames (one teleport doesn't always take, and the
  -- bonfire's sitters are in the way), then stood up.
  if landing then
    fatal_fall = false
    pcall(player.teleport, landing.x, landing.y, landing.z)
    if landing_facing then pcall(player.set_facing, landing_facing) end
    pcall(game.set, "chr.fall_time", 0, my_handle)
    landing.frames_left = landing.frames_left - 1
    if landing.frames_left <= 0 then
      landing = nil
      stand_up()
      if landing_facing then
        landing_facing = nil
        sit_at = now() + SIT_AFTER
        -- Its sit joins the rest that brought it back (rest.lua): no second party rest.
        party.sitting_back = true
      end
    end
    return
  end
  -- Sat down through the rest prompt, as the others did: pressed while it's up (the game finds it a
  -- moment after the landing, and takes the press once the character has stood) until the
  -- character sits; none within SIT_WAIT, it stays standing.
  if sit_at and now() >= sit_at then
    local sitting = (animation_of(my_handle) or ""):find("Bonfire") ~= nil
    if sitting then
      -- (party.sitting_back stays: the game asks to rest a moment after the sit, and rest.lua
      -- takes it then.)
      sit_at, sit_pressed_at = nil, nil
      log.info("back sitting at the bonfire with the party")
    elseif now() - sit_at > SIT_WAIT then
      sit_at, sit_pressed_at, party.sitting_back = nil, nil, false
    elseif (catalogue.field("ui.action_prompt") or NO_PROMPT) ~= NO_PROMPT and (not sit_pressed_at or now() - sit_pressed_at >= SIT_PRESS_EVERY)
      and pcall(input.press, "pad_a", 0.2) then
      sit_pressed_at = now()
    end
  end
  if fatal_fall and not party.out and hp > 1 then
    -- (Which caught it, and how long the fall was: a long fall before a player was landed by a
    -- teammate, a joined player 2026-10-19, is the behaviour's, where no death floor is below.)
    local read_ok, fell_for = pcall(game.get, "chr.fall_time", my_handle)
    log.info("a fatal fall (%s; %s s in the air)", fatal_fall, read_ok and fell_for and string.format("%.1f", fell_for) or "?")
    pcall(player.set_hp, 1)
    hp = 1
  end
  fatal_fall = false
  if not party.out and not party.downed_since and hp > 1 then return end
  local standing = {}
  for _, character in ipairs(others) do
    if character.hp > 1 then standing[#standing + 1] = character end
  end
  if #standing == 0 then
    -- Everyone is down: the party dies. A player: out until the host's death reloads its world,
    -- then back there with it; its own game doesn't die.
    if role == "player" then
      if not party.wiped then
        party.wiped = true
        if party.downed_since then party.set_downed(false) end
        if not party.out then set_out(my_handle, true) end
        log.info("nobody is standing; back to the bonfire with the host")
        -- Its souls stay where it went down, its bloodstain, as its own death would leave them
        -- (2026-10-15: each picks up its own).
        pcall(game.call, "bloodstain.leave")
        -- YOU DIED on every screen, as on the host's.
        if not pcall(ui.game_banner, YOU_DIED_BANNER) then notice("Everyone is down: back to the bonfire with the host") end
      end
      pcall(player.set_hp, 1)
      return
    end
    -- The host: the real death (the game's own, from here).
    log.info("nobody is standing; the death counts")
    if party.downed_since then party.set_downed(false) end
    if party.out then set_out(my_handle, false) end
    pcall(player.set_no_death, false)
    no_death_on, party.dying = nil, true
    pcall(player.set_hp, 0)
    return
  end
  local first_standing = standing[1]
  if party.downed_since then
    if party.revived then
      party.set_downed(false)
      pcall(player.set_hp, math.floor(max_hp * REVIVE_HP + 0.5))
      party.revives_used = party.revives_used + 1
      log.info("revived by a teammate")
      pcall(ui.place_banner, "Revived")
      return
    end
    pcall(player.set_hp, 1)
    -- Not while a teammate is reviving it (2026-10-19: the timer ran out mid-revive);
    -- a revive stopped after the time is up bleeds it out then.
    local reviver = party.reviver and net.player(party.reviver)
    if not reviver then party.reviver = nil end
    if now() - party.downed_since >= BLEED_OUT and not reviver then
      party.set_downed(false)
      set_out(my_handle, true)
      log.info("bled out; out until the party rests at a bonfire")
      pcall(ui.place_banner, "Bled out")
      notice("You'll be back when the others rest at a bonfire")
      return
    end
    -- Held on the ground (a hit's or the behaviour's own animation could stand it up).
    if not party.in_down_pose(animation_of(my_handle)) then pcall(player.play_animation, party.DOWN_POSE) end
    if reviver then
      ui.status(string.format("You're down: %s is reviving you", reviver.name ~= "" and reviver.name or "a teammate"))
    else
      local seconds_left = math.floor(BLEED_OUT - (now() - party.downed_since)) + 1
      ui.status(string.format("You're down: a teammate can revive you (%d)", seconds_left))
    end
    return
  end
  if not party.out then
    -- A fall out of the world: the character lands next to the teammate and is stood up first.
    -- Held in the air from its fall instead, its physics stayed falling, and at the revive it went
    -- into its fall-death animation for good (verified 2026-10-09).
    local animation = animation_of(my_handle) or ""
    local fell = animation:find("Fall") ~= nil or animation:find("Death") ~= nil
    if fell and landings_tried < FALL_LANDINGS then
      landings_tried = landings_tried + 1
      landing = { x = first_standing.x + LAND_BESIDE, y = first_standing.y + LAND_ABOVE, z = first_standing.z, frames_left = LANDING_FRAMES }
      return
    end
    landings_tried = 0
    if not fell and revive_allowed() then
      party.set_downed(true)
      log.info("downed; a teammate can revive this player for %d s", BLEED_OUT)
      return
    end
    set_out(my_handle, true)
    log.info("down; out until the party rests at a bonfire")
    if #standing > 1 then
      notice(input.using_pad()
        and "You're down: you'll be back when the others rest at a bonfire (left and right on the D-pad: watch another player)"
        or "You're down: you'll be back when the others rest at a bonfire (A and D, or the arrow keys: watch another player)")
    else
      notice("You're down: you'll be back when the others rest at a bonfire")
    end
    return
  end
  if party.revive_due then
    party.revive_due = false
    set_out(my_handle, false)
    pcall(player.set_hp, max_hp)
    -- Beside a teammate sitting at the bonfire, facing it as they do; else next to one.
    local sitter
    for _, character in ipairs(standing) do
      if (animation_of(character.handle) or ""):find("Bonfire") then
        sitter = character
        break
      end
    end
    local facing_ok, facing = false, nil
    if sitter then facing_ok, facing = pcall(world.facing, sitter.handle) end
    if facing_ok and facing then
      landing_facing = facing
      landing = {
        x = sitter.x + SIT_BESIDE * math.cos(facing), y = sitter.y + LAND_ABOVE, z = sitter.z - SIT_BESIDE * math.sin(facing),
        frames_left = LANDING_FRAMES,
      }
    else
      landing = { x = first_standing.x + LAND_BESIDE, y = first_standing.y + LAND_ABOVE, z = first_standing.z, frames_left = LANDING_FRAMES }
    end
    party.back_up_at = now()
    log.info("back with the party at the bonfire")
    return
  end
  -- Out: hidden and untouchable, held above a standing player, whom its camera looks on at. Held in
  -- the air, the character counts as falling: its fall timer is held at 0, and a death animation (a
  -- fall out of the world) is stood up at once.
  pcall(player.set_hp, 1)
  local watched = watched_player(standing)
  pcall(player.teleport, watched.x, watched.y + FOLLOW_ABOVE, watched.z)
  pcall(game.call, "chr.stand_on", my_handle, watched.handle)
  local _, my_y = player.position()
  local height_over = my_y and (my_y - watched.y) or FOLLOW_ABOVE
  if height_over ~= height_over then height_over = FOLLOW_ABOVE end -- NaN (the position not read yet)
  camera_drop_wanted = math.max(-1, math.min(FOLLOW_ABOVE + 1, height_over))
  pcall(game.set, "chr.fall_time", 0, my_handle)
  if (animation_of(my_handle) or ""):find("Death") then stand_up() end
end

-- Another player who falls goes down and comes back on its own game: a death floor's hit on its
-- character here doesn't start the fade a phantom leaves by (it stayed faded, 2026-10-14).
game.decide("chr.departure_hit", "ignore")
-- A player's souls from the party's death stay in its bloodstain, shown at its load in the host's
-- world (a phantom's is taken away at a load).
game.decide("load.bloodstain", "any")

kindle.on("frame", function()
  respawn_frame()
  camera_frame(camera_drop_wanted)
  if party.together() then
    hide_frame(net.me())
    out_interact_frame()
  else
    if next(party.hidden) then hide_frame(net.me()) end
  end
  party.frame()
end)
