-- A player stays with the party. The game's multiplayer flow ends a phantom's visit in several
-- ways, each sending it home (to be joined again by Kindle's rejoin, a load of its own world and
-- then another of the host's) or a host to the title screen: a boss's death (every game fades the
-- summoned players out, then sends them home and out of the session), a fall out of the world, a
-- host gone, a host's last guest gone. In a co-op session the party stays together: nobody fades
-- out after a boss and a player stays in the host's world (with its action buttons, its item
-- popups' OK at once), the host stays in its world when its players leave, and a player goes
-- where the host goes, following it (follow.lua: its game's own send-home after the leave is
-- refused, and the notices of it hidden). Seamless Co-op plays the same way.
local party = require("party")
local catalogue = require("catalogue")
local follow = require("follow")
local net, game, log = kindle.net, kindle.game, kindle.log

-- A fall out of the world (a kill plane) runs the game's death of a phantom even with the
-- no-death flag (its flow, then the world reload 5 s later): a player who is out, or was back
-- from being out less than this long ago, isn't sent home by it.
local KEEP_AFTER_UP = 15 -- seconds
-- NetworkMsgParam rows: a phantom's boss fight over ("Critical battle over. Returning to your
-- world."), a phantom's notice that the boss can be fought, and the connection error that sends
-- a player home.
local NOTICE_BOSS_OVER, NOTICE_BOSS_OPEN, NOTICE_CONNECTION_ERROR = 211, 261, 271

-- The game asks for a world reload to send this player home.
game.on_decide("world.reload_requested", function()
  -- Following the host: its game would send it home after its leave (a load of its own world,
  -- then another to join again); it joins the host in its new world instead, one load.
  if follow.following() then
    log.info("the game would send this player home; it follows the host instead")
    follow.reload_refused = true
    return "refuse"
  end
  if net.role() ~= "player" then return nil end
  local just_back_up = party.back_up_at ~= nil and kindle.time() - party.back_up_at < KEEP_AFTER_UP
  if party.out or just_back_up then
    log.info("the game would send this player home after its fall; it stays with the party")
    return "refuse"
  end
  return nil
end)

-- The game's notices of a phantom's visit ending, which aren't so for a player who stays: while
-- following the host ("A connection error occurred. Returning to your world." as it leaves,
-- "Being summoned to another world as phantom..." as it joins again), a boss fight's end for a
-- player who stays after it, and the connection error of a player who left co-op itself.
game.on_decide("ui.network_notice", function(row)
  if follow.following() then return "hide" end
  if net.role() == "player" and (row == NOTICE_BOSS_OVER or row == NOTICE_BOSS_OPEN) then return "hide" end
  if row == NOTICE_CONNECTION_ERROR and follow.left_by_choice then
    follow.left_by_choice = false
    return "hide"
  end
  return nil
end)

-- A host's session stays open as Seamless Co-op's does: the game ends it with its last guest gone
-- (the host to the title screen 5 s later) and closes it to new players when a boss dies; players
-- join again instead (only a host's session is kept).
catalogue.decide("session.leave_requested", "keep")
catalogue.decide("session.close_requested", "keep")

-- A boss's death on a phantom's game turns its action buttons off for its way home: a player
-- stays (only a phantom's game takes that branch).
catalogue.decide("flow.boss_death_leaving", "stay")

kindle.on("frame", function()
  local role = net.role()
  -- A boss died: nobody fades out, and a player isn't sent home or out of the session.
  catalogue.decide("flow.boss_clear_fade", role ~= nil and "skip" or "game")
  catalogue.decide("flow.boss_clear_home", role == "player" and "stay" or "game")
  catalogue.decide("flow.boss_leave_session", role == "player" and "stay" or "game")
  -- A host whose last player left stays in its world.
  catalogue.decide("flow.leave_limit", role == "host" and "skip" or "game")
end)
