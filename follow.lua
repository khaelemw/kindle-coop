-- Staying together: a player follows the host's travel, and joins again whenever its game sends it
-- home, until it leaves co-op itself.
--
-- Following: when the host goes to another place (a bonfire's travel, its death's reload, any
-- loading screen) its players would stay in its world where the host was, without it. The host
-- tells them ("follow"); each leaves the session and joins again as soon as the host's game has
-- its character in the new world (Kindle takes joins from then: session.rs arrival), so the
-- player's load runs alongside the host's and ends about when it does, without going home first.
-- Its game would send it home after the leave ("connection error, returning to your world", a
-- load of its own world, then a second load to join again): while following that's refused
-- (flow.lua, world.reload_requested) and its notices hidden. A player whose death counts can't
-- join where it lies (its game drops the join at once): it goes home as its death has it, and
-- joins again from there.
--
-- Joining again: a player sent home with no session (its death, the host's: the game's own
-- "HostDead_1" sends every guest home when the host dies) joins its session again, so the party
-- carries on after a load; every REJOIN_EVERY, until the host can't be reached for
-- REJOIN_GIVE_UP or the player leaves co-op (kindle.net.leave, the Co-op tab's Leave).
local party = require("party")
local net, game, player, ui, log = kindle.net, kindle.game, kindle.player, kindle.ui, kindle.log

local follow = {}

-- A follow: how long it tries before giving up and letting the game send the player home, how
-- often it asks to join (the host refuses while it's loading), and how long a player that arrived
-- where the host was but outside its session waits before joining again.
local FOLLOW_AT_MOST = 60 -- seconds
local FOLLOW_RETRY = 0.25
local FOLLOW_ALONE_FOR = 3
-- Joining again: how long between tries, and how long the host may be unreachable before the
-- player stops.
local REJOIN_EVERY = 10
local REJOIN_GIVE_UP = 120
-- A refusal for a DLC is told once its player is in a world (a follower is turned away just
-- before it's sent home: shown at once, the notice was over by the end of the loading screen,
-- verified 2026-10-10): this long after the refusal, and once in a world this long; on screen
-- for REFUSAL_NOTICE_FOR.
local NOTICE_AFTER, NOTICE_SETTLE, REFUSAL_NOTICE_FOR = 3, 2, 8

-- The code of the session this player is in or was last in (joined again with), nil once it
-- left co-op or gave up.
local session_code
-- Following the host: { since, joined (joined it again), loading (that join's load started),
-- alone_since (in the world, outside a session, after the join's load) }; nil otherwise.
local following
-- The game asked to send this player home while it followed, and was refused (flow.lua): if the
-- follow gives up, Kindle sends it home itself.
follow.reload_refused = false
-- A join under way (kindle.net.join), and when the last one started.
local join_pending, last_try_at = false, nil
-- Joining again: since when the host hasn't been reachable.
local missing_since
-- The last refusal for a DLC told (once per reason), and the notice due: {text, at}.
local last_refusal, refusal_notice
-- This player left co-op itself (kindle.net.leave or the Co-op tab): its game's "connection
-- error" notice as it goes home isn't one (flow.lua).
follow.left_by_choice = false
-- This mod left the session itself (a follow given up): that leave isn't the player's choice.
local own_leave = false
local in_world_since

local function now() return kindle.time() end

-- Whether this player follows the host's travel now.
function follow.following()
  return following ~= nil and now() - following.since < FOLLOW_AT_MOST
end

local function state() return net.state() end

local function is_dlc_refusal(why)
  return why ~= nil and why:find("which this game doesn't have", 1, true) ~= nil
end

local function tell_refusal(why)
  if not is_dlc_refusal(why) or why == last_refusal then return end
  last_refusal = why
  refusal_notice = { text = "Can't join the host for now: " .. why .. ". You'll join again when it can take you.", at = now() }
end

local function refusal_notice_frame()
  if not refusal_notice or now() - refusal_notice.at < NOTICE_AFTER then return end
  if not in_world_since or now() - in_world_since < NOTICE_SETTLE then return end
  ui.toast(refusal_notice.text, { seconds = REFUSAL_NOTICE_FOR })
  refusal_notice = nil
end

-- A player who couldn't follow the host goes home: Kindle sends it if its game's own send-home
-- was refused while following; otherwise the game does it itself.
local function stop_following()
  following = nil
  local refused = follow.reload_refused
  follow.reload_refused = false
  if refused and player.loaded() and state() == "none" then
    log.info("sending this player home")
    -- The game's session may be halfway into the gone host's (its join under way as the host
    -- left): it's left first, else the game ended the world just after the player got home and
    -- went to the title screen (verified 2026-10-09 with two games on one PC).
    own_leave = true
    pcall(net.leave, true)
    local ok, err = pcall(game.call, "world.send_home")
    if not ok then log.warn("couldn't send this player home (%s); it stays where the host was", err) end
  end
end

-- The host: it goes to another place, and its players follow.
local host_was_in_world = false
local function host_frame()
  local in_world = player.loaded()
  if host_was_in_world and not in_world and party.together() then
    log.info("travelling; the players follow")
    pcall(net.send, "all", "follow", true)
  end
  host_was_in_world = in_world
end

-- A player: the host travelled.
net.on("follow", function(_, from)
  if not party.from_host(from) then return end
  -- A player whose death counts can't join again where it lies.
  local dead = party.dying or (player.loaded() and player.hp() <= 0)
  if dead then
    log.info("the host travelled; this player is dead, so it goes home and joins again from there")
  else
    log.info("the host travelled; following it")
    following = { since = now(), joined = false, loading = false }
    follow.reload_refused = false
    last_try_at = nil
  end
  pcall(net.leave, true)
end)

-- Kindle's session ended: by this game's choice (not a follow's leave, which is for now: the
-- mod's own leaves go with net.leave(true)), no more joining again.
game.on("session.left", function(by_this_game)
  if by_this_game and not following and not own_leave then
    session_code = nil
    follow.left_by_choice = true
  end
  own_leave = false
end)

-- Starts a join of the session; `done(result, why)` once it's made or failed.
local function try_join(done)
  join_pending, last_try_at = true, now()
  local ok, err = pcall(net.join, session_code, function(result, why)
    join_pending = false
    done(result, why)
  end)
  if not ok then
    join_pending = false
    log.debug("couldn't start a join: %s", err)
  end
end

local function following_frame()
  if now() - following.since >= FOLLOW_AT_MOST then
    log.warn("couldn't follow the host; going home")
    stop_following()
    return
  end
  local in_world = player.loaded()
  if following.joined then
    -- Following until the player is in the host's world: the game's send-home (a few seconds
    -- after the leave) may come during the join.
    local current = state()
    if not in_world then
      following.loading = true
    elseif following.loading and current == "joined" then
      log.info("followed the host")
      following = nil
    elseif not following.loading and (current == "none" or current == "join failed") then
      following.joined = false
    elseif following.loading and (current == "none" or current == "join failed") then
      following.alone_since = following.alone_since or now()
      if now() - following.alone_since >= FOLLOW_ALONE_FOR then
        log.info("arrived where the host was, but not in its session; joining again")
        following.joined, following.loading, following.alone_since = false, false, nil
      end
    end
    return
  end
  -- Straight after the host: a join every FOLLOW_RETRY, in as soon as the host takes one.
  if join_pending or net.role() ~= nil or state() ~= "none" or not in_world then return end
  if last_try_at and now() - last_try_at < FOLLOW_RETRY then return end
  try_join(function(result, why)
    if not following then
      -- Given up meanwhile: a join made now isn't kept.
      if result == "joined" then
        own_leave = true
        pcall(net.leave, true)
      end
      return
    end
    if result == "joined" then
      log.info("following the host: joined it again")
      following.joined = true
    elseif result == "gone" then
      log.warn("the host is gone (%s); going home", why)
      stop_following()
    elseif result == "refused" and is_dlc_refusal(why) then
      log.warn("can't follow the host (%s); going home", why)
      tell_refusal(why)
      stop_following()
    else
      log.debug("following the host: %s", why)
    end
  end)
end

local function rejoin_frame()
  if join_pending or net.role() ~= nil or state() ~= "none" or not player.loaded() then return end
  if last_try_at and now() - last_try_at < REJOIN_EVERY then return end
  try_join(function(result, why)
    if result == "joined" then
      log.info("back to the session (joined again)")
      missing_since = nil
    elseif result == "gone" then
      missing_since = missing_since or now()
      if now() - missing_since > REJOIN_GIVE_UP then
        log.warn("the host can't be reached any more; not joining again")
        session_code, missing_since = nil, nil
      end
    else
      log.warn("couldn't join the session again: %s", why)
      tell_refusal(why)
    end
  end)
end

kindle.on("frame", function()
  local in_world = player.loaded()
  if in_world then
    in_world_since = in_world_since or now()
  else
    in_world_since = nil
  end
  local role = net.role()
  if role == "host" then
    host_frame()
  else
    host_was_in_world = false
  end
  -- The session this player joined, to join again.
  if role == "player" then
    session_code = net.code() or session_code
    follow.left_by_choice, own_leave = false, false
  end
  refusal_notice_frame()
  if following then
    following_frame()
  elseif session_code and role == nil then
    rejoin_frame()
  end
end)

return follow
