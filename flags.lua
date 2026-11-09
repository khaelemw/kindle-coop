-- Event flags in a session: what is each player's own (pickups, shops, the 6000s), what is the host's
-- world's (its shared flags as they change, the 2000s and 8000s, the NPCs' stories), and changes reaching the
-- host. A player's game uses the session's flag set (kindle.flags' "session"), which the game fills
-- with the host's whole flag state at the join and keeps current only with the host's
-- network-connected sets.
local party = require("party")
local net, game, flags, events, player, log = kindle.net, kindle.game, kindle.flags, kindle.events, kindle.player, kindle.log

-- What a player has picked up is kept with its character, as a host's is: the session set has no
-- tables for the 5s (the pickups' flags) nor the 7s, so the game couldn't set its pickups' flags and
-- its treasure was back at every load (verified 2026-10-09). Those tables are the character's own;
-- the host's flags aren't touched. The 7s' shop flags (322 of their 356 stock flags and 348 of 476
-- release flags) likewise: a player shops with what it has bought and unlocked. Among the 7s the
-- NPCs' stories are the world's (STORIES below).
local OWN_DIGITS = { 5, 7 }

-- The character's own progress among the low flags: 6000..6999, the thousand the game doesn't share
-- (only the 0, 1, 5 and 9 thousands go between games under 10,000,000). It holds the Ashen Estus
-- Flask's (6010) and its levels', the gestures' (6050..6084), each boss's soul for Ludleth (63xx)
-- and the Shrine Handmaid's one-off goods (6800, 6820). In a session the game uses the session's
-- copy: a player saw another's (or none) and lost what it did there at home. The character's go
-- into the session's copy as a session's copy is first used, and the session's back into the
-- character's whenever they change.
local OWN_THOUSAND = 6000

-- The host's world among the low flags the game doesn't share either: the 2000s (2100, the Ringed
-- City's) and 8000s (8200..8263, as bosses die, read by the map variants' events). The host sends
-- its blocks when they change; each player's game puts them in its session copy.
local WORLD_THOUSANDS = { 2000, 8000 }

-- The NPCs' stories among the 7s are the world's: each map's NPCs have a block of 1000 (7AAB0xxx:
-- talked to, quest steps, moved to Firelink, angered), and 70000xxx holds the summon signs and
-- lifecycle switches (0..99) next to the shop unlocks from the ashes a player gave (100..470). In a
-- player's session set those blocks are copies of their own (flags.separate_block) holding the
-- host's values, while every other 7s block (the merchants' stock, the covenant altars, the crow's
-- trades) is the character's. A change a player's game makes to the world's goes to the host,
-- whose world it is; the host's next blocks bring it back. {first flag, how many from it}.
local STORIES = {
  { 70000000, 100 }, { 73000000, 1000 }, { 73010000, 1000 }, { 73100000, 1000 }, { 73300000, 1000 },
  { 73410000, 1000 }, { 73500000, 1000 }, { 73700000, 1000 }, { 73800000, 1000 }, { 73900000, 1000 },
  { 74000000, 1000 }, { 74100000, 1000 }, { 74500000, 1000 }, { 75000000, 1000 }, { 75100000, 1000 },
  { 75110000, 1000 },
}
-- Flags among those that only tell a game's own player what to do as an NPC talks to it (the talk
-- gestures, common_func 20006005/20006006 and 20006010/20006011): as the world's they moved every
-- player (the host was moved to the Fire Keeper as a joined player talked to her, 2026-10-14).
-- Likewise a boss's "line said" marks: Oceiros's talk (t300324) says each of his two lines once,
-- when he's within 72 m of the game's own player and below 90% HP, and marks it (73000200,
-- 73000201); as the world's, the host's mark reached the player before its own talk got there, and
-- the player never saw his subtitles (a joined player; then on two games on one PC,
-- 2026-10-19). Lothric's (t341320, the Twin Princes) the same way: his event (m34 13415843, on
-- every game) raises 73410100 for a line, his talk clears it as it speaks and alternates his lines
-- with 73410101/73410102, and marks one said with 73410110; nothing else reads them (found by
-- sweeping the boss talks for marks in the shared blocks after Oceiros; not yet tried in game).
-- They stay each game's own.
local TALKER_ONLY = {
  73100131, 73100132, 73700115, 73700116, 73700118, 73700121, 74000135, 74000137, 74000383, 74000384,
  74000386, 74000387, 74000389, 74000391, 74000430, 74000432, 74000136, 74000138, 74000390, 74000392,
  74000431, 74000433, 73010952, 73100952, 73300952, 73500162, 73700119, 73700952, 75100952, 73500163,
  73000200, 73000201, 73410100, 73410101, 73410102, 73410110,
}
-- The host's world in each map's own flags: the 1s, 2s and 6s an area has (doors and shortcuts,
-- levers, lifts, enemies that stay dead, treasure), those the game shares. The game's join state
-- (packet 0x10, written by +0x4C39F0) carries a map's area flags only for the area the host's
-- character stands in, so after any load (a join, a follow, a wipe) a player's session copy of the
-- other maps it has loaded was what it last was: a door of the Undead Settlement's (63100401, its
-- side of the tower the Road of Sacrifices') opened by the host showed shut after a follow (a
-- joined player; then on two games on one PC, 2026-10-18). A player asks for every map's blocks as
-- its load begins (the host's game, loaded first, has its maps: a follow waits for that) and puts
-- each map's in its session copy as soon as that map's flags are there, during the load: a map's
-- events read their flags as they start, and with the host's arriving only after the load an event
-- took its own branch from the player's old copy (Oceiros's, m30 13005830, read him alive and
-- showed his health bar at Lothric Castle, a joined player 2026-10-19). After the load it asks
-- again, for what the host changed meanwhile.
-- Areas by map (m30_01 is 3010, m51_01 5110), and the first digits of their flags.
local MAP_AREAS = { 3000, 3010, 3100, 3200, 3300, 3410, 3500, 3700, 3800, 3900, 4000, 4100, 4500, 5000, 5100, 5110 }
local AREA_DIGITS = { 1, 2, 6 }

local WORDS = 32 -- a block of 1000 flags is 32 words of 32 bits (the last bits unused)
local ALL_BITS = 0xFFFFFFFF

-- A flag's word (from 1) and bit mask in its block's words: the game keeps a block's first flag
-- in the highest bit of its first word.
local function word_and_bit(offset_in_block)
  return offset_in_block // 32 + 1, 1 << (31 - offset_in_block % 32)
end

-- The world's bits of a story block, as a mask of its words: its first `world_count` flags,
-- without TALKER_ONLY's.
local function story_mask(first_flag, world_count)
  local mask = {}
  for word = 1, WORDS do mask[word] = 0 end
  for offset = 0, math.min(world_count, 1000) - 1 do
    local word, bit = word_and_bit(offset)
    mask[word] = mask[word] | bit
  end
  for _, flag in ipairs(TALKER_ONLY) do
    if flag >= first_flag and flag < first_flag + 1000 then
      local word, bit = word_and_bit(flag - first_flag)
      mask[word] = mask[word] & ~bit & ALL_BITS
    end
  end
  return mask
end
-- Each story block's mask, by its first flag.
local STORY_MASKS = {}
for _, story in ipairs(STORIES) do
  local first_flag, world_count = story[1], story[2]
  STORY_MASKS[first_flag] = story_mask(first_flag, world_count)
end

local function same_words(words_a, words_b)
  if words_a == nil or words_b == nil then return words_a == words_b end
  for word = 1, WORDS do
    if words_a[word] ~= words_b[word] then return false end
  end
  return true
end

-- A block's words from another game, checked (WORDS integers of 32 bits), or nil.
local function checked_words(value)
  if type(value) ~= "table" or #value ~= WORDS then return nil end
  local words = {}
  for word = 1, WORDS do
    local number = math.tointeger(value[word])
    if not number or number < 0 or number > ALL_BITS then return nil end
    words[word] = number
  end
  return words
end

-- Whether the game shares a flag between the games of a session (EventFlag_IsShareable), by its
-- ten-millions digit and thousands digit.
local function shared_flag(flag)
  local thousands_digit, ten_millions_digit = (flag // 1000) % 10, (flag // 10000000) % 10
  if ten_millions_digit == 0 then
    return thousands_digit == 0 or thousands_digit == 1 or thousands_digit == 5 or thousands_digit == 9
  end
  if ten_millions_digit == 1 or ten_millions_digit == 2 then
    return thousands_digit <= 1 or (thousands_digit >= 4 and thousands_digit <= 7)
  end
  if ten_millions_digit == 6 then return thousands_digit == 0 end
  return false
end

-- The first flags of an area's blocks the game shares (an area's thousands are its own: 3100 to
-- 3109 for m31).
local function area_blocks(area)
  local first_flags = {}
  for _, digit in ipairs(AREA_DIGITS) do
    for thousand = 0, 9 do
      local first_flag = digit * 10000000 + (area + thousand) * 1000
      if shared_flag(first_flag) then first_flags[#first_flags + 1] = first_flag end
    end
  end
  return first_flags
end

-- A block's words (kindle.flags.block), and whether it could be read now: during a load the game
-- has no flags for the maps it hasn't loaded, and the read raises ("map has no flags").
local function read_block(first_flag, flag_set)
  local read_ok, words = pcall(flags.block, first_flag, flag_set)
  if not read_ok then return false, nil end
  return true, words
end

-- The game's network-connected set of flags on this game (2003[62] one flag, [63] a range).
local function network_set(first, last, on)
  if first == last then
    return pcall(events.run, 2003, 62, "iB", first, on and 1 or 0)
  end
  return pcall(events.run, 2003, 63, "iiB", first, last, on and 1 or 0)
end

-- ── the host ────────────────────────────────────────────────────────────────────────────────

-- The flags its game changed, to set again as network-connected ones (flag -> true); the blocks
-- and stories it last sent; the members it last sent them to.
local changes_due, sent_blocks, sent_stories, sent_to_members = {}, nil, nil, nil
-- How often the world's blocks are looked at for changes (the host's to send, a player's stories
-- to keep): they change a few times a minute, and reading all 18 every frame was most of the mod's
-- frame time (20 ms of every second on a test host, 2026-10-18).
local LOOK_EVERY = 0.25 -- seconds
-- The most flags a player's one change sets (the game's batch sets name a range; a far wider one
-- from another game would hold the host's frame).
local MAX_RANGE = 10000
local host_looked_at, player_looked_at = nil, nil

-- What a joined player changes in the host's world reaches the host: the game's network-connected
-- sets made on a player didn't reach the host (verified 2026-10-12). A player's are sent to the
-- host, whose game runs the same command, so the game shares them with every player as its own.
net.on("flags", function(message)
  if net.role() ~= "host" or type(message) ~= "table" then return end
  local first, last = math.tointeger(message.first), math.tointeger(message.last)
  if not first or not last or first < 0 or last < first or last - first > MAX_RANGE then return end
  local was_ok, was = pcall(flags.get, first)
  local change = (first == last and was_ok and was == (message.on == true)) and "already so here" or "a change"
  log.info("a player set flags %d..%d (%s): %s", first, last, tostring(message.on == true), change)
  if not network_set(first, last, message.on == true) then log.warn("couldn't set a player's flags %d..%d", first, last) end
end)

-- The host's world flags reach its players as they change: most of its world's changes aren't
-- network-connected sets (an enemy that stays dead, a treasure looted, a lift, a fog: its scripts'
-- plain sets; an NPC summoned at its sign: the game's own code, no event command), so a player, who
-- never joins again, fell behind for the whole session, and never saw the host's NPC summons (the
-- summon flag enables the NPC on every game, common_func 20005720). Each frame every flag the game
-- shares among the host's changes to its own set is set again with the game's network-connected
-- set at its value then: what the player's next join would have given.
-- A player's own changes to the host's world go the other way (player_frame): its lift ridden, its
-- lever pulled (its event scripts' plain sets) left the host's game as it was, the lift at the top
-- on one game and the bottom on the other. Only what its event commands set, and not the
-- flags the host's game sent it: a player's game also marks the events that end early in a world
-- not its own (an event's own flag, set as it ends), and those marks would end the host's events
-- at its next load (77 of 92 changes at a join on two games on one PC, 2026-10-19, were such). Nor a random
-- roll (2003[17]): each game rolls its own, and the host's roll is the world's (it reaches the
-- player with the host's changes); a player's could overwrite it after the host acted on its own.
-- Nor what an event the game runs with its network sync off sets: the game runs such an event for
-- each game alone, and its sets are that game's (a phantom's way through a boss's fog, common_func
-- 20005801, clears the "fog walked" flag as it restarts on the phantom's game; sent on, it cleared
-- the host's, and the Ancient Wyvern, waiting on it, never came after the party's wipe,
-- 2026-10-19). Unless this mod turned that event's sync off (events/lib.lua's made_sync_off): it
-- did so to keep a player's own doing on its game, and the world's flags the event sets still go
-- to the host, as before the edit (the chapel past Vordt's "fight entered", 13000880).
local event_edits = require("events.lib")
local player_changes_due, player_plain_sets = {}, {}
game.on("flags.plain_set", function(first, last, random, synced, event_id)
  if net.role() ~= "player" or random then return end
  if synced or event_edits.made_sync_off[event_id] then player_plain_sets[#player_plain_sets + 1] = { first, last } end
end)

-- Whether a flag is in an event command's plain set seen this frame (reported before its changes).
local function in_plain_set(flag)
  for _, range in ipairs(player_plain_sets) do
    if flag >= range[1] and flag <= range[2] then return true end
  end
  return false
end

game.on("flags.changed", function(flag, _, session, received)
  local role = net.role()
  if role == "host" and not session then
    changes_due[flag] = true
  elseif role == "player" and session and not received and shared_flag(flag) and in_plain_set(flag) then
    player_changes_due[flag] = true
  end
end)

local function host_frame()
  if next(changes_due) then
    local due_list = {}
    for flag in pairs(changes_due) do due_list[#due_list + 1] = flag end
    changes_due = {}
    table.sort(due_list)
    for _, flag in ipairs(due_list) do
      if flag > 0 and shared_flag(flag) then
        local read_ok, on = pcall(flags.get, flag)
        if read_ok and not network_set(flag, flag, on) then log.warn("the players' view of flag %d stays as it was", flag) end
      end
    end
  end
  local read_ok, set_in_use = pcall(flags.set_in_use)
  if not party.together() or not read_ok or set_in_use ~= "own" then return end
  -- A player who joined gets the blocks again.
  local members = table.concat(net.members() or {}, ",")
  if members ~= sent_to_members then sent_blocks, sent_stories, sent_to_members = nil, nil, members end
  local now = kindle.time()
  if sent_blocks and sent_stories and host_looked_at and now - host_looked_at < LOOK_EVERY then return end
  host_looked_at = now
  -- Sent as JSON objects: their keys are strings (the block's first flag).
  local blocks, changed = {}, sent_blocks == nil
  for _, thousand in ipairs(WORLD_THOUSANDS) do
    local readable, words = read_block(thousand, "own")
    if not readable or not words then return end
    blocks[tostring(thousand)] = words
    if sent_blocks and not same_words(words, sent_blocks[tostring(thousand)]) then changed = true end
  end
  if changed and pcall(net.send, "all", "world_blocks", blocks) then sent_blocks = blocks end
  local stories = {}
  changed = sent_stories == nil
  for _, story in ipairs(STORIES) do
    local first_flag = story[1]
    local readable, words = read_block(first_flag, "own")
    if not readable then return end
    local mask = STORY_MASKS[first_flag]
    local world_words = {}
    for word = 1, WORDS do world_words[word] = (words and words[word] or 0) & mask[word] end
    stories[tostring(first_flag)] = world_words
    if sent_stories and not same_words(world_words, sent_stories[tostring(first_flag)]) then changed = true end
  end
  if changed and pcall(net.send, "all", "stories", stories) then sent_stories = stories end
end

-- A player's game asks for maps' blocks: the host's, for the maps it has too.
net.on("area_blocks_wanted", function(areas, from)
  if net.role() ~= "host" or type(areas) ~= "table" then return end
  local answered = {}
  for _, area in ipairs(areas) do
    area = math.tointeger(area)
    local known = area ~= nil and not answered[area]
    if known then answered[area] = true end
    local listed = false
    for _, map_area in ipairs(MAP_AREAS) do
      if map_area == area then listed = true end
    end
    if known and listed then
      local blocks, count = {}, 0
      for _, first_flag in ipairs(area_blocks(area)) do
        local readable, words = read_block(first_flag, "own")
        if readable and words then
          blocks[tostring(first_flag)] = words
          count = count + 1
        end
      end
      if count > 0 then pcall(net.send, from, "area_blocks", { area = area, blocks = blocks }) end
    end
  end
end)

-- ── a player ────────────────────────────────────────────────────────────────────────────────

-- The host's blocks that came, to put in place (by thousand); its story blocks that came (by first
-- flag), and those as last put in place (the host's values, by first flag; `failed` once the
-- stories can't be kept apart); whether the missing digits were told this session; the set in use
-- last frame and whether the player was in the world.
local blocks_due, stories_due, host_stories = {}, {}, {}
local digits_told, set_last_frame, loaded_last_frame = false, nil, false
-- Since this game's last load began: the asks for the maps' blocks made ("loading", "loaded"); the
-- host's that came (by first flag), put in the session copy as each map's flags are there (kept
-- through the load, its own setup could write over them); the maps whose blocks are in place.
local areas_asked, area_blocks_due, areas_placed = {}, {}, {}

-- A map's flags' area (MAP_AREAS), or nil for a flag that isn't a map's own.
local function area_of(flag)
  local ten_millions_digit = (flag // 10000000) % 10
  if ten_millions_digit == 0 then return nil end
  local thousands = (flag // 1000) % 10000
  return thousands - thousands % 10
end

net.on("area_blocks", function(message, from)
  if not party.from_host(from) or type(message) ~= "table" or type(message.blocks) ~= "table" then return end
  local area = math.tointeger(message.area)
  if not area then return end
  for _, first_flag in ipairs(area_blocks(area)) do
    local words = checked_words(message.blocks[tostring(first_flag)])
    if words then area_blocks_due[first_flag] = words end
  end
end)

-- Every map's blocks asked for as the load begins and again once loaded, and a map's whose flags
-- come later (a map loaded on the way) with none of the host's in place; the host's that came: in
-- place as each map's flags are there.
local function area_blocks_frame(loaded)
  local ask = loaded and "loaded" or "loading"
  if not areas_asked[ask] and pcall(net.send, "host", "area_blocks_wanted", MAP_AREAS) then areas_asked[ask] = true end
  if areas_asked.loaded then
    local wanted = {}
    for _, area in ipairs(MAP_AREAS) do
      if not areas_placed[area] and not areas_asked[area] and read_block(area_blocks(area)[1], "session") then wanted[#wanted + 1] = area end
    end
    if #wanted > 0 and pcall(net.send, "host", "area_blocks_wanted", wanted) then
      for _, area in ipairs(wanted) do areas_asked[area] = true end
    end
  end
  local placed = 0
  for first_flag, words in pairs(area_blocks_due) do
    local readable, current = read_block(first_flag, "session")
    if readable and current then
      areas_placed[area_of(first_flag)] = true
      if not same_words(current, words) and pcall(flags.set_block, first_flag, words, "session") then placed = placed + 1 end
      if loaded then area_blocks_due[first_flag] = nil end
    end
  end
  if placed > 0 then log.info("the host's world in %d block(s) of its maps' flags%s", placed, loaded and "" or " (loading)") end
end

net.on("world_blocks", function(message, from)
  if not party.from_host(from) or type(message) ~= "table" then return end
  for _, thousand in ipairs(WORLD_THOUSANDS) do
    local words = checked_words(message[tostring(thousand)])
    if words then blocks_due[thousand] = words end
  end
end)

net.on("stories", function(message, from)
  if not party.from_host(from) or type(message) ~= "table" then return end
  for _, story in ipairs(STORIES) do
    local first_flag = story[1]
    local words = checked_words(message[tostring(first_flag)])
    if words then stories_due[first_flag] = words end
  end
end)

-- A player's game set network-connected flags: to the host.
game.on("flags.network_set", function(first, last, on)
  if net.role() == "player" then
    log.info("this player set flags %d..%d (%s); telling the host", first, last, tostring(on))
    pcall(net.send, "host", "flags", { first = first, last = last, on = on })
  end
end)

local function tell_missing_digits()
  local missing = {}
  for digit = 0, 9 do
    local first_flag = digit * 10000000
    if pcall(flags.get, first_flag, "own") and not pcall(flags.get, first_flag, "session") then missing[#missing + 1] = digit end
  end
  log.info("the session's flags have no tables for the first digits [%s] (this character's have)", table.concat(missing, ", "))
end

local function own_thousand_frame(fresh)
  local own, session = flags.block(OWN_THOUSAND, "own"), flags.block(OWN_THOUSAND, "session")
  if not own or not session or same_words(own, session) then return end
  -- A new session copy (first used, a load, or all empty while the character has some): the
  -- character's go in; else the session's are the character's.
  local session_empty = true
  for word = 1, WORDS do
    if session[word] ~= 0 then session_empty = false end
  end
  if fresh or session_empty then
    flags.set_block(OWN_THOUSAND, own, "session")
    log.info("this player's 6000s flags (the Ashen Estus Flask, gestures, souls to transpose, one-off goods) are its character's own")
  else
    flags.set_block(OWN_THOUSAND, session, "own")
  end
end

-- flags.separate_block's answers: the session set's copy of the block made now (the host's values
-- to come again), made already, or not yet.
local SEPARATE_MADE_NOW, SEPARATE_NOT_YET = 2, 0

local function stories_frame()
  for _, story in ipairs(STORIES) do
    local first_flag = story[1]
    local mask = STORY_MASKS[first_flag]
    local call_ok, separated = pcall(game.call, "flags.separate_block", first_flag)
    if not call_ok then
      if not host_stories.failed then
        log.warn("the NPCs' stories stay this player's own (%s)", separated)
        host_stories.failed = true
      end
      return
    end
    if separated == SEPARATE_MADE_NOW then host_stories[first_flag] = nil end
    if separated ~= SEPARATE_NOT_YET then
      local _, current = read_block(first_flag, "session")
      local from_host = stories_due[first_flag]
      if current and from_host then
        -- The host's world's bits in, the character's own kept.
        stories_due[first_flag] = nil
        local merged = {}
        for word = 1, WORDS do merged[word] = (current[word] & ~mask[word] & ALL_BITS) | (from_host[word] & mask[word]) end
        if not same_words(merged, current) then
          if pcall(flags.set_block, first_flag, merged, "session") then current = merged end
        end
        host_stories[first_flag] = from_host
      end
      if current then
        -- The character's flags in a block shared with the world's: kept with the character.
        local _, own = read_block(first_flag, "own")
        if own then
          local own_updated = {}
          for word = 1, WORDS do own_updated[word] = (own[word] & mask[word]) | (current[word] & ~mask[word] & ALL_BITS) end
          if not same_words(own_updated, own) then pcall(flags.set_block, first_flag, own_updated, "own") end
        end
        -- The world's flags this game changed: to the host.
        local host_words = host_stories[first_flag]
        if host_words then
          for word = 1, WORDS do
            local changed_bits = (current[word] ~ host_words[word]) & mask[word]
            if changed_bits ~= 0 then
              for bit_index = 0, 31 do
                local bit = 1 << (31 - bit_index)
                if changed_bits & bit ~= 0 then
                  local flag = first_flag + (word - 1) * 32 + bit_index
                  pcall(net.send, "host", "flags", { first = flag, last = flag, on = current[word] & bit ~= 0 })
                end
              end
              host_words[word] = (host_words[word] & ~mask[word] & ALL_BITS) | (current[word] & mask[word])
            end
          end
        end
      end
    end
  end
end

-- This player's changes to the host's world: to the host, at their value now. A map's only once
-- the host's blocks for it are in place since the load: until then its events see the copy as it
-- last was, and what they set from it isn't the host's world.
local function send_player_changes()
  if not next(player_changes_due) then return end
  local due_list = {}
  for flag in pairs(player_changes_due) do due_list[#due_list + 1] = flag end
  player_changes_due = {}
  table.sort(due_list)
  for _, flag in ipairs(due_list) do
    local area = area_of(flag)
    if area == nil or areas_placed[area] then
      local read_ok, on = pcall(flags.get, flag, "session")
      if read_ok then pcall(net.send, "host", "flags", { first = flag, last = flag, on = on }) end
    end
  end
end

local function player_frame()
  local read_ok, set_in_use = pcall(flags.set_in_use)
  local loaded = player.loaded()
  local fresh = (set_in_use ~= set_last_frame) or (loaded and not loaded_last_frame)
  if set_in_use ~= set_last_frame or (loaded_last_frame and not loaded) then
    areas_asked, area_blocks_due, areas_placed = {}, {}, {}
  end
  set_last_frame, loaded_last_frame = set_in_use, loaded
  -- (During the load too: a map's flags are there before its events start.)
  if read_ok and set_in_use == "session" then area_blocks_frame(loaded) end
  if not read_ok or set_in_use ~= "session" or not loaded then
    player_changes_due = {}
    return
  end
  if not digits_told then
    digits_told = true
    tell_missing_digits()
  end
  for _, digit in ipairs(OWN_DIGITS) do
    local call_ok, switched_now = pcall(game.call, "flags.use_own_table", digit)
    if call_ok and switched_now then log.info("this player's %ds flags are its character's own", digit) end
  end
  pcall(own_thousand_frame, fresh)
  send_player_changes()
  for thousand, words in pairs(blocks_due) do
    -- The game has the session set's 8000s be the character's own bits: the host's values went into
    -- the character's own world too. The block is made the session set's own first, and
    -- the host's values go in only once it is.
    local call_ok, separated = pcall(game.call, "flags.separate_block", thousand)
    if call_ok and separated == SEPARATE_MADE_NOW then
      log.info("the host's %ds are kept apart from this character's own", thousand)
    end
    local _, current = read_block(thousand, "session")
    if call_ok and separated ~= SEPARATE_NOT_YET and current and not same_words(current, words) then
      pcall(flags.set_block, thousand, words, "session")
    end
  end
  -- The stories: at once when the host's came or after a load, else every LOOK_EVERY.
  local now = kindle.time()
  if not host_stories.failed and (fresh or next(stories_due) or not player_looked_at or now - player_looked_at >= LOOK_EVERY) then
    player_looked_at = now
    stories_frame()
  end
end

kindle.on("frame", function()
  player_plain_sets = {}
  local role = net.role()
  if role == "host" then
    host_frame()
  elseif role == "player" then
    player_frame()
  else
    changes_due, sent_blocks, sent_stories, sent_to_members = {}, nil, nil, nil
    blocks_due, stories_due, host_stories, digits_told = {}, {}, {}, false
    areas_asked, area_blocks_due, areas_placed, player_changes_due = {}, {}, {}, {}
  end
end)
