-- What one game starts, every game sees at once (lib.restart): the event's main wait also ends when
-- its flag comes on (another game did it first), and the event restarts, taking its own "already
-- done" branch, as on a reload. Each wait is reached only while the flag is off:
-- - a ladder kicked down and an object broken (common_func 20005640, 20005650: the event's
--   argument at byte 0);
-- - m30 13005830 (13000838).
--
-- Rows: map, event, wait = which of the event's main waits (from 0), flag = the flag (a number,
-- or {arg = byte}: the event's argument there).
return {
  {"common_func", 20005640, wait = 0, flag = {arg = 0}},
  {"common_func", 20005650, wait = 0, flag = {arg = 0}},
  {"m30_00_00_00", 13005830, wait = 0, flag = 13000838},
}
