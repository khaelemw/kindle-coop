-- The co-op mod's use of the catalogue (kindle.game): its answers to hook points, given each frame
-- from the game's state (game.decide is called only when an answer changes), and fields read
-- where the game may not have them (during a load the game has no talk manager, no menus...).
-- A Lua error in a frame handler stops the whole mod (Kindle unloads it), so a read that can
-- fail while the game loads goes through catalogue.field.
local game, log = kindle.game, kindle.log

local catalogue = {}

-- Each hook point's answer as last given, by name.
local last_answers = {}

function catalogue.decide(name, answer)
  if last_answers[name] ~= answer then
    local ok, err = pcall(game.decide, name, answer)
    if not ok then log.warn("%s: %s", name, err) end
    last_answers[name] = answer
  end
end

-- A field's value, or nil when the game doesn't have it now.
function catalogue.field(name)
  local ok, value = pcall(game.get, name)
  if ok then return value end
  return nil
end

return catalogue
