--[[
    Car tilt view (type "navigation", subtype "ah"). The subtype keeps the name of the inherited
    artificial horizon, so a theme that placed one still loads; for a car it shows how far the
    body leans, from the attitude telemetry sensors:

      - left: the car seen from behind, tipping by the roll angle over the edge of its lower
        tyre, on a level ground line;
      - right: the car seen from the side (nose to the right), tipping by the pitch angle;
      - under each, the angle in degrees.

    The car turns warncolor from warnangle and critcolor from critangle, either axis. Pitch is
    gripora-firmware's attitude convention, positive nose down (set invertpitch if the nose goes
    the wrong way). The heli/plane horizon's parameters (pixelsperdeg, showcompass, showaltitude,
    ...) are ignored.

    wakeupinterval      : number   -- Optional wakeup interval in seconds
    bgcolor             : color    -- Box background (theme fallback if nil)
    bodycolor           : color    -- Car body (default: theme fillcolor)
    windowcolor         : color    -- Windows (default: theme bgcolor)
    wheelcolor          : color    -- Tyres (default: dark grey)
    lightcolor          : color    -- Tail lights (default: red)
    groundcolor         : color    -- Ground line (default: theme textcolor)
    textcolor           : color    -- Angle text (default: theme textcolor)
    warnangle           : number   -- Degrees from which the car is drawn in warncolor (default: 20)
    critangle           : number   -- Degrees from which the car is drawn in critcolor (default: 35)
    warncolor           : color    -- (default: theme fillwarncolor)
    critcolor           : color    -- (default: theme fillcritcolor)
    invertpitch         : bool     -- Tip the side view the other way (default: false)
    showpitch           : bool     -- Show the side view (default: true); false gives the whole box to the rear view
    showvalues          : bool     -- Show the angles (default: true)
    font                : font     -- Angle text font (default: FONT_XS)
]]

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local grsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd

local floor = math.floor
local abs = math.abs
local min = math.min
local sin = math.sin
local cos = math.cos
local rad = math.rad
local format = string.format

local render = {}
local utils = grsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

-- Car outlines in car units, y down, (0, 0) the middle of the body. Each part is a convex quad
-- (x1, y1, ..., x4, y4) drawn as two triangles, in this order; `role` picks its colour.
-- Rear view: half-width 1, tyres on the ground at y = 0.55.
local REAR = {
    {"wheel", -1.00, -0.05, -0.62, -0.05, -0.62, 0.55, -1.00, 0.55},
    {"wheel", 0.62, -0.05, 1.00, -0.05, 1.00, 0.55, 0.62, 0.55},
    {"body", -0.80, -0.15, 0.80, -0.15, 0.70, 0.32, -0.70, 0.32},
    {"body", -0.58, -0.15, -0.40, -0.52, 0.40, -0.52, 0.58, -0.15},
    {"window", -0.47, -0.20, -0.33, -0.45, 0.33, -0.45, 0.47, -0.20},
    {"body", -0.34, -0.66, -0.27, -0.66, -0.27, -0.50, -0.34, -0.50},
    {"body", 0.27, -0.66, 0.34, -0.66, 0.34, -0.50, 0.27, -0.50},
    {"body", -0.90, -0.75, 0.90, -0.75, 0.90, -0.65, -0.90, -0.65},
    {"light", -0.66, -0.08, -0.46, -0.08, -0.46, 0.05, -0.66, 0.05},
    {"light", 0.46, -0.08, 0.66, -0.08, 0.66, 0.05, 0.46, 0.05},
}
-- Side view: half-length 1, nose at +x, wheels (below) on the ground at y = 0.55.
local SIDE = {
    {"body", -1.00, -0.12, 0.95, -0.02, 1.00, 0.25, -1.00, 0.25},
    {"body", -0.55, -0.12, -0.35, -0.45, 0.25, -0.45, 0.45, -0.07},
    {"window", -0.44, -0.14, -0.30, -0.39, 0.18, -0.39, 0.33, -0.09},
    {"body", -0.92, -0.48, -0.86, -0.48, -0.86, -0.11, -0.92, -0.11},
    {"body", -1.06, -0.56, -0.70, -0.56, -0.70, -0.48, -1.06, -0.48},
}
local SIDE_WHEELS = {-0.62, 0.30, 0.62, 0.30} -- centres (x, y); radius below
local SIDE_WHEEL_R = 0.25
-- The car tips over the edge of its low side, the way it would roll over: the rear view about
-- the outer edge of the lower tyre, the side view about the lower wheel's contact.
local GROUND_Y = 0.55
local REAR_EDGE_X = 1.00
local SIDE_EDGE_X = 0.62

function render.invalidate(box)
    box._cfg = nil
    box._geoKey = nil
end

local function ensureCfg(box)
    return utils.ensureCfg(box, function(cfg, box)
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.body = resolveThemeColor("fillcolor", getParam(box, "bodycolor"))
        cfg.window = resolveThemeColor("bgcolor", getParam(box, "windowcolor")) or lcd.RGB(0, 0, 0)
        cfg.wheel = resolveThemeColor("wheelcolor", getParam(box, "wheelcolor") or "darkgrey")
        cfg.light = resolveThemeColor("lightcolor", getParam(box, "lightcolor") or "red")
        cfg.ground = resolveThemeColor("textcolor", getParam(box, "groundcolor"))
        cfg.text = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.warn = resolveThemeColor("fillwarncolor", getParam(box, "warncolor"))
        cfg.crit = resolveThemeColor("fillcritcolor", getParam(box, "critcolor"))
        cfg.warnangle = tonumber(getParam(box, "warnangle")) or 20
        cfg.critangle = tonumber(getParam(box, "critangle")) or 35
        cfg.pitchSign = getParam(box, "invertpitch") == true and -1 or 1
        cfg.showpitch = getParam(box, "showpitch") ~= false
        cfg.showvalues = getParam(box, "showvalues") ~= false
        cfg.font = getParam(box, "font") or FONT_XS
        if type(cfg.font) == "string" then cfg.font = _G[cfg.font] or FONT_XS end
        cfg.rollLabel = "@i18n(widgets.dashboard.roll)@"
        cfg.pitchLabel = "@i18n(widgets.dashboard.pitch)@"
    end)
end

-- Angles are drawn to the whole degree: a reading that moves by less repaints nothing.
local function quantize(value)
    value = tonumber(value)
    if value == nil then return nil end
    if value >= 0 then return floor(value + 0.5) end
    return -floor(-value + 0.5)
end

local function angleText(label, value)
    if value == nil then return label .. " --" end
    return format("%s %d°", label, value)
end

function render.wakeup(box)
    local cfg = ensureCfg(box)
    local telemetry = grsuite.tasks.telemetry
    local getSensor = telemetry and telemetry.getSensor
    local roll = getSensor and quantize(getSensor("attroll"))
    local pitch = getSensor and quantize(getSensor("attpitch"))

    local d = box._dyn
    if not d then
        d = {}
        box._dyn = d
    end
    if roll ~= d.roll or d.rollText == nil then
        d.roll = roll
        d.rollText = angleText(cfg.rollLabel, roll)
    end
    if pitch ~= d.pitch or d.pitchText == nil then
        d.pitch = pitch
        d.pitchText = angleText(cfg.pitchLabel, pitch)
    end
end

function render.dirty(box)
    local d = box._dyn
    if not d then return false end
    if d.roll ~= d.paintedRoll or d.pitch ~= d.paintedPitch then
        d.paintedRoll = d.roll
        d.paintedPitch = d.pitch
        return true
    end
    return false
end

-- Turns `parts` (car units) into the corners of their quads in `out`, 8 numbers per part,
-- rotated by `angle` (radians, clockwise on screen) about the car point (edgeX, GROUND_Y), which
-- lands on the screen at (px, py); `scale` pixels per car unit. Returns the count written.
local function placeParts(parts, out, px, py, scale, angle, edgeX)
    local s, c = sin(angle), cos(angle)
    local n = 0
    for i = 1, #parts do
        local part = parts[i]
        for k = 0, 3 do
            local ux = (part[2 + k * 2] - edgeX) * scale
            local uy = (part[3 + k * 2] - GROUND_Y) * scale
            out[n + 1 + k * 2] = px + ux * c - uy * s
            out[n + 2 + k * 2] = py + ux * s + uy * c
        end
        n = n + 8
    end
    return n
end

-- Screen geometry, rebuilt only when the box moves or an angle changes.
local function ensureGeometry(box, c, d, x, y, w, h)
    local key = x + y * 4096 + w * 16777216 + h * 68719476736
    if box._geoKey == key and box._geoRoll == d.roll and box._geoPitch == d.pitch then return box._geo end
    box._geoKey, box._geoRoll, box._geoPitch = key, d.roll, d.pitch

    local g = box._geo
    if not g then
        g = {rear = {}, side = {}, wheels = {}}
        box._geo = g
    end

    local textH = 0
    if c.showvalues then
        lcd.font(c.font)
        local _, th = lcd.getTextSize("0")
        textH = (th or 12) + 2
    end
    local rearW = c.showpitch and floor(w * 0.6) or w
    local sideW = w - rearW
    -- Room above the ground line, with some to spare for a tipped car's corners.
    local room = h - textH - 10
    -- Tipping over an edge moves the car towards that side: keep room for it at 30 degrees.
    local rearScale = min(rearW * 0.30, room / 1.6)
    local sideScale = min(sideW * 0.34, room / 1.5)
    -- The car (1.3 units above the ground), the ground line and the text, centred in the box.
    local carH = 1.3 * rearScale
    local groundY = floor(y + (h - carH - textH - 3) / 2 + carH)

    g.groundY = groundY
    g.textY = groundY + 3
    g.rearCx = x + rearW / 2
    g.sideCx = x + rearW + sideW / 2

    -- Positive angles tip the car clockwise on screen: its right side (rear view) or its nose
    -- (side view) goes down, so it turns over that side's edge.
    local roll = d.roll or 0
    local edge = roll >= 0 and REAR_EDGE_X or -REAR_EDGE_X
    g.rearN = placeParts(REAR, g.rear, g.rearCx + edge * rearScale, groundY, rearScale, rad(roll), edge)

    local pitch = (d.pitch or 0) * c.pitchSign
    if c.showpitch then
        local angle = rad(pitch)
        edge = pitch >= 0 and SIDE_EDGE_X or -SIDE_EDGE_X
        local px = g.sideCx + edge * sideScale
        g.sideN = placeParts(SIDE, g.side, px, groundY, sideScale, angle, edge)
        local s, co = sin(angle), cos(angle)
        for i = 1, #SIDE_WHEELS, 2 do
            local ux = (SIDE_WHEELS[i] - edge) * sideScale
            local uy = (SIDE_WHEELS[i + 1] - GROUND_Y) * sideScale
            g.wheels[i] = px + ux * co - uy * s
            g.wheels[i + 1] = groundY + ux * s + uy * co
        end
        g.wheelR = SIDE_WHEEL_R * sideScale
    else
        g.sideN = 0
    end

    local worst = abs(roll)
    if c.showpitch and abs(pitch) > worst then worst = abs(pitch) end
    if worst >= c.critangle then
        g.bodyColor = c.crit or c.body
    elseif worst >= c.warnangle then
        g.bodyColor = c.warn or c.body
    else
        g.bodyColor = c.body
    end
    return g
end

local function drawParts(parts, pts, n, c, bodyColor)
    local tri = lcd.drawFilledTriangle
    for i = 0, n - 1, 8 do
        local role = parts[i // 8 + 1][1]
        local color
        if role == "wheel" then
            color = c.wheel
        elseif role == "window" then
            color = c.window
        elseif role == "light" then
            color = c.light
        else
            color = bodyColor
        end
        if color then
            lcd.color(color)
            tri(pts[i + 1], pts[i + 2], pts[i + 3], pts[i + 4], pts[i + 5], pts[i + 6])
            tri(pts[i + 1], pts[i + 2], pts[i + 5], pts[i + 6], pts[i + 7], pts[i + 8])
        end
    end
end

function render.paint(x, y, w, h, box)
    local c = box._cfg
    local d = box._dyn
    if not c or not d then return end

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)
    local g = ensureGeometry(box, c, d, x, y, w, h)

    lcd.setClipping(x, y, w, h)

    if c.ground then
        lcd.color(c.ground)
        lcd.drawLine(x + 2, g.groundY, x + w - 3, g.groundY)
    end

    drawParts(REAR, g.rear, g.rearN, c, g.bodyColor)

    if c.showpitch then
        drawParts(SIDE, g.side, g.sideN, c, g.bodyColor)
        if c.wheel then
            lcd.color(c.wheel)
            local wheels = g.wheels
            for i = 1, #wheels, 2 do
                lcd.drawFilledCircle(wheels[i], wheels[i + 1], g.wheelR)
            end
        end
    end

    if c.showvalues and c.text then
        lcd.font(c.font)
        lcd.color(c.text)
        lcd.drawText(g.rearCx, g.textY, d.rollText, CENTERED)
        if c.showpitch then lcd.drawText(g.sideCx, g.textY, d.pitchText, CENTERED) end
    end

    lcd.setClipping(0, 0, lcd.getWindowSize())
end

render.scheduler = 0.1

return render
