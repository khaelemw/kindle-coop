-- Resting together. Sitting at a bonfire rests at once in the game (the world brings its enemies
-- back, HP, FP and Estus refill). In a session with others a player who sits waits for the
-- others instead (bonfire.rest_requested held): once every player who isn't out sits at the same
-- bonfire, the host says so ("rest") and every game rests there, so the enemies come back on every
-- game at once. Players who are out come back then, next to the others at the bonfire, and sit
-- down with them as part of that rest (one rest, 2026-10-18: before, their sit made the
-- party rest a second time). Only the host travels, and only from there (the party's decision:
-- host-only travel).
local party = require("party")
local catalogue = require("catalogue")
local net, game, ui, log = kindle.net, kindle.game, kindle.ui, kindle.log

local WAIT_NOTICE_EVERY = 5 -- seconds between the "waiting" notices
local NOT_SITTING = -1 -- a bonfire id meaning "not sitting at one"

-- The bonfire this player sits at (since its rest was held back, until it stands up), and whether
-- that sitting's rest is done.
local sitting_at, rested = nil, false
-- The party's rest came while this player's bonfire menu was up: the bonfire, rested once the menu
-- closes. The game always rests before that menu opens (the sitting raises the rest, then the
-- menu comes up); the party's rest made under the open menu left the host sitting with no menu,
-- unable to stand up or open Esc (2026-10-15: it sat first, its menu came 1.3 s later,
-- the joined player sat 2.7 s after that).
local rest_after_menu
-- A player: the host's "rest" (the bonfire); what it last told the host of its sitting.
local rest_due, last_sent_sitting
-- The host: where each player sits, by member id: {bonfire (NOT_SITTING none), rested (that
-- sitting's rest is done)}; whether "rest" went out for the party sitting now.
local sitting_by_member, rest_sent = {}, false
local wait_notice_at

local together = party.together

-- The host: the bonfire every player who isn't out sits at, if they all sit at the same one, and
-- whether any of them hasn't rested there yet (only then does the party rest).
local function party_bonfire()
  local my_id, members = net.me(), net.members()
  if not members then return nil end
  local first_bonfire, someone_unrested = nil, false
  for _, id in ipairs(members) do
    if not party.outs[id] then
      local bonfire, member_rested
      if id == my_id then
        bonfire, member_rested = sitting_at or NOT_SITTING, rested
      else
        local sitting = sitting_by_member[id] or {}
        bonfire, member_rested = sitting.bonfire or NOT_SITTING, sitting.rested == true
      end
      if first_bonfire == nil then
        first_bonfire = bonfire
      elseif bonfire ~= first_bonfire then
        return nil
      end
      if not member_rested then someone_unrested = true end
    end
  end
  if first_bonfire == nil or first_bonfire == NOT_SITTING then return nil end
  return first_bonfire, someone_unrested
end

local function rest_at(bonfire)
  local ok, err = pcall(game.call, "bonfire.rest", bonfire)
  if ok then
    log.info("rested at bonfire %d with the party", bonfire)
    ui.toast("Rested with the party")
  else
    log.warn("couldn't rest at bonfire %d with the party: %s", bonfire, err)
  end
end

local function rest_now(bonfire)
  party.party_rested()
  party.last_rest_bonfire = bonfire
  if sitting_at then
    if rested then return end
    rested = true
    if catalogue.field("ui.menu_open") then
      rest_after_menu = sitting_at
      return
    end
  end
  rest_at(sitting_at or bonfire)
end

-- A sitting player's rest waits for the others; any other rest is the game's.
game.on_decide("bonfire.rest_requested", function(bonfire, sits_there)
  -- (A rest while down shouldn't come since the downed pose is a gesture; said if it does.)
  if party.downed_since then log.warn("the game rests this player while it is down (bonfire %s, sitting %s)", tostring(bonfire), tostring(sits_there)) end
  if sits_there ~= 1 or not together() then return nil end
  local sitting_back = party.sitting_back
  party.sitting_back = false
  if sitting_back and bonfire == party.last_rest_bonfire then
    -- Back from being out, sitting down beside the others: this game rested with the party
    -- already (rest_now, as the rest came); no rest of its own, and none for the party.
    sitting_at, rested = bonfire, true
    log.info("sitting at bonfire %d with the party, which rested as this player came back", bonfire)
    return "hold"
  end
  sitting_at, rested = bonfire, false
  log.info("sitting at bonfire %d; the rest waits for the other players", bonfire)
  return "hold"
end)

game.on_decide("bonfire.travel_requested", function()
  if not together() then return nil end
  local refused_because
  if net.role() ~= "host" then
    refused_because = "Only the host can travel in co-op"
  elseif not party_bonfire() then
    refused_because = "Everyone has to be resting at this bonfire to travel"
  else
    return nil
  end
  ui.toast(refused_because)
  return "refuse"
end)

-- The host: where a player sits.
net.on("sitting", function(sitting, from)
  if net.role() == "host" and type(sitting) == "table" and math.type(sitting.bonfire) == "integer" then
    sitting_by_member[from] = { bonfire = sitting.bonfire, rested = sitting.rested == true }
  end
end)

-- A player: the party rests now.
net.on("rest", function(bonfire, from)
  if party.from_host(from) and math.type(bonfire) == "integer" then rest_due = bonfire end
end)

kindle.on("frame", function()
  if rest_after_menu and (not together() or not catalogue.field("ui.menu_open")) then
    local bonfire = rest_after_menu
    rest_after_menu = nil
    rest_at(bonfire)
  end
  -- (Not readable during a load: not sitting.)
  if sitting_at and not catalogue.field("bonfire.sitting") then sitting_at, rested = nil, false end
  if not together() then
    sitting_at, rest_due, last_sent_sitting, sitting_by_member, rest_sent = nil, nil, nil, {}, false
    return
  end
  local role, now = net.role(), kindle.time()
  if role == "player" then
    local sitting = { bonfire = sitting_at or NOT_SITTING, rested = sitting_at ~= nil and rested }
    local told = sitting.bonfire .. (sitting.rested and " rested" or "")
    if last_sent_sitting ~= told and pcall(net.send, "host", "sitting", sitting) then last_sent_sitting = told end
  end
  if sitting_at and not rested and (not wait_notice_at or now - wait_notice_at >= WAIT_NOTICE_EVERY) then
    ui.toast("Waiting for the other players to rest at the bonfire")
    wait_notice_at = now
  end
  if role == "host" then
    local members = {}
    for _, id in ipairs(net.members() or {}) do members[id] = true end
    for id in pairs(sitting_by_member) do
      if not members[id] then sitting_by_member[id] = nil end
    end
    local bonfire, someone_unrested = party_bonfire()
    if bonfire and someone_unrested and not rest_sent then
      rest_sent = true
      log.info("everyone is resting at bonfire %d", bonfire)
      pcall(net.send, "all", "rest", bonfire)
      rest_now(bonfire)
    elseif not bonfire then
      rest_sent = false
    end
  end
  if rest_due then
    local bonfire = rest_due
    rest_due = nil
    rest_now(bonfire)
  end
end)
