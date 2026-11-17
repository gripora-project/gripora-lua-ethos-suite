-- Setup Wizard step: Receiver (check only). Opened by app/pages/setup_wizard.lua.
--
-- The configurator's StepReceiver.svelte also sets up the receiver port and
-- protocol. The radio talks to the flight controller through the receiver,
-- so that part stays in the Configurator: if this page is open, the link
-- already works. What is left is the channel order and direction check.
-- Gripora drives a car, so only steering and throttle are asked for; roll
-- and pitch stay parked on spare channels (lib/setup_wizard_controls.lua).
--
--   check   two live bars (steering, throttle, read as the configurator
--           does: the raw receiver channel the RX map points at, scaled by
--           rc_center and rc_deflection). Wheel full left, trigger full
--           brake, and both bars should go left. "Car order" sets the order
--           car radios send (CH1 steering, CH2 throttle) when the map is
--           anything else; "Bars are wrong" offers Detect.
--   detect  turn the wheel, then pull the trigger; the channel that clearly
--           moves is that function's (lib/setup_wizard_controls.lua
--           movedChannel()), and the map is written (MSP_SET_RX_MAP).
--
-- A reversed bar is fixed on the radio, not here, as the configurator says.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()).
local OWNED = ui.notLoaded({"grsuite.lib.setup_wizard_controls", "grsuite.lib.msp_rx_map", "grsuite.lib.msp_rc_config"})
local controls = requireModule("lib/setup_wizard_controls.lua")
local rxMap = requireModule("lib/msp_rx_map.lua")
local rcConfig = requireModule("lib/msp_rc_config.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.rx_title)@",
  check = "@i18n(app.modules.setup_wizard.rx_check_car)@",
  order = "@i18n(app.modules.setup_wizard.rx_order_car_fmt)@",
  carHint = "@i18n(app.modules.setup_wizard.rx_car_hint)@",
  carOrder = "@i18n(app.modules.setup_wizard.rx_car_order)@",
  reversed = "@i18n(app.modules.setup_wizard.rx_reversed)@",
  detectTitle = "@i18n(app.modules.setup_wizard.rx_detect_title)@",
  wrong = "@i18n(app.modules.setup_wizard.rx_wrong)@",
  restart = "@i18n(app.modules.setup_wizard.rx_restart)@",
}

-- The controls, each with its slot in the RX map (3 = yaw, 4 = throttle).
local FUNCTIONS = {
  {name = "@i18n(app.modules.setup_wizard.axis_steering)@", slot = 3,
    move = "@i18n(app.modules.setup_wizard.rx_move_steering)@"},
  {name = "@i18n(app.modules.setup_wizard.axis_throttle)@", slot = 4,
    move = "@i18n(app.modules.setup_wizard.rx_move_trigger)@"},
}
local STEERING, THROTTLE = 1, 2

-- A control this far out (of 1) counts as at its end.
local TARGET = 0.85
-- Room the bars need, in text lines.
local BARS_LINES = 4

local function new(wiz)
  local self = {liveRc = "raw"}
  local scr = ui.new(wiz)

  local screen = "check"
  local map = nil
  local centre, span = 1500, 500
  local found, baseline, peaks = {}, {}, {}

  wiz.fetch({
    map = function(ok, err) return rxMap.buildReadMessage(ok, err) end,
    rc = function(ok, err) return rcConfig.buildReadMessage(ok, err) end,
  }, function(results)
    map = results.map and rxMap.toList(results.map) or controls.carMap(0, 1)
    if results.rc then
      centre = results.rc.rc_center or centre
      span = results.rc.rc_deflection or span
    end
    wiz.rebuild()
  end)

  -- -1..1 for control i (STEERING or THROTTLE), or nil when unknown.
  local function reading(i)
    local raw = map and wiz.rcRaw[(map[FUNCTIONS[i].slot] or 0) + 1]
    if not raw or raw <= 0 then return nil end
    local f = (raw - centre) / span
    if f < -1 then f = -1 elseif f > 1 then f = 1 end
    return f
  end

  local function startDetect()
    found = {}
    screen = "detect"
    for i = 1, #wiz.rcRaw do baseline[i] = wiz.rcRaw[i]; peaks[i] = 0 end
    for i = #wiz.rcRaw + 1, #baseline do baseline[i], peaks[i] = nil, nil end
    wiz.rebuild()
  end

  local function writeMap(newMap)
    wiz.change("rx_map", map, function(o)
      bus.publish("msp.request", rxMap.buildWriteMessage(o))
    end)
    map = newMap
    bus.publish("msp.request", rxMap.buildWriteMessage(map))
  end

  local function useCarOrder()
    writeMap(controls.carMap(0, 1))
    wiz.rebuild()
  end

  -- One bar per control, the target (full left) marked at its left end.
  local function drawBars(x, y, w, h, colors)
    lcd.font(FONT_S)
    local _, th = lcd.getTextSize("Ag")
    local rowH = math.min(math.floor(h / #FUNCTIONS), th + 14)
    local labelW = 0
    for i = 1, #FUNCTIONS do labelW = math.max(labelW, (lcd.getTextSize(FUNCTIONS[i].name))) end
    labelW = labelW + 10
    for i = 1, #FUNCTIONS do
      local ry = y + (i - 1) * rowH
      local f = reading(i)
      local there = f and f <= -TARGET
      lcd.color(there and colors.active or colors.text)
      lcd.drawText(x, ry + math.floor((rowH - th) / 2), FUNCTIONS[i].name, LEFT)
      ui.gauge(x + labelW, ry + 3, w - labelW - 4, rowH - 6, f and (f + 1) / 2 or nil, colors, 0, (1 - TARGET) / 2)
    end
  end

  -- Steering across, throttle up and down: a square with the target corner
  -- (bottom left) marked and a dot where the two are.
  local padName = FUNCTIONS[STEERING].name .. " / " .. FUNCTIONS[THROTTLE].name
  local function drawPad(x, y, w, h, colors)
    lcd.font(FONT_XS)
    local _, lh = lcd.getTextSize("Ag")
    local s = math.min(w - 8, h - lh - 6)
    if s < 30 then return end
    local gx = x + math.floor((w - s) / 2)
    local y0 = y + math.floor((h - s - lh - 4) / 2)
    local r = math.max(3, math.floor(s * 0.07))
    local cx, cy = gx + math.floor(s / 2), y0 + math.floor(s / 2)
    lcd.color(colors.surface)
    lcd.drawRectangle(gx, y0, s, s)
    lcd.drawLine(cx, y0 + 4, cx, y0 + s - 4)
    lcd.drawLine(gx + 4, cy, gx + s - 4, cy)
    -- The corner to go to.
    local z = math.floor(s * (1 - TARGET) / 2) + r
    lcd.color(colors.active)
    lcd.drawRectangle(gx + 1, y0 + s - z - 1, z, z)
    local fx, fy = reading(STEERING), reading(THROTTLE)
    if fx and fy then
      local px = cx + math.floor(fx * (s / 2 - r - 2))
      local py = cy - math.floor(fy * (s / 2 - r - 2))
      lcd.color((fx <= -TARGET and fy <= -TARGET) and colors.active or colors.text)
      lcd.drawLine(cx, cy, px, py)
      lcd.drawFilledCircle(px, py, r)
    end
    lcd.color(colors.muted)
    lcd.drawText(gx + math.floor(s / 2), y0 + s + 4, padName, CENTERED)
  end

  function self.build()
    scr:begin()
    if not map then
      scr:text(T.title, "@i18n(app.msg_loading)@")
      return nil
    end
    if screen == "check" then
      local body = T.check .. " " .. string.format(T.order, map[FUNCTIONS[STEERING].slot] + 1,
        map[FUNCTIONS[THROTTLE].slot] + 1)
      local buttons = {{text = T.wrong, press = startDetect}}
      if not controls.isCarMap(map) then
        body = body .. " " .. T.carHint
        table.insert(buttons, 1, {text = T.carOrder, press = useCarOrder})
      end
      scr:text(T.title, body, T.reversed)
      scr:draw(drawPad, nil, true)
      scr:live(drawBars, BARS_LINES)
      -- Next when the bars follow the controls; Detect when they don't.
      return scr:row(nil, buttons)
    end
    local fn = FUNCTIONS[#found + 1]
    scr:text(T.detectTitle, fn.move)
    scr:draw(drawPad, nil, true)
    scr:live(drawBars, BARS_LINES)
    -- Back cancels; the order is written once both have moved.
    return scr:row(function() screen = "check"; wiz.rebuild() end,
      {{text = T.restart, primary = true, press = startDetect}}, false)
  end

  function self.paint() scr:paint() end

  local lastShown = {}

  function self.wakeup()
    if screen == "detect" then
      local raw = wiz.rcRaw
      for i = 1, #raw do
        if baseline[i] == nil then baseline[i], peaks[i] = raw[i], 0 end
        local move = math.abs(raw[i] - baseline[i])
        if move > (peaks[i] or 0) then peaks[i] = move end
      end
      local channel = controls.movedChannel(peaks, found)
      if channel >= 0 then
        found[#found + 1] = channel
        -- The next control starts from where everything is now.
        for i = 1, #raw do baseline[i], peaks[i] = raw[i], 0 end
        if #found == #FUNCTIONS then
          writeMap(controls.carMap(found[STEERING], found[THROTTLE]))
          screen = "check"
        end
        wiz.rebuild()
        return
      end
    end
    -- Redraw the bars when a reading moves.
    for i = 1, #FUNCTIONS do
      local f = reading(i)
      if f ~= lastShown[i] then
        lastShown[i] = f
        wiz.invalidate()
      end
    end
  end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}
