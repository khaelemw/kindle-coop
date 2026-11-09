-- How the other players are shown: as themselves, as with Seamless Co-op.
--
-- Their look: a summoned player's comes from its role (RoleParam: the white phantom's row 1, a
-- covenant's for its members, TeamType 2 for all of them): PhantomParamId0..3, the PhantomParam row
-- drawn over the character (80, the white phantom's glow and see-through edges; the Warriors of
-- Sunlight 85, gold). Cleared (-1, no phantom look) once the game's params are loaded, on every
-- game; the game reads them as it draws, so it takes at once (verified 2026-10-09 with two games on
-- one PC: a player drawn as a white phantom on the host's screen was drawn as itself). A dark
-- spirit's roles (TeamType 16, the game's red phantoms and NPC invaders') and NPC summons
-- (NpcParam's PhantomParamId) keep theirs.
--
-- Their name tags show only their names: the role line above (menu text, FMG 200: 331100 "Host of
-- Embers", 331101 "Phantom", 331147 "Summoner", the host's after it has died) said a player was a
-- phantom, and the host "Summoner" (verified 2026-10-11 with two games on one PC: with those three
-- empty both tags read just the name and the HP bar). Dark spirits' and covenants' labels stay. The
-- join's announcements likewise (event text, FMG 30; the white sign summons' 0, 1 and 3:
-- 2600000.. "Phantom <name> summoned" on the host, 2601000.. "Summoned to the world of Host of
-- Embers <name>" and 2311000.. "Being summoned to another world as phantom..." on the player) say
-- a player joined; the game fills in the <?...?> names as it shows them. A player who is out is
-- hidden (death.lua), and its tag with it (ui.hidden_name_tags).
local catalogue = require("catalogue")
local params, text, log = kindle.params, kindle.text, kindle.log

local SUMMONED_TEAM = 2 -- RoleParam's TeamType of the white phantoms and covenant summons
local PHANTOM_FIELDS = { "PhantomParamId0", "PhantomParamId1", "PhantomParamId2", "PhantomParamId3" }
local NO_PHANTOM_LOOK = -1
local MENU_TEXT, EVENT_TEXT = 200, 30
local ROLE_TAGS = { 331100, 331101, 331147 }
local JOIN_TEXTS = {
  { 2600000, "<?joinName?> joined" }, { 2600001, "<?joinName?> joined" }, { 2600003, "<?joinName?> joined" },
  { 2601000, "Joined <?hostName?>'s world" }, { 2601001, "Joined <?hostName?>'s world" }, { 2601003, "Joined <?hostName?>'s world" },
  { 2311000, "Joining another world..." }, { 2311001, "Joining another world..." }, { 2311003, "Joining another world..." },
}
local RETRY_EVERY = 1 -- seconds, until the params and texts are loaded

local look_done, texts_done = false, false
local look_tried_at, texts_tried_at

local function clear_phantom_look()
  local cleared_roles = 0
  for _, row_id in ipairs(params.rows("RoleParam")) do
    local role = params.get("RoleParam", row_id)
    if role and role.TeamType == SUMMONED_TEAM then
      for _, field in ipairs(PHANTOM_FIELDS) do
        pcall(function() role[field] = NO_PHANTOM_LOOK end)
      end
      cleared_roles = cleared_roles + 1
    end
  end
  if cleared_roles > 0 then
    log.info("players are drawn as themselves, not as phantoms (%d roles)", cleared_roles)
    return true
  end
  return false
end

-- Each text set; true once every one took (the game's text tables are loaded).
local function set_texts()
  local all_set = true
  for _, id in ipairs(ROLE_TAGS) do
    local ok, changed = pcall(text.set, MENU_TEXT, id, "")
    all_set = all_set and ok and changed > 0
  end
  for _, join in ipairs(JOIN_TEXTS) do
    local ok, changed = pcall(text.set, EVENT_TEXT, join[1], join[2])
    all_set = all_set and ok and changed > 0
  end
  if all_set then log.info("name tags show players' names only; joins say so") end
  return all_set
end

catalogue.decide("ui.hidden_name_tags", "hide")

kindle.on("frame", function()
  local now = kindle.time()
  if not look_done and (not look_tried_at or now - look_tried_at >= RETRY_EVERY) then
    look_tried_at = now
    local ok, done = pcall(clear_phantom_look)
    look_done = ok and done
  end
  if not texts_done and (not texts_tried_at or now - texts_tried_at >= RETRY_EVERY) then
    texts_tried_at = now
    texts_done = set_texts()
  end
end)
