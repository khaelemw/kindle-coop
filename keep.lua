-- What a player keeps as its own in the host's world, as at home: its ember and its key items.
--
-- Embered, as in single player (2026-10-11: "the game should play as if it was exactly
-- the same as single player just with your friend there"). The game's ember state is a byte of the
-- player data (kindle.player.embered): the Ember's effect (SpEffect 3290) sets it, a death clears
-- it, and while it's set the game gives the character the embered SpEffect 490 (+30% max HP, its
-- glow). A joined player is a white phantom to the game, which keeps the byte (and an Ember's
-- effect still sets it) but never gives a phantom 490, and offers no Ember to use (a phantom counts
-- as embered). So for a joined player: embered, it gets 490 as the game does at home; unembered,
-- it can use an Ember (EquipParamGoods 500: enable_white and enable_multi, and while it's
-- unembered enable_ActiveEmber), whose own effect sets the byte, then 490 follows (enable_multi is
-- set for everyone: a host can use one with players there, as alone); out (down until the party
-- rests), it's unembered, as a death makes it. Its game keeps the byte, so it goes home with it.
--
-- Its look: an embered character gets the ember's look (the cracks, SpEffect 9139, and the HUD's
-- fiery hexagon) only if its type is the world's owner's, so an embered joined player had neither,
-- on its own game or the host's (chr.ember_look). Every embered player's character gets it, as the
-- host does. The ember's effects (490, and the look's 9139) don't target a white phantom, which a
-- joined player is to the game (only its own game, where it's "self", gave them to it): they do.
--
-- Key items: a load into someone else's world gives the game's phantom an empty list of key items
-- (its Small Doll gone at Irithyll's barrier, those picked up there lost at its next load); a
-- player's own are put back in use as soon as its game is in the host's world.
--
-- Going home: back home a player keeps what it had in the host's world, as a character keeps what
-- it has anywhere. The game's way for a phantom is the other: as it leaves for another world the
-- game keeps a copy of its HP, FP, Estus and goods, and its load home puts the copy back
-- (load.phantom_copy), so a player's HP, FP and Estus at home were those it joined with, and goods
-- it used in the host's world came back to it. Alive, it keeps what it has; dead (the party
-- wiped), it's back as a death leaves a character in single player: full HP, FP and Estus.
--
-- Its own type: the game keeps a player's type as it joins, to give it back at home, and a player
-- following the host joins again without going home, still a phantom: it went home a white
-- phantom, and was saved as one (verified 2026-10-08). The kept type stays a home one
-- (chr_type.keep_home_type), and a character saved as a phantom loads at home as itself
-- (load.player_type).
local party = require("party")
local catalogue = require("catalogue")
local follow = require("follow")
local net, game, player, params, log = kindle.net, kindle.game, kindle.player, kindle.params, kindle.log

local EMBER_ROW, EMBERED_EFFECT, EMBER_LOOK_EFFECT = 500, 490, 9139
-- The Ember's embering effect (state 0x115: the game's player update embers the character that
-- has it and shows "EMBER RESTORED", banner 17).
local EMBERING_EFFECT, EMBER_RESTORED_BANNER = 3296, 17

-- The Ember's row: whether a phantom may use it (set once), enable_ActiveEmber as last written
-- (nil: the game's own); whether this player was out last frame.
local ember_opened_to_phantoms, active_ember_written, was_out = false, nil, false

local function ember_frame(joined)
  local ember = params.get("EquipParamGoods", EMBER_ROW)
  if not ember then return end
  if not ember_opened_to_phantoms and pcall(function() ember.enable_white = 1 ember.enable_multi = 1 end) then
    ember_opened_to_phantoms = true
  end
  local read_ok, embered = false, nil
  if player.loaded() then read_ok, embered = pcall(player.embered) end
  if not read_ok then embered = nil end
  local unembered = joined and embered == false
  if active_ember_written ~= unembered and pcall(function() ember.enable_ActiveEmber = unembered and 1 or 0 end) then
    active_ember_written = unembered
  end
  if not joined then
    was_out = false
    return
  end
  if party.out and not was_out and embered then
    pcall(player.set_embered, false)
    pcall(player.remove_effect, EMBERED_EFFECT)
    log.info("down: no longer embered")
  end
  was_out = party.out
  if party.out or embered ~= true then return end
  if not player.has_effect(EMBERED_EFFECT) then pcall(player.apply_effect, EMBERED_EFFECT) end
end

local function key_items_frame()
  local read_ok, own_in_use = pcall(game.get, "inventory.own_key_items")
  if read_ok and own_in_use == false then
    local call_ok, switched = pcall(game.call, "inventory.use_own_key_items")
    if call_ok and switched then log.info("this player's key items are its own again (the game's load gave it a phantom's)") end
  end
end

-- A boss's defeat embers the host, and a phantom who helped is home embered (the game's revive as
-- it loads home); a player who stays (flow.lua) went on unembered (a joined player after Iudex
-- Gundyr, 2026-10-14). It gets the Ember's own effect; not one who is out.
game.on("flow.boss_clear_stayed", function()
  if party.out or not player.loaded() then return end
  local read_ok, embered = pcall(player.embered)
  if read_ok and embered == false then
    local ok, err = pcall(player.set_embered, true)
    if ok then
      log.info("embered by the boss's defeat")
    else
      log.warn("couldn't ember this player after the boss (%s)", err)
    end
  end
end)

-- This player was last in a host's world: {alive = whether it was standing there} (set each frame
-- while it's there), taken by its next load home.
local from_host_world

local function in_host_world()
  local state = net.state()
  return state == "joining" or state == "joined"
end

game.on_decide("load.phantom_copy", function()
  -- A load into a host's world (a join, a follow) isn't one home.
  if in_host_world() or not from_host_world then return nil end
  local alive = from_host_world.alive
  from_host_world = nil
  if alive then
    log.info("home with what it had in the host's world")
    return "keep_current"
  end
  log.info("home after a death: back with full HP, FP and Estus")
  return "full"
end)

game.on_decide("load.player_type", function()
  if in_host_world() or follow.following() then return nil end
  return "home"
end)
-- "EMBER RESTORED" is the embering player's own: the game shows it for any player's character that
-- embers, and another player's Ember reaches this game with its character (its effect is synced, so
-- that player's ember look shows here), so both screens showed it (2026-10-19). Shown
-- only while this game's player has the embering effect, as the one embering does.
game.on_decide("ui.banner", function(kind)
  if kind ~= EMBER_RESTORED_BANNER or not party.together() then return nil end
  if player.loaded() and player.has_effect(EMBERING_EFFECT) then return nil end
  log.info("another player embered: its \"EMBER RESTORED\" isn't this player's")
  return "hide"
end)

catalogue.decide("chr_type.keep_home_type", "own")
catalogue.decide("chr.ember_look", "any")

-- The ember's effects for a white phantom too, once the params are there (before anyone joins).
local ember_effects_opened = false
kindle.on("frame", function()
  if ember_effects_opened then return end
  local rows = {}
  for _, id in ipairs({ EMBERED_EFFECT, EMBER_LOOK_EFFECT }) do
    local row = params.get("SpEffectParam", id)
    if not row or row.effectTargetWhiteGhost == nil then return end
    rows[#rows + 1] = row
  end
  for _, row in ipairs(rows) do row.effectTargetWhiteGhost = 1 end
  ember_effects_opened = true
  log.info("the ember's effects (%d, %d) are a white phantom's too", EMBERED_EFFECT, EMBER_LOOK_EFFECT)
end)

kindle.on("frame", function()
  local joined = net.role() == "player" and net.state() == "joined" and player.loaded()
  ember_frame(joined)
  if net.role() == "player" and player.loaded() then key_items_frame() end
  if joined then from_host_world = { alive = not party.out and player.hp() > 1 } end
end)
