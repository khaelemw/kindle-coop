-- Reviving (the design, 2026-10-11): a player who goes down isn't out at once: it's downed
-- (death.lua), on the ground, unable to act or to be hurt, and a teammate who is standing can
-- revive it by holding the action button by it for REVIVE_HOLD (being hit stops it); revived, it's
-- back with part of its HP and still embered. The reviver crouches with a hand to the ground over
-- the downed player (a gesture's pose, held from KNEEL_AT) on every game: it tells the others
-- ("reviving") and each holds the pose on its character (a held animation isn't sent by the game).
-- Not the bonfire lighting it was: the game's bonfire animations make the character invulnerable
-- (their TAE's jump table 54), so a reviver took no hits and couldn't be stopped (2026-10-18; on
-- two games on one PC a skeleton's hits did nothing until it stood).
local party = require("party")
local net, world, player, input, ui, log = kindle.net, kindle.world, kindle.player, kindle.input, kindle.ui, kindle.log

local REVIVE_HOLD = 5 -- seconds
local REVIVE_RANGE = 2.0 -- m
local KNEEL_AT = 1.2 -- seconds into the pose it's held
local REVIVE_POSE = "W_Event80900" -- a gesture (animation 80900): crouched, a hand to the ground
local REVIVE_ANIMATION = "Event80900"

-- This player reviving: {who (member id), since, hp (its HP then)}. Other players reviving now
-- (member id -> since), and those who stopped, to stand up on this game. After an interrupted
-- revive, none starts until the action button is let go.
local reviving, wait_for_release = nil, false
local revivers, stopped_revivers = {}, {}

local function now() return kindle.time() end

local function name_of(member_id)
  local member = net.player(member_id)
  return (member and member.name ~= "") and member.name or "your teammate"
end

local function animation_of(handle)
  local ok, animation = pcall(world.animation, handle)
  return ok and animation or nil
end

net.on("reviving", function(message, from)
  if type(message) ~= "table" then return end
  if message.target then
    revivers[from] = now()
    if message.target == net.me() and party.downed_since then party.reviver = from end
  else
    revivers[from] = nil
    stopped_revivers[#stopped_revivers + 1] = from
    if party.reviver == from then party.reviver = nil end
  end
end)

net.on("revive", function()
  if party.downed_since then party.revived = true end
end)

-- The reviver stood up again: its animation going and standing.
local function stop_reviving()
  -- The player's actions back, unless it went down or out meanwhile (death.lua blocks them then).
  if not party.downed_since and not party.out then
    pcall(input.block_interact, false)
    pcall(input.block_actions, false)
  end
  pcall(player.set_animation_speed, 1)
  ui.status(nil)
  pcall(net.send, "all", "reviving", { target = false })
  pcall(player.play_animation, "W_Idle")
end

-- The other players reviving shown reaching out (their pose held on this game), and those who
-- stopped stood up.
local function revivers_frame()
  for _, member_id in ipairs(stopped_revivers) do
    local member = net.player(member_id)
    if member then
      pcall(world.set_animation_speed, member.handle, 1)
      pcall(world.play_animation, member.handle, "W_Idle")
    end
  end
  stopped_revivers = {}
  for member_id, since in pairs(revivers) do
    local member = net.player(member_id)
    if member then
      if now() - since < KNEEL_AT then
        if animation_of(member.handle) ~= REVIVE_ANIMATION then pcall(world.play_animation, member.handle, REVIVE_POSE) end
      else
        pcall(world.set_animation_speed, member.handle, 0)
      end
    end
  end
end

-- This player reviving a downed teammate by it (holding the action button).
local function revive_frame()
  local my_id = net.me()
  local hp = player.loaded() and player.hp() or nil
  local able = party.together() and not party.out and not party.downed_since and hp ~= nil and hp > 1
  if not able or not my_id then
    ui.prompt(nil)
    if reviving then
      reviving = nil
      if player.loaded() then stop_reviving() end
    end
    return
  end
  local downed_teammates = {}
  for member_id in pairs(party.downs) do
    if member_id ~= my_id then downed_teammates[#downed_teammates + 1] = member_id end
  end
  if #downed_teammates == 0 and not reviving then
    ui.prompt(nil)
    return
  end
  local x, y, z = player.position()
  local nearby
  for _, member_id in ipairs(downed_teammates) do
    local member = net.player(member_id)
    local character = member and world.character(member.handle)
    if character then
      -- A downed teammate's pose isn't sent by the game: this game holds it on its character.
      if not party.in_down_pose(animation_of(member.handle)) then pcall(world.play_animation, member.handle, party.DOWN_POSE) end
      if not nearby and x and character.x then
        local distance = math.sqrt((character.x - x) ^ 2 + (character.y - y) ^ 2 + (character.z - z) ^ 2)
        if distance <= REVIVE_RANGE then nearby = member_id end
      end
    end
  end
  local held = input.held("action")
  if not held then wait_for_release = false end
  if reviving and nearby == reviving.who and held then
    ui.prompt(nil)
    local held_for = now() - reviving.since
    if hp < reviving.hp then
      reviving = nil
      stop_reviving()
      -- A new revive only once the button is let go: held, it began again at once.
      wait_for_release = true
      ui.toast("The revive was interrupted")
    elseif held_for >= REVIVE_HOLD then
      local revived = reviving.who
      reviving = nil
      stop_reviving()
      pcall(net.send, revived == net.host() and "host" or revived, "revive", true)
      log.info("revived %s", revived)
      pcall(ui.place_banner, name_of(revived) .. " revived")
    else
      if held_for >= KNEEL_AT then pcall(player.set_animation_speed, 0) end
      ui.status("Reviving " .. name_of(reviving.who), held_for / REVIVE_HOLD)
    end
  elseif reviving then
    reviving = nil
    stop_reviving()
  elseif nearby and held and not wait_for_release then
    ui.prompt(nil)
    reviving = { who = nearby, since = now(), hp = hp }
    -- The game doesn't see the held button (or anything else) meanwhile: a gesture ends at any
    -- action, the held A included (it stood the reviver straight up again).
    pcall(input.block_actions, true)
    pcall(input.block_interact, true)
    pcall(player.play_animation, REVIVE_POSE)
    pcall(net.send, "all", "reviving", { target = nearby })
  elseif nearby then
    ui.prompt((input.using_pad() and "A" or "E") .. ": Revive " .. name_of(nearby) .. " (hold)")
  else
    ui.prompt(nil)
  end
end

kindle.on("frame", function()
  revive_frame()
  revivers_frame()
end)
