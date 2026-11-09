-- The joined player as the host. A co-op player is a white phantom to the game (type 1, in a world
-- not its own): the session counts and registers it as one, and the world stays the host's
-- (bosses, NPCs' stories, the world's flags). Everywhere else the game treats a summoned player
-- differently, this mod makes it play as the host does, except what is each player's own (its
-- souls, items, shops, levels, Estus, ember). Here: the per-type table, the event scripts' type
-- test, the NPCs it sees, its cutscene skip, its Estus and flask level, talking, loot, and what it
-- may use. Elsewhere: flags (flags.lua), the ember and key items (keep.lua), deaths (death.lua),
-- the game's own event scripts (events/).
local catalogue = require("catalogue")
local net, game, params, log = kindle.net, kindle.game, kindle.params, kindle.log
local decide = catalogue.decide

-- The per-type table: a co-op player's row (type 1) takes the host's (type 0) in these columns
-- (read 2026-10-14 from each column's readers): 0 a ghost's form, 2 takes loot, 3 sounds as a
-- phantom, 4 (unused), 5 its animations act on the world, 6 the death replay, 8 a rated message's
-- reward. Column 1 (a hostile phantom) is the host's already; 7, the world's owner (the session's
-- join and leave, the host's event manager, enemy detection), stays a phantom's.
local NATIVE_COLUMNS = { 0, 2, 3, 4, 5, 6, 8 }
local HOST, WHITE_PHANTOM, DARK_PHANTOM = 0, 1, 2
local TAKES_LOOT = 2

local function type_table()
  for _, column in ipairs(NATIVE_COLUMNS) do
    game.call("chr_type.set", WHITE_PHANTOM, column, game.call("chr_type.get", HOST, column))
  end
  game.call("chr_type.set", DARK_PHANTOM, TAKES_LOOT, true)
  log.info("players are treated as the host by the type table (%d columns)", #NATIVE_COLUMNS)
end

-- What a joined player may use, as at home. A goods row (EquipParamGoods) says whether a character
-- of its kind may use it: enable_live (at home, embered), enable_gray (at home, unembered),
-- enable_white (a white phantom, which a joined player is to the game) and enable_multi (anyone, in
-- a session). Two rows a character at home may use embered or not, in a session too, were closed to
-- a white phantom: Seed of a Giant Tree (440) and Dried Finger (385). Every such row is opened to it:
-- a joined player uses what its own character could in a session. Rows a session closes (the
-- Purging Stone, the Homeward Bone, the Darksign: enable_multi 0, for the host too) stay closed;
-- the Ember, usable only unembered, is keep.lua's.
local function open_goods()
  local opened = 0
  for _, id in ipairs(params.rows("EquipParamGoods")) do
    local goods = params.get("EquipParamGoods", id)
    if goods and goods.enable_multi == 1 and goods.enable_live == 1 and goods.enable_gray == 1 and goods.enable_white ~= 1 then
      if pcall(function() goods.enable_white = 1 end) then opened = opened + 1 end
    end
  end
  log.info("players use what their own characters could in a session (%d item(s) opened to them)", opened)
end

local type_table_done, goods_done = false, false

kindle.on("frame", function()
  if not type_table_done then
    type_table_done = true
    local ok, err = pcall(type_table)
    if not ok then log.warn("players aren't treated as the host by the type table (%s)", err) end
  end
  if not goods_done then
    local ember = params.get("EquipParamGoods", 500)
    if ember and ember.enable_live ~= nil then
      goods_done = true
      open_goods()
    end
  end
  local role, state = net.role(), net.state()
  local is_player = role == "player"
  -- In a host's world (or on the way there): the events built as its world loads, the NPCs made.
  local in_host_world = is_player and (state == "joining" or state == "joined")
  -- A player's event tests of "the host" test its own type, so the host's events run for it too.
  decide("events.chr_type_test", in_host_world and "as_phantom" or "game")
  -- It sees the host's NPCs as the host does, not as wandering ghosts (the Fire Keeper).
  decide("npc.guest_look", in_host_world and "as_host" or "game")
  -- Its skip ends a cutscene on every game, as the host's does.
  decide("cutscene.skip_owner", in_host_world and "owner" or "game")
  -- Its Estus is a full member's (a guest is always a co-op player: Kindle keeps the game offline),
  -- and its flask level its own.
  decide("load.estus_allotment", "as_host")
  decide("bonfire.level_copy", "own")
  -- Its bonfires stay lit over its loads (following the host's travel): sitting rests, as the host's.
  decide("bonfire.session_list", "keep")
  -- Bonfires and NPCs open to everyone (resting together: rest.lua), as with Seamless Co-op.
  decide("talk.in_session", role ~= nil and "no" or "game")
  decide("talk.player_check", is_player and "as_host" or "game")
  -- A player's talks don't wait for an NPC's ready effect, which only the host's game gives.
  decide("talk.npc_ready", is_player and "always" or "game")
  -- Loot is every player's own, as with Seamless Co-op: a player's game rolls its own drops and
  -- loads its own treasure (by its own pickup flags: what it picks up is its own, each player takes
  -- each item once), numbers them in a range of their own (the host's message taking an item off
  -- names only the host's), sets its treasure's pickup flags, keeps them when the host says to
  -- clear them, and gets event awards; an enemy already dead in the host's world before the
  -- player's game had it dies without paying souls.
  decide("loot.guest_loot", "own")
  decide("loot.guest_awards", "allow")
  decide("enemy.host_hp_death", "silent")
  decide("loot.guest_item_ids", is_player and "own" or "game")
  decide("loot.treasure_flag", is_player and "set" or "game")
  decide("loot.item_messages", is_player and "keep_own" or "game")
end)
