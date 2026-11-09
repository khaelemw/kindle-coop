-- The party: players gather in a lobby before anyone loads, from the title screen on (Kindle's
-- lobby, kindle.net), then the host starts: it loads its character, and its world opens to the
-- party. One character per player per host world (2026-10-18): a player who has one in
-- that world is given it (its party save, which the host keeps with its world); the first time it
-- has none, and its game's main menu offers New Game: the character made there is its own in that
-- world. Each member in its world then joins the host's session by itself (no codes typed).
--
-- The host: it sends each member its party save for its world (from the title on: the world its
-- Continue loads), and once in its world it hosts the session and tells the lobby its code
-- ("world"). A member: its party save is put in place at its
-- main menu (Kindle; the events below tell it what to say), and once it's in its world with the
-- host's open, it joins it. Leaving the session by choice (the Co-op tab) stops that: a member
-- isn't joined to the same world again, and a host doesn't open its world to the party again until
-- it has left it. Travel, deaths and rejoins after that are the session's (follow.lua).
--
-- Starting together (2026-10-18): the host's Start (the Co-op tab, at the title) tells
-- the party, and every game goes on from its title by itself: the host's continues at once (its
-- main menu's Continue), a member's as soon as its party save for the host's world is in place
-- (Continue, its character there; New Game the first time, left for the player to make one). A
-- game goes on from its title the way a player would: its main menu built anew (back to "PRESS
-- ANY BUTTON", title.back_to_press_start: the first entry chosen), A through "PRESS ANY BUTTON"
-- and the notices, and A once at the main menu. A menu open over the title (the Mods screen) is
-- closed first.
local follow = require("follow")
local net, game, player, ui, log = kindle.net, kindle.game, kindle.player, kindle.ui, kindle.log

local RETRY_EVERY = 1 -- seconds between tries to host or join while the game can't yet
local PRESS_EVERY = 1.5 -- seconds between the presses that take a game on from its title
local GO_ON_LIMIT = 60 -- seconds a game is taken on from its title before giving up
local NOT_AT_TITLE, BEFORE_MAIN_MENU, MAIN_MENU = 0, 1, 2 -- title.screen

local lobby_module = {}

-- The host: the session code it last told the lobby; the members it last told (to tell a new one
-- too); the members sent their party save, by id: the world it was for; whether it left its session
-- by choice (no reopening until it leaves its world); when it last tried to host.
local told_code, told_members, saves_sent, host_paused, host_tried_at = nil, "", {}, false, nil
-- A member: the host's session code (nil while its world isn't open); the code it joined (or left
-- by choice), not joined again; when it last tried to join; whether a join is under way.
local world_code, joined_code, join_tried_at, join_pending = nil, nil, nil, false
-- Whether the session left by choice was seen (follow.left_by_choice).
local left_by_choice_seen = false
-- Starting together: the host started (a member's view; nil before); this game is to go on from its
-- title (and whether its main menu was built anew since, when it last pressed); a member's party
-- save in place (nil before, else whether it has a character).
local started, going_on, menu_fresh, pressed_at, going_on_since, save_has_character = false, false, false, nil, nil, nil

local function notice(text) ui.toast(text) end

local function now() return kindle.time() end

-- The host's session code, as a member gets it.
net.on("world", function(code, from)
  local lobby = net.lobby()
  if not lobby or lobby.role ~= "member" or from ~= lobby.host then return end
  local opened = world_code == nil and type(code) == "string" and code ~= ""
  world_code = (type(code) == "string" and code ~= "") and code or nil
  if opened and not player.loaded() then notice("The host's world is open: load your character to join it") end
end)

-- What the member's game does with its party save (Kindle puts it in place at the main menu).
-- The host started the party.
net.on("start", function(_, from)
  local lobby = net.lobby()
  if not lobby or lobby.role ~= "member" or from ~= lobby.host then return end
  started = true
  notice("The host started: your character loads as soon as its world is open")
end)

game.on("saves.party_save_ready", function(has_character)
  save_has_character = has_character
  if has_character then
    notice("Your character for the host's world is ready: it loads when the host starts the party")
  else
    notice("Your first time in the host's world: when the host starts, you make your character for it (New Game)")
  end
end)
game.on("saves.party_save_waiting", function()
  notice("Your character for the host's world is ready: quit to the title (System > Quit Game) to play it")
end)
-- Out of the party (2026-10-18): a member in its world goes to the title, as Quit Game
-- does, not on in its own world; its own characters are back at the main menu.
local function quit_to_title()
  local ok, asked = pcall(game.call, "world.quit_to_title")
  if not ok then log.warn("couldn't quit to the title (%s)", asked) end
  return ok and asked
end
game.on("saves.party_save_left", function()
  if quit_to_title() then
    notice("Out of the party: back to the title for your own characters")
  else
    notice("Out of the party: your character's progress in the host's world isn't kept from now on. Quit to the title for your own characters")
  end
end)
game.on("saves.own_saves_back", function()
  notice("Your own characters again: press any button")
end)
game.on("lobby.closed", function()
  notice("The host closed the party")
  quit_to_title()
end)

-- This game left its session by choice (follow.lua says): a member isn't joined to that world
-- again; a host's world isn't opened to the party again until it leaves it.
local function left_by_choice_frame(lobby)
  if not follow.left_by_choice then
    left_by_choice_seen = false
    return
  end
  if left_by_choice_seen then return end
  left_by_choice_seen = true
  if lobby.role == "host" then
    host_paused = true
  else
    joined_code = world_code
  end
end

-- Takes this game on from its title, as a player would (the comment at the top).
local function going_on_frame()
  if not going_on then return end
  -- Done once its character is in (or given up after GO_ON_LIMIT). Not at the title for a moment
  -- (its re-init after title.back_to_press_start): waits.
  if player.loaded() or now() - going_on_since > GO_ON_LIMIT then
    if not player.loaded() then log.warn("this game didn't go on from its title by itself") end
    going_on = false
    return
  end
  local read_ok, screen = pcall(game.get, "title.screen")
  if not read_ok or screen == NOT_AT_TITLE then return end
  if pressed_at and now() - pressed_at < PRESS_EVERY then return end
  pressed_at = now()
  local menu_ok, menu_open = pcall(game.get, "ui.menu_open")
  if menu_ok and menu_open then
    pcall(kindle.input.press, "pad_b", 0.2)
  elseif screen == BEFORE_MAIN_MENU then
    menu_fresh = true
    pcall(kindle.input.press, "pad_a", 0.2)
  elseif screen == MAIN_MENU and not menu_fresh then
    menu_fresh = pcall(game.call, "title.back_to_press_start")
  elseif screen == MAIN_MENU then
    -- The main menu built anew: its first entry (Continue, or New Game), once.
    pcall(kindle.input.press, "pad_a", 0.2)
    going_on = false
  end
end

local function go_on_from_title()
  going_on, menu_fresh, pressed_at, going_on_since = true, false, nil, now()
end

-- The Co-op tab's Start: the host tells the party and goes on from its title.
function lobby_module.start()
  local lobby = net.lobby()
  if not lobby or lobby.role ~= "host" then return false, "Only the party's host starts it" end
  local read_ok, screen = pcall(game.get, "title.screen")
  if not read_ok or screen == NOT_AT_TITLE then return false, "Start from the title" end
  pcall(net.lobby_send, "all", "start", true)
  go_on_from_title()
  return true
end

-- A member at the title: what happens next, in a line (the Co-op tab shows it).
function lobby_module.member_status()
  if save_has_character == nil then return "Waiting for your character for the host's world" end
  if started then return "The host started: your character is loading" end
  if save_has_character then return "Your character is ready: waiting for the host to start" end
  return "Ready: you make your character when the host starts"
end

-- Other mods (and Kindle's console) can start the party as the Co-op tab's button does.
kindle.export({ start_party = function() return lobby_module.start() end })

local function host_frame(lobby)
  local in_world = player.loaded()
  if not in_world then host_paused = false end
  -- In its world, the host opens it to the party: the session, then its code.
  if in_world and not host_paused and net.role() == nil and (net.state() == "none" or net.state() == "create failed")
    and (not host_tried_at or now() - host_tried_at >= RETRY_EVERY) then
    host_tried_at = now()
    local ok, err = pcall(net.host_session)
    if ok then
      log.info("the host is in its world; hosting the session for the party")
    else
      log.warn("couldn't host the session for the party (%s)", err)
    end
  end
  local code = net.code()
  local member_ids = {}
  for _, member in ipairs(lobby.members) do member_ids[#member_ids + 1] = member.id end
  local members_now = table.concat(member_ids, ",")
  if code ~= told_code or members_now ~= told_members then
    local opened = told_code == nil and code ~= nil
    if pcall(net.lobby_send, "all", "world", code or "") or #lobby.members <= 1 then
      told_code, told_members = code, members_now
      if opened and #lobby.members > 1 then notice("Your world is open to the party") end
    end
  end
  -- Each member gets its party save for the party's world, once per world (again if it left and
  -- came back): at the title already, for the world the host's Continue loads (lobby.world), so
  -- its character is in place before the host starts and everyone loads together; again from the
  -- world if the host's character turned out to be another's.
  local in_lobby = {}
  for _, member in ipairs(lobby.members) do in_lobby[member.id] = true end
  for member_id in pairs(saves_sent) do
    if not in_lobby[member_id] then saves_sent[member_id] = nil end
  end
  if lobby.world then
    for _, member in ipairs(lobby.members) do
      if member.id ~= lobby.me and saves_sent[member.id] ~= lobby.world then
        local ok, world = pcall(net.send_party_save, member.id)
        if ok then
          saves_sent[member.id] = world
          log.info("sent %s its character for %s", member.name, world)
        end
      end
    end
  end
end

local function member_frame()
  -- Started, and this game's party save in place: on from the title.
  if started and save_has_character ~= nil and not going_on then
    local has_character = save_has_character
    save_has_character, started = nil, false
    go_on_from_title()
    log.info("the party started; this game goes on from its title (%s)", has_character and "Continue" or "New Game")
  end
  -- A member in its world, with no session, joins the host's world once it's open.
  if not world_code or not player.loaded() or net.role() ~= nil or joined_code == world_code or join_pending then return end
  if join_tried_at and now() - join_tried_at < RETRY_EVERY then return end
  if net.state() ~= "none" and net.state() ~= "join failed" then return end
  join_tried_at, join_pending = now(), true
  local code = world_code
  local ok = pcall(net.join, code, function(result, why)
    join_pending = false
    if result == "joined" then
      joined_code = code
      log.info("joined the host's world")
    elseif result == "refused" then
      joined_code = code
      notice("The host's world turned you away: " .. tostring(why))
    else
      log.debug("not joined the host's world yet (%s)", tostring(why))
    end
  end)
  if not ok then join_pending = false end
end

kindle.on("frame", function()
  local lobby = net.lobby()
  if not lobby then
    told_code, told_members, saves_sent, host_paused = nil, "", {}, false
    world_code, joined_code, join_pending = nil, nil, false
    started, save_has_character = false, nil
    going_on_frame()
    return
  end
  going_on_frame()
  left_by_choice_frame(lobby)
  if lobby.role == "host" then
    host_frame(lobby)
  else
    member_frame()
  end
end)

return lobby_module
