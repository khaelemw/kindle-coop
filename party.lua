-- The party's state between the games of a session: who is out (down until the party rests) and
-- who is downed (a teammate can revive them). A player tells the host its own as it changes
-- ("state"); the host keeps everyone's and sends the lists ("outs", "downs") as they change.
local net = kindle.net

local party = {
  -- This player: out, downed since (kindle.time()), revived by a teammate (to take on the next
  -- frame), back from being out at the party's rest (due), its death counting (dying), wiped (the
  -- party died: back with the host after its world reloads).
  out = false,
  downed_since = nil,
  revived = false,
  -- The teammate reviving this player now (member id; revive.lua, from its "reviving").
  reviver = nil,
  revive_due = false,
  dying = false,
  wiped = false,
  -- Revives since the party last rested.
  revives_used = 0,
  -- Everyone's (member ids as net.members gives them, as sets: id -> true): the host's lists, on
  -- every game.
  outs = {},
  downs = {},
  -- Other players' characters this game hides (handle -> true), and when it last got back from
  -- being out (kindle.time()).
  hidden = {},
  back_up_at = nil,
  -- Back from being out at the party's rest, this player sitting down beside the others
  -- (death.lua): that sit is part of the rest just made (rest.lua). The bonfire of the last rest.
  sitting_back = false,
  last_rest_bonfire = nil,
}

-- A downed player's pose: a gesture held on the ground (animation 80700, its start then its loop).
-- It was the bonfire sit (W_BonfireStart), and a bonfire animation brings the game's bonfire
-- behaviour with it: invulnerable (the TAE's jump table 54, in every bonfire animation and no
-- gesture), and near a bonfire the sit can raise the game's own rest, which refills the Estus
-- (a revived player with full Estus in the Dancer's arena, where the boss's bonfire is).
-- A downed player is kept from harm by Kindle's own switches instead (death.lua).
party.DOWN_POSE = "W_Event80700"

-- Whether a message came from the host, to this game as a player: what the host alone decides
-- (the world's flags, the party's lists, a rest, a travel) is taken from it only, not from another
-- player (a player's messages to "all" go through the host, which names their sender).
function party.from_host(from)
  return net.role() == "player" and from ~= nil and from == net.host()
end

-- Whether an animation (world.animation's name) is the downed pose.
function party.in_down_pose(animation)
  return animation ~= nil and animation:find("^Event8070[01]$") ~= nil
end

-- The host: each player's {out, down}, by member id.
local states_by_member = {}
-- A player: what it last told the host.
local last_sent_state

function party.together()
  local members = net.members()
  return members ~= nil and #members > 1
end

-- The party rested at a bonfire (rest.lua): its revives are back, and this player, if out, comes back.
function party.party_rested()
  party.revives_used = 0
  if party.out then party.revive_due = true end
end

-- A list of member ids from another game, as a set (id -> true); anything else in it ignored.
local function set_of_ids(list)
  local set = {}
  if type(list) == "table" then
    for _, id in ipairs(list) do
      if type(id) == "string" then set[id] = true end
    end
  end
  return set
end

-- A set's keys as a sorted list.
local function sorted_keys(set)
  local list = {}
  for key in pairs(set) do list[#list + 1] = key end
  table.sort(list)
  return list
end

local function same_set(set_a, set_b)
  return table.concat(sorted_keys(set_a), ",") == table.concat(sorted_keys(set_b), ",")
end

net.on("state", function(state, from)
  if net.role() == "host" and type(state) == "table" then
    states_by_member[from] = { out = state.out == true, down = state.down == true }
  end
end)
net.on("outs", function(list, from) if party.from_host(from) then party.outs = set_of_ids(list) end end)
net.on("downs", function(list, from) if party.from_host(from) then party.downs = set_of_ids(list) end end)

-- Each frame (death.lua calls it after its own): the state between the games.
function party.frame()
  if not party.together() then
    states_by_member, last_sent_state, party.outs, party.downs = {}, nil, {}, {}
  else
    local my_id, downed = net.me(), party.downed_since ~= nil
    if net.role() == "player" then
      local state_now = (party.out and "o" or "-") .. (downed and "d" or "-")
      if last_sent_state ~= state_now and pcall(net.send, "host", "state", { out = party.out, down = downed }) then
        last_sent_state = state_now
      end
    elseif net.role() == "host" then
      local members, outs, downs = {}, {}, {}
      for _, id in ipairs(net.members() or {}) do members[id] = true end
      for id, state in pairs(states_by_member) do
        if not members[id] then
          states_by_member[id] = nil
        else
          if state.out then outs[id] = true end
          if state.down then downs[id] = true end
        end
      end
      if party.out then outs[my_id] = true end
      if downed then downs[my_id] = true end
      if not same_set(outs, party.outs) then
        party.outs = outs
        pcall(net.send, "all", "outs", sorted_keys(outs))
      end
      if not same_set(downs, party.downs) then
        party.downs = downs
        pcall(net.send, "all", "downs", sorted_keys(downs))
      end
    end
  end
end

return party
