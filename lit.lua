-- Bonfires lit for everyone. A bonfire a player lights is lit in the host's world ("light"), so
-- the world changes only there (2026-10-11) and then, as any bonfire the host has lit,
-- in every player's own world: bonfires are lit for everyone, as with Seamless Co-op. A bonfire
-- the host lit was lit only in its world: a player's game in a session keeps its own copy of
-- those flags (kindle.flags' "session" set, apart from the character's "own"), and back home it
-- couldn't travel there (verified 2026-10-10 with two games on one PC: High Wall of Lothric,
-- flag 13000009, lit for the host, unlit for the player in the session and at home). The host
-- sends its players the lit flags of its bonfires ("lit") when they change and every
-- RESEND_EVERY seconds; a player sets those it hasn't in its own flags (as an event script lights
-- a bonfire), but not a DLC's it doesn't have: in the session, in its own set, so a player that
-- quits in the host's world has them too; one that couldn't, once a load has taken it home.
local party = require("party")
local net, flags, world, player, game, log = kindle.net, kindle.flags, kindle.world, kindle.player, kindle.game, kindle.log

local CHECK_EVERY, RESEND_EVERY = 2, 10 -- seconds
-- Bonfires players lit, kept for the host's next frame at most.
local MAX_LIGHTS = 64

-- The host: the lit flags it last sent, and when; when it last looked; bonfires its players lit,
-- to light in its world; the entities of those whose fire is still to light.
local last_sent, last_sent_at, last_checked_at
local lit_by_players, fires_to_light = {}, {}
-- A player: the host's lit bonfires, to set at home (flag -> true); those handled since its last
-- load (the host sends them all every RESEND_EVERY; its own set is used only for new ones); the
-- bonfires lit in its session's flags at the last check, and when; whether the world it's in is a
-- host's (until its next load: set straight after the leave, still in the host's world, the flags
-- were gone at home, the game's own load).
local due, handled = {}, {}
local lit_at_last_check, last_check_at
local in_host_world = false
local in_world_since

-- The game's bonfires with a lit flag, by that flag.
local function bonfires_by_flag()
  local by_flag = {}
  for _, bonfire in ipairs(world.bonfires()) do
    if bonfire.flag > 0 then by_flag[bonfire.flag] = bonfire end
  end
  return by_flag
end

-- The bonfires lit in the flag set in use (flag -> true).
local function lit_now()
  local lit = {}
  for flag, bonfire in pairs(bonfires_by_flag()) do
    if bonfire.lit then lit[flag] = true end
  end
  return lit
end

-- A set's keys as a sorted list.
local function sorted_keys(set)
  local list = {}
  for key in pairs(set) do list[#list + 1] = key end
  table.sort(list)
  return list
end

-- Sets the bonfires' lit flags (in `flag_set`, nil the one in use), those not set yet and not a
-- DLC's this game doesn't have; their names.
local function light(flag_list, flag_set)
  local by_flag, names = bonfires_by_flag(), {}
  for _, flag in ipairs(flag_list) do
    local bonfire = by_flag[flag]
    local read_ok, is_lit = pcall(flags.get, flag, flag_set)
    if bonfire and read_ok and not is_lit and (bonfire.dlc == 0 or kindle.dlc_installed(bonfire.dlc) == true) then
      local set_ok, err = pcall(flags.set, flag, true, flag_set)
      if set_ok then
        names[#names + 1] = bonfire.name or tostring(flag)
      else
        log.warn("couldn't light bonfire flag %d: %s", flag, err)
      end
    end
  end
  return names
end

-- The host: a player lit a bonfire.
net.on("light", function(flag)
  if net.role() == "host" and math.type(flag) == "integer" and #lit_by_players < MAX_LIGHTS then lit_by_players[#lit_by_players + 1] = flag end
end)

-- A player: the host's lit bonfires.
net.on("lit", function(flag_list, from)
  if not party.from_host(from) or type(flag_list) ~= "table" then return end
  for _, flag in ipairs(flag_list) do
    if math.type(flag) == "integer" then due[flag] = true end
  end
end)

local function host_frame(now, in_world)
  -- A bonfire a player lit is the host's world's, as if the host had lit it.
  if #lit_by_players > 0 then
    local by_flag = bonfires_by_flag()
    for _, flag in ipairs(lit_by_players) do
      -- (A bonfire's flag only: no other flag of the host's is a player's to set this way.)
      local read_ok, is_lit = pcall(flags.get, flag)
      if by_flag[flag] and read_ok and not is_lit then
        local set_ok, err = pcall(flags.set, flag, true)
        if set_ok then
          log.info("a player lit a bonfire (flag %d); it's lit in this world", flag)
          last_checked_at = nil
          local bonfire = by_flag[flag]
          if bonfire and bonfire.entity_id > 0 then fires_to_light[#fires_to_light + 1] = bonfire.entity_id end
        else
          log.warn("couldn't light the bonfire a player lit (%d): %s", flag, err)
        end
      end
    end
    lit_by_players = {}
  end
  -- Its fire, one a frame (false: an earlier one still waits).
  if fires_to_light[1] then
    local call_ok, fire_lit = pcall(game.call, "bonfire.light_fire", fires_to_light[1])
    if not call_ok or fire_lit then table.remove(fires_to_light, 1) end
  end
  if (last_checked_at and now - last_checked_at < CHECK_EVERY) or not in_world then return end
  last_checked_at = now
  local lit_list = sorted_keys(lit_now())
  local changed = not last_sent or table.concat(last_sent, ",") ~= table.concat(lit_list, ",")
  if changed or now - last_sent_at >= RESEND_EVERY then
    pcall(net.send, "all", "lit", lit_list)
    last_sent, last_sent_at = lit_list, now
  end
end

local function player_frame(now, in_world)
  in_host_world = true
  -- A bonfire this player lights is lit in its session's flags only (the host's world doesn't
  -- know): it tells the host, whose world it's in, as a light of the host's.
  if not in_world or net.state() ~= "joined" then
    lit_at_last_check = nil
  elseif not last_check_at or now - last_check_at >= CHECK_EVERY then
    last_check_at = now
    local lit = lit_now()
    if lit_at_last_check then
      for flag in pairs(lit) do
        if not lit_at_last_check[flag] then
          log.info("this player lit a bonfire (flag %d); telling the host", flag)
          pcall(net.send, "host", "light", flag)
        end
      end
    end
    lit_at_last_check = lit
  end
  if not in_world then handled = {} end
  for flag in pairs(due) do
    if handled[flag] then due[flag] = nil end
  end
  local read_ok, set_in_use = pcall(flags.set_in_use)
  if next(due) == nil or not in_world or not read_ok or set_in_use ~= "session" then return end
  local flag_list = sorted_keys(due)
  -- Its own set must have the bonfires' table now.
  if not pcall(flags.get, flag_list[1], "own") then return end
  due = {}
  for _, flag in ipairs(flag_list) do handled[flag] = true end
  local names = light(flag_list, "own")
  if #names > 0 then log.info("lit the bonfires the host lit, in this character's own world: %s", table.concat(names, ", ")) end
end

local function home_frame(now, in_world)
  if not in_world then in_host_world = false end
  local read_ok, set_in_use = pcall(flags.set_in_use)
  if next(due) == nil or in_host_world or not read_ok or set_in_use ~= "own" or net.state() ~= "none"
    or not in_world_since or now - in_world_since < 1 then
    return
  end
  local flag_list = sorted_keys(due)
  due = {}
  local names = light(flag_list)
  if #names > 0 then log.info("lit the bonfires the host lit: %s", table.concat(names, ", ")) end
end

kindle.on("frame", function()
  local now, in_world = kindle.time(), player.loaded()
  if in_world then
    in_world_since = in_world_since or now
  else
    in_world_since = nil
  end
  local role = net.role()
  if role == "host" then
    host_frame(now, in_world)
  elseif role == "player" then
    player_frame(now, in_world)
  else
    home_frame(now, in_world)
  end
end)
