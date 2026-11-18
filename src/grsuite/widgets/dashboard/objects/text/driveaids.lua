--[[
    The car's drive aids and driving mode in one word, from the drive status telemetry sensor
    (gripora-firmware TELEM_DRIVE_STATUS, decoded by lib/drive_status.lua). Most urgent first:

        GYRO OFF    stabilisation bypassed                          offcolor
        ABS         ABS releasing the brake                         activecolor
        TC          traction control holding the throttle back      activecolor
        LAUNCH      launching                                       activecolor
        LAUNCH      launch staged, waiting for the throttle         stagedcolor
        DRIFT       DRIFT mode                                      modecolor
        AIDS OFF    the DRIVE AIDS OFF switch is on                 offcolor
        ABS / TC    braking / driving with ABS / TC watching        oncolor
        AIDS ON     the aids are running                            oncolor
        OFF         the aids are not running (disarmed, failsafe)   textcolor

    The inherited "governor" subtype is an alias of this one, so a theme written for a heli shows
    the car's drive aids in its governor tile.

    Most parameters are those of armflags.lua. The ones specific to this box:

    novalue             : string                    -- (Optional) Text shown while the sensor is missing (default: "-")
    thresholds          : table                     -- (Optional) {value = <text>, textcolor = ...} entries; a match overrides the colours below
    offcolor            : color                     -- (Optional) GYRO OFF and AIDS OFF (default: red)
    activecolor         : color                     -- (Optional) An aid acting right now (default: orange)
    stagedcolor         : color                     -- (Optional) Launch staged (default: yellow; dark amber on a light theme)
    modecolor           : color                     -- (Optional) DRIFT (default: blue)
    oncolor             : color                     -- (Optional) Aids running (default: green)
    textcolor           : color                     -- (Optional) OFF, and the no-value text (theme fallback if nil)
]]

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local grsuite = requireModule("widgets/dashboard/context.lua")
local driveStatus = requireModule("lib/drive_status.lua")

local TEXT = driveStatus.TEXT
local LEVEL = driveStatus.LEVEL

local render = {}

-- Bright yellow does not read on a light background: dark amber there (about 5:1 on white).
local function STAGED_DEFAULT()
    if type(lcd.darkMode) == "function" and lcd.darkMode() == false then return {150, 100, 0} end
    return "yellow"
end

local utils = grsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local getPulsingDots = utils.getPulsingDots
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

function render.invalidate(box)
    box._cfg = nil
    box._textLayout = nil
end

-- ABS, TC and LAUNCH keep their word between watching and acting: a change of colour alone
-- must repaint too.
function render.dirty(box)
    local colorChanged = box._dynamicTextColor ~= box._lastTextColor
    box._lastTextColor = box._dynamicTextColor
    return utils.dirtyOnDisplayValueChange(box) or colorChanged
end

-- A theme's {value = <text>, textcolor = ...} entry for this text, or nil.
local function thresholdColor(box, value)
    local thresholds = getParam(box, "thresholds")
    if type(thresholds) ~= "table" then return nil end
    for i = 1, #thresholds do
        local threshold = thresholds[i]
        local thresholdValue = threshold.value
        if type(thresholdValue) == "function" then thresholdValue = thresholdValue(box, value) end
        if thresholdValue == value and threshold.textcolor then
            return resolveThemeColor("textcolor", threshold.textcolor)
        end
    end
    return nil
end

local function ensureCfg(box)
    return utils.ensureCfg(box, function(cfg, box)
        cfg.title = getParam(box, "title")
        cfg.titlepos = getParam(box, "titlepos")
        cfg.titlealign = getParam(box, "titlealign")
        cfg.titlefont = getParam(box, "titlefont")
        cfg.titlespacing = getParam(box, "titlespacing")
        cfg.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.titlepadding = getParam(box, "titlepadding")
        cfg.titlepaddingleft = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")
        cfg.font = getParam(box, "font")
        cfg.valuealign = getParam(box, "valuealign")
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.novalue = getParam(box, "novalue") or "-"
        cfg.unit = nil
        cfg.defaultTextColor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        -- level -> colour (lib/drive_status.lua's LEVEL).
        cfg.levelColor = {
            off = resolveThemeColor("offcolor", getParam(box, "offcolor") or "red"),
            active = resolveThemeColor("activecolor", getParam(box, "activecolor") or "orange"),
            staged = resolveThemeColor("stagedcolor", getParam(box, "stagedcolor") or STAGED_DEFAULT()),
            mode = resolveThemeColor("modecolor", getParam(box, "modecolor") or "blue"),
            on = resolveThemeColor("oncolor", getParam(box, "oncolor") or "green"),
            idle = cfg.defaultTextColor,
        }
    end)
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local telemetry = grsuite.tasks.telemetry
    local raw = telemetry and telemetry.getSensor("drive_status")
    local state = driveStatus.state(raw)

    local displayValue, levelColor
    if state then
        displayValue = TEXT[state]
        levelColor = cfg.levelColor[LEVEL[state]]
    elseif telemetry and telemetry.active and telemetry.active() then
        displayValue = cfg.novalue
    else
        displayValue = getPulsingDots(box)
    end

    box._dynamicTextColor = thresholdColor(box, displayValue) or levelColor or cfg.defaultTextColor
    box._currentDisplayValue = displayValue

    if box._dashboardRectW and box._dashboardRectH then
        local x, y = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local w, h
        x, y, w, h = utils.boxContentRect(x, y, box._dashboardRectW, box._dashboardRectH, cfg.bgcolor)
        prepareTextLayout(box, x, y, w, h, cfg.title, cfg.titlepos, cfg.titlealign, cfg.titlefont, cfg.titlespacing, cfg.titlepadding, cfg.titlepaddingleft, cfg.titlepaddingright, cfg.titlepaddingtop, cfg.titlepaddingbottom, box._currentDisplayValue, cfg.unit, cfg.font, cfg.valuealign, cfg.valuepadding, cfg.valuepaddingleft, cfg.valuepaddingright, cfg.valuepaddingtop, cfg.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}
    local textColor = box._dynamicTextColor or c.defaultTextColor

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)
    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, box._currentDisplayValue, c.unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, textColor, c.titlecolor)
end

render.scheduler = 0.5

return render
