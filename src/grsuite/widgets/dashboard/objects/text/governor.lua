-- Kept only so a user theme that still names the inherited "governor" subtype
-- keeps loading: Gripora has no governor, so it draws the arming state
-- (objects/text/armflags.lua) instead. The built-in themes use "armflags".
return assert(loadfile("widgets/dashboard/objects/text/armflags.lua"))()
