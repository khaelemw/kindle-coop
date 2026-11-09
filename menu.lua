-- The Co-op tab (Esc -> Mods -> Co-op, and the title menu's own Co-op entry): the party (a lobby
-- players gather in at the title before the host starts: lobby.lua) and the session (host one,
-- join one, copy its code, the players' pings, leave). Codes go through the clipboard, as players send them to each
-- other (no typing in a game menu): opening copies the code, joining reads it (a paste button).
-- Each button says what happened.
local lobby_module = require("lobby")
local net, ui = kindle.net, kindle.ui

-- A host from the tab: its code is copied once the session is up, waiting at most this long.
local COPY_CODE_WAIT = 20 -- seconds
local copy_code_since

local function notice(text) ui.toast(text) end

-- A code that only works on the host's network says so.
local function local_code_note(is_local)
  if is_local then return " (This network only: for the internet, see public_address in kindle.toml.)" end
  return ""
end

local function host_session()
  local ok, err = pcall(net.host_session)
  if ok then
    notice("Hosting a session...")
    copy_code_since = kindle.time()
  else
    notice("Couldn't host: " .. tostring(err))
  end
end

local function join_copied(pasted)
  local code = (pasted or ""):match("^%s*(.-)%s*$")
  if code == "" then
    notice("Copy the host's session code first, then choose Join.")
    return
  end
  local ok, err = pcall(net.join, code, function(result, why)
    if result ~= "joined" then notice("Couldn't join: " .. tostring(why)) end
  end)
  if ok then
    notice("Joining the host...")
  elseif tostring(err):find("isn't a session code", 1, true) then
    notice("What's copied isn't a session code. Copy the host's code, then choose Join.")
  else
    notice("Couldn't join: " .. tostring(err))
  end
end

local function copy_code()
  local code, is_local = net.code()
  if not code then
    notice("There's no session code: host a session first.")
  elseif ui.copy(code) then
    notice("Session code " .. code .. " copied: send it to who you're playing with." .. local_code_note(is_local))
  else
    notice("Session code: " .. code .. " (couldn't copy it)")
  end
end

local function players_and_ping()
  local rows = net.pings()
  if #rows == 0 then
    notice("No other players in this session")
    return
  end
  local list = {}
  for _, row in ipairs(rows) do list[#list + 1] = string.format("%s: %d ms", row.name, row.ms) end
  notice(table.concat(list, "   "))
end

local PLACE_NAMES = { title = "at the title", loading = "loading", world = "in the world" }

local function open_party()
  local ok, code = pcall(net.open_lobby)
  if not ok then
    notice("Couldn't open a party: " .. tostring(code))
  elseif ui.copy(code) then
    local _, is_local = net.code()
    notice("Party open. Code " .. code .. " copied: send it to who you're playing with. Load your character when they're in: they join your world." .. local_code_note(is_local))
  else
    notice("Party open. Code: " .. code)
  end
end

local function join_party(pasted)
  local code = (pasted or ""):match("^%s*(.-)%s*$")
  if code == "" then
    notice("Copy the host's party code first, then choose Join the copied party.")
    return
  end
  local ok, err = pcall(net.join_lobby, code, function(result, why)
    if result == "joined" then
      notice("In the party. When the host starts, your character for its world comes to you here.")
    else
      notice("Couldn't join the party: " .. tostring(why))
    end
  end)
  if ok then
    notice("Joining the party...")
  else
    notice("Couldn't join the party: " .. tostring(err))
  end
end

local function start_party()
  local ok, why = lobby_module.start()
  if ok then
    notice("Starting: your character loads, and everyone in the party follows into your world")
  else
    notice("Couldn't start: " .. tostring(why))
  end
end

local function copy_party_code()
  local lobby = net.lobby()
  if not lobby then
    notice("You're not in a party.")
  elseif not lobby.code then
    notice("Only the party's host has its code.")
  elseif ui.copy(lobby.code) then
    notice("Party code " .. lobby.code .. " copied.")
  else
    notice("Party code: " .. lobby.code)
  end
end

local function leave_party()
  local lobby = net.lobby()
  if not lobby then
    notice("You're not in a party.")
    return
  end
  -- A host closes the party, and the session it opened to it (its players go home).
  if lobby.role == "host" and net.role() == "host" then pcall(net.leave) end
  net.leave_lobby()
  notice("Left the party.")
end

local function leave_session()
  local role = net.role()
  if role == nil then
    notice("You're not in a session.")
    return
  end
  local ok, err = pcall(net.leave)
  if not ok then
    notice("Couldn't leave: " .. tostring(err))
  elseif role == "host" then
    notice("Session ended.")
  else
    notice("Leaving the session...")
  end
end

-- The tab shows what can be done now, and the party: at the title, opening or joining a party, and
-- the host's Start (the title menu's own "Co-op" entry opens just this tab); in the world, the
-- session's buttons too. Each member of the party is a line of its own (greyed: information), with
-- where it is. The tab is made again whenever what it shows changes.
local REBUILD_EVERY = 0.25 -- seconds between looks at what the tab shows
local LABEL_MAX = 48 -- a row's label, at most (Kindle's limit)
local MEMBER_ROWS_MAX = 6

local OPEN_PARTY = {
  label = "Open a party",
  help = "Players join it from the title screen; then you start, and everyone goes into your world together. Its code is copied for you: send it to them.",
  on_press = open_party,
}
local JOIN_PARTY = {
  label = "Join the copied party",
  help = "Copy the host's party code, then choose this. When the host starts, your character for its world loads (the first time, you make one).",
  paste = true,
  on_press = join_party,
}
local START_PARTY = {
  label = "Start the party",
  help = "Once everyone's in: you all go in together. Your character loads, and each player's game loads its character for your world (or New Game, the first time) and joins you.",
  on_press = start_party,
}
local COPY_PARTY_CODE = { label = "Copy the party code", help = "Copies the party's code again, to send to someone who wants to join.", on_press = copy_party_code }
local CLOSE_PARTY = { label = "Close the party", help = "Closes the party, and the session you opened to it: players go home.", on_press = leave_party }
local LEAVE_PARTY = { label = "Leave the party", help = "Leave the party: your own characters again, at the title.", on_press = leave_party }
local HOST_SESSION = { label = "Host a session", help = "Others join your world. The session code is copied for you: send it to them.", on_press = host_session }
local JOIN_SESSION = { label = "Join with the copied code", help = "Copy the host's session code, then choose this to join their world.", paste = true, on_press = join_copied }
local COPY_SESSION_CODE = { label = "Copy the session code", help = "Copies this session's code again, to send to someone who wants to join.", on_press = copy_code }
local PLAYERS_AND_PING = {
  label = "Players and ping",
  help = "Each player's ping in ms. On the HUD, under your bars: green under 80 ms, orange under 150, red above.",
  on_press = players_and_ping,
}
local LEAVE_SESSION = { label = "Leave the session", help = "Players go home; a host ends the session.", on_press = leave_session }

local function shortened(text)
  if #text <= LABEL_MAX then return text end
  return text:sub(1, LABEL_MAX - 3) .. "..."
end

local function info(label, help)
  return { label = shortened(label), help = help or "", info = true }
end

-- The world a host's party plays in, in words (Kindle's key is the character's name and its save
-- slot).
local function world_words(world)
  if not world then return nil end
  return (world:gsub("_%d+$", ""))
end

-- Where a member is, in a row's few words (the rows are narrow).
local SHORT_PLACES = { title = "title", loading = "loading", world = "in world" }

-- The party's lines: one per member, where it is, the host first.
local function party_lines(lobby, rows)
  local count = 0
  for pass = 1, 2 do
    for _, member in ipairs(lobby.members) do
      local is_host = member.id == lobby.host
      if (pass == 1) == is_host and count < MEMBER_ROWS_MAX then
        count = count + 1
        local where = SHORT_PLACES[member.place] or member.place
        local help = member.name .. (member.id == lobby.me and " (you)" or "") .. ": " .. (PLACE_NAMES[member.place] or member.place)
        rows[#rows + 1] = info((is_host and "Host " or "") .. member.name .. ": " .. where, help)
      end
    end
  end
end

-- The tab's rows for what this game can do now.
local function tab_rows()
  local rows = {}
  local lobby = net.lobby()
  local in_world = kindle.player.loaded()
  if lobby and lobby.role == "host" then
    local world = world_words(lobby.world)
    if not in_world then
      rows[#rows + 1] = info(world and ("Your world: " .. world .. "'s") or "Your world: the character you load",
        "Continue loads the character you last played: the party plays in its world")
    end
    party_lines(lobby, rows)
    if not in_world then rows[#rows + 1] = START_PARTY end
    rows[#rows + 1] = COPY_PARTY_CODE
    rows[#rows + 1] = CLOSE_PARTY
  elseif lobby then
    if not in_world then rows[#rows + 1] = info(lobby_module.member_status(), "What happens next") end
    party_lines(lobby, rows)
    rows[#rows + 1] = LEAVE_PARTY
  else
    rows[#rows + 1] = OPEN_PARTY
    rows[#rows + 1] = JOIN_PARTY
  end
  if in_world then
    local role = net.role()
    if role == nil then
      rows[#rows + 1] = HOST_SESSION
      rows[#rows + 1] = JOIN_SESSION
    else
      if role == "host" then rows[#rows + 1] = COPY_SESSION_CODE end
      rows[#rows + 1] = PLAYERS_AND_PING
      rows[#rows + 1] = LEAVE_SESSION
    end
  end
  return rows
end

-- What a tab shows, to see when it changes.
local function signature(rows)
  local parts = {}
  for _, row in ipairs(rows) do parts[#parts + 1] = row.label end
  return table.concat(parts, "\n")
end

local shown, looked_at = nil, nil
local function refresh_tab()
  local rows = tab_rows()
  local now_shows = signature(rows)
  if now_shows == shown then return end
  local ok, err = pcall(ui.mod_tab, "Co-op", rows)
  if ok then
    shown = now_shows
  else
    kindle.log.warn("the Co-op tab: %s", err)
  end
end
refresh_tab()
ui.title_entry("Co-op", "Play together: open or join a party here; the host starts it and everyone goes in together")

-- The party's comings and goings, said as they happen.
local members_seen = nil
local function party_news()
  local lobby = net.lobby()
  if not lobby then
    members_seen = nil
    return
  end
  local now_in = {}
  for _, member in ipairs(lobby.members) do now_in[member.id] = member.name end
  if members_seen then
    for id, name in pairs(now_in) do
      if not members_seen[id] and id ~= lobby.me then notice(name .. " joined the party") end
    end
    for id, name in pairs(members_seen) do
      if not now_in[id] then notice(name .. " left the party") end
    end
  end
  members_seen = now_in
end

kindle.on("frame", function()
  local now = kindle.time()
  if looked_at and now - looked_at < REBUILD_EVERY then return end
  looked_at = now
  refresh_tab()
  party_news()
end)

-- A host from the tab gets its code copied once the session is up.
kindle.on("frame", function()
  if not copy_code_since then return end
  local code, is_local = net.code()
  if code then
    copy_code_since = nil
    if ui.copy(code) then
      notice("Hosting. Session code " .. code .. " copied: send it to who you're playing with." .. local_code_note(is_local))
    else
      notice("Hosting. Session code: " .. code)
    end
  elseif kindle.time() - copy_code_since > COPY_CODE_WAIT then
    copy_code_since = nil
    notice("The session didn't start.")
  end
end)
