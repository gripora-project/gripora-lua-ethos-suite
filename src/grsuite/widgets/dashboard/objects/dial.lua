--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local grsuite = requireModule("widgets/dashboard/context.lua")

local wrapperFactory = requireModule("widgets/dashboard/lib/wrapper_factory.lua")

return wrapperFactory.createObjectWrapper("dial", "image")
