-- Kept so a theme that names the inherited "governor" subtype keeps loading. A heli theme's
-- governor tile showed the governor state in flight; Gripora has no governor, so the tile shows
-- the car's drive aids and driving mode instead (objects/text/driveaids.lua).
return assert(loadfile("widgets/dashboard/objects/text/driveaids.lua"))()
