-- Setup Wizard pictures: the car seen from above, nose up, as on the
-- configurator's car pictures (CarSide/GyroCheckArt/SteerBothWays). The
-- front wheels steer (S1); a car with rear steering (S2 in the car mixer
-- preset, lib/setup_wizard_mix.lua) has its rear wheels steer too, against
-- the front ones or with them, as the mix says. A check lights the steering
-- wheels and turns them the way they should go; the gyro check also draws
-- how the car is turned by hand.
--
-- layout() runs when a screen is built; draw() runs from paint and only does
-- arithmetic and drawing on what layout() worked out, so it allocates
-- nothing. The Sensors step's 3D car is app/car3d.lua.

if package.loaded["grsuite.app.setup_wizard_art"] then
  return package.loaded["grsuite.app.setup_wizard_art"]
end

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local car3d = requireModule("app/car3d.lua")

local floor = math.floor
local sin, cos = math.sin, math.cos

local art = {}

-- Kept for the shell, which sets it from MSP_MIXER_CONFIG; the car picture
-- does not depend on it.
art.modelType = nil

-- How far the wheels are drawn turned on a check.
local STEER_ANGLE = math.rad(24)

-- The rear steering mode the mix has: nil, "opposite" or "same". The front
-- servo is the lowest-numbered one on yaw; another one on yaw is the rear,
-- opposite when its weight is negative.
local function rearMode(surfaces)
  local first = nil
  for i = 1, #surfaces do
    local s = surfaces[i]
    if s.axes and s.axes.yaw then
      if not first or s.servo < first.servo then first = s end
    end
  end
  if not first then return nil end
  for i = 1, #surfaces do
    local s = surfaces[i]
    if s ~= first and s.axes and s.axes.yaw then
      return (s.axes.yaw.pos or 0) < 0 and "opposite" or "same"
    end
  end
  return nil
end

function art.baseLayout(surfaces, axis)
  return {
    rear = rearMode(surfaces),
    steering = #surfaces > 0,
    -- +1 steer right, -1 left, nil straight ahead
    steer = (axis == "yaw") and 1 or nil,
    lit = axis == "yaw",
    turn = false,
  }
end

-- What to draw for this mix, and what the check moves.
-- surfaces: wiz.surfaces(); axis: "yaw" for a steering check, nil for none.
-- flip: the gyro answering a turn by hand: the car is turned clockwise (an
-- arrow over the nose) and the wheels steer left, against it.
function art.layout(surfaces, axis, flip)
  local l = art.baseLayout(surfaces, axis)
  if axis == "yaw" and flip then
    l.steer = -1
    l.turn = true
  end
  return l
end

-- The car with its steering wheels lit at centre, for a step that works one
-- servo at a time (Center).
function art.surfaceLayout(surfaces)
  local l = art.baseLayout(surfaces, nil)
  l.lit = true
  return l
end

-- A "done" badge: a green disc with a white tick, centred on cx, cy.
local tickGreen, tickWhite = nil, nil

local function thickLine(x1, y1, x2, y2, half)
  local dx, dy = x2 - x1, y2 - y1
  local l = math.sqrt(dx * dx + dy * dy)
  if l < 1 then return end
  local nx, ny = -dy / l * half, dx / l * half
  lcd.drawFilledTriangle(x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny)
  lcd.drawFilledTriangle(x1 + nx, y1 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny)
end

function art.tick(cx, cy, r)
  if not tickGreen then tickGreen, tickWhite = lcd.RGB(46, 160, 67), lcd.RGB(255, 255, 255) end
  lcd.color(tickGreen)
  lcd.drawFilledCircle(cx, cy, r)
  lcd.color(tickWhite)
  local half = math.max(2, floor(r * 0.09))
  local ax, ay = cx - floor(r * 0.45), cy + floor(r * 0.02)
  local bx, by = cx - floor(r * 0.12), cy + floor(r * 0.36)
  local qx, qy = cx + floor(r * 0.48), cy - floor(r * 0.32)
  thickLine(ax, ay, bx, by, half)
  thickLine(bx, by, qx, qy, half)
  lcd.drawFilledCircle(bx, by, half)
end

-- The car with the done badge in the corner (a step's or the wizard's end).
-- l: a layout, art.layout(wiz.surfaces(), nil).
function art.done(l, x, y, w, h, colors)
  art.draw(l, x, y, w, h, colors)
  local r = math.max(12, floor(math.min(w, h) * 0.17))
  art.tick(x + w - r - 6, y + h - r - 6, r)
end

-- The 3D pictures' background work (car3d.service()): the wizard calls
-- it from every wakeup.
art.service = car3d.service

-- A rectangle (half sizes hw x hh) centred on cx, cy and turned by angle
-- (radians, clockwise on screen), as two triangles.
local function turnedRect(cx, cy, hw, hh, angle)
  local c, s = cos(angle), sin(angle)
  local ax, ay = cx - hw * c + hh * s, cy - hw * s - hh * c
  local bx, by = cx + hw * c + hh * s, cy + hw * s - hh * c
  local qx, qy = cx + hw * c - hh * s, cy + hw * s + hh * c
  local dx, dy = cx - hw * c - hh * s, cy - hw * s + hh * c
  lcd.drawFilledTriangle(ax, ay, bx, by, qx, qy)
  lcd.drawFilledTriangle(ax, ay, qx, qy, dx, dy)
end

-- An arrow from x1, y1 to x2, y2, its head at the end.
local function arrow(x1, y1, x2, y2, half, head)
  local dx, dy = x2 - x1, y2 - y1
  local l = math.sqrt(dx * dx + dy * dy)
  if l < 1 then return end
  local ux, uy = dx / l, dy / l
  local bx, by = x2 - ux * head, y2 - uy * head
  thickLine(x1, y1, bx, by, half)
  local px, py = -uy * head * 0.7, ux * head * 0.7
  lcd.drawFilledTriangle(x2, y2, bx + px, by + py, bx - px, by - py)
end

-- The car from above in x, y, w, h: body, cabin and four wheels; the
-- steering wheels lit and turned for a check, with an arrow ahead of them,
-- and for the gyro check an arrow over the nose for the turn by hand.
function art.draw(l, x, y, w, h, colors)
  local turnRoom = l.turn and 0.22 or 0.06
  local carH = math.min(h * (1 - turnRoom) * 0.9, w * 1.5)
  local carW = carH * 0.48
  local cx = x + w / 2
  local cy = y + h * turnRoom + h * (1 - turnRoom) / 2
  local top, bottom = cy - carH / 2, cy + carH / 2

  -- Wheels first, the body over their inner edges.
  local wheelHW, wheelHH = carW * 0.13, carH * 0.1
  local wheelX = carW / 2
  local frontY, rearY = top + carH * 0.2, bottom - carH * 0.2
  local steer = l.steer or 0
  local frontAngle = steer * STEER_ANGLE
  local rearAngle = 0
  if l.rear == "opposite" then rearAngle = -frontAngle elseif l.rear == "same" then rearAngle = frontAngle end

  lcd.color((l.lit and l.steering) and colors.active or colors.surface)
  turnedRect(cx - wheelX, frontY, wheelHW, wheelHH, frontAngle)
  turnedRect(cx + wheelX, frontY, wheelHW, wheelHH, frontAngle)
  lcd.color((l.lit and l.rear) and colors.active or colors.surface)
  turnedRect(cx - wheelX, rearY, wheelHW, wheelHH, rearAngle)
  turnedRect(cx + wheelX, rearY, wheelHW, wheelHH, rearAngle)

  -- Body: a long block with a tapered nose, and the cabin on it.
  local bodyHW = carW * 0.38
  local noseY = top + carH * 0.04
  local shoulderY = top + carH * 0.12
  lcd.color(colors.body)
  lcd.drawFilledRectangle(floor(cx - bodyHW), floor(shoulderY), floor(bodyHW * 2), floor(bottom - shoulderY))
  lcd.drawFilledTriangle(cx - bodyHW, shoulderY, cx + bodyHW, shoulderY, cx + bodyHW * 0.6, noseY)
  lcd.drawFilledTriangle(cx - bodyHW, shoulderY, cx + bodyHW * 0.6, noseY, cx - bodyHW * 0.6, noseY)
  lcd.color(colors.muted)
  lcd.drawFilledRectangle(floor(cx - bodyHW * 0.7), floor(cy - carH * 0.12), floor(bodyHW * 1.4), floor(carH * 0.3))

  local half = math.max(2, floor(carW * 0.035))
  local head = math.max(6, floor(carW * 0.16))
  if steer ~= 0 and l.lit then
    -- Which way the front wheels steer: an arrow just ahead of them.
    lcd.color(colors.active)
    local ay = frontY - wheelHH - head
    arrow(cx - carW * 0.15 * steer, ay, cx + carW * 0.35 * steer, ay, half, head)
  end
  if l.turn then
    -- The turn by hand, clockwise seen from above: the nose goes right.
    lcd.color(colors.text)
    local ty = y + h * turnRoom * 0.5
    arrow(cx - carW * 0.4, ty + head * 0.5, cx + carW * 0.5, ty - head * 0.2, half, head)
  end
end

-- A servo seen from above: its horn on an arc from Min (left) to Max
-- (right), for the Binding limits step. Positions are fractions of the way
-- out, -1 (full Min) .. 1 (full Max), drawn up to 75 degrees either side of
-- straight up. d is the caller's own table, refilled in place each paint:
--   pos              where the horn is
--   zoneFrom, zoneTo the stored limits (a band on the arc), or nil
--   side             "min" | "max": the half being found, lit as the horn
--                    moves along it; nil for none
--   saved            a tick at this position (a stored or just-set limit)
--   stop             a wall at this position: where the linkage binds
--   back             an arrow from the horn back towards the centre
local SWING = math.rad(75)
local sin, cos = math.sin, math.cos

local function dialPoint(cx, cy, r, f)
  local a = math.pi / 2 - f * SWING
  return cx + floor(r * cos(a) + 0.5), cy - floor(r * sin(a) + 0.5)
end

-- The arc's angles at fixed steps, worked out once: paint only looks them up.
local GRID = 20
local GRID_COS, GRID_SIN = {}, {}
for i = 0, GRID do
  local a = math.pi / 2 - (-1 + 2 * i / GRID) * SWING
  GRID_COS[i], GRID_SIN[i] = cos(a), sin(a)
end

-- The arc from..to as a band thick pixels deep inside radius r: each step a
-- quad of two filled triangles, the ends cut exactly at from and to.
local function dialArc(cx, cy, r, from, to, thick)
  if to <= from then return end
  local ri = r - thick
  local a = math.pi / 2 - from * SWING
  local c0, s0 = cos(a), sin(a)
  local ox0, oy0 = cx + floor(r * c0 + 0.5), cy - floor(r * s0 + 0.5)
  local ix0, iy0 = cx + floor(ri * c0 + 0.5), cy - floor(ri * s0 + 0.5)
  local i = floor((from + 1) * GRID / 2) + 1
  while true do
    local c1, s1
    local last = i > GRID or (-1 + 2 * i / GRID) >= to
    if last then
      a = math.pi / 2 - to * SWING
      c1, s1 = cos(a), sin(a)
    else
      c1, s1 = GRID_COS[i], GRID_SIN[i]
    end
    local ox1, oy1 = cx + floor(r * c1 + 0.5), cy - floor(r * s1 + 0.5)
    local ix1, iy1 = cx + floor(ri * c1 + 0.5), cy - floor(ri * s1 + 0.5)
    lcd.drawFilledTriangle(ox0, oy0, ix0, iy0, ox1, oy1)
    lcd.drawFilledTriangle(ix0, iy0, ix1, iy1, ox1, oy1)
    if last then return end
    ox0, oy0, ix0, iy0 = ox1, oy1, ix1, iy1
    i = i + 1
  end
end

-- A radial bar across the arc, r1 out to r2, half as wide as hw.
local function dialBar(cx, cy, r1, r2, f, hw)
  local a = math.pi / 2 - f * SWING
  local px, py = sin(a) * hw, cos(a) * hw
  local x1, y1 = cx + r1 * cos(a), cy - r1 * sin(a)
  local x2, y2 = cx + r2 * cos(a), cy - r2 * sin(a)
  local ax, ay = floor(x1 + px + 0.5), floor(y1 + py + 0.5)
  local bx, by = floor(x1 - px + 0.5), floor(y1 - py + 0.5)
  local qx, qy = floor(x2 + px + 0.5), floor(y2 + py + 0.5)
  local dx, dy = floor(x2 - px + 0.5), floor(y2 - py + 0.5)
  lcd.drawFilledTriangle(ax, ay, bx, by, qx, qy)
  lcd.drawFilledTriangle(bx, by, dx, dy, qx, qy)
end

local function clampUnit(f)
  if f < -1 then return -1 elseif f > 1 then return 1 end
  return f
end

function art.servoDial(cx, cy, r, d, colors)
  local t = math.max(3, floor(r / 18))
  -- A thin track, the stored range thick on it.
  lcd.color(colors.body)
  dialArc(cx, cy, r - floor(t / 2) + 1, -1, 1, 2)
  if d.zoneFrom and d.zoneTo then
    lcd.color(colors.surface)
    dialArc(cx, cy, r, clampUnit(d.zoneFrom), clampUnit(d.zoneTo), t)
  end
  local pos = clampUnit(d.pos or 0)
  lcd.color(colors.active)
  if d.side == "min" and pos < 0 then
    dialArc(cx, cy, r, pos, 0, t)
  elseif d.side == "max" and pos > 0 then
    dialArc(cx, cy, r, 0, pos, t)
  end
  -- Centre: where the horn starts on every side.
  lcd.color(colors.muted)
  dialBar(cx, cy, r + 4, r - t - 6, 0, 1)
  if d.saved then
    lcd.color(colors.text)
    dialBar(cx, cy, r + 6, r - t - 8, clampUnit(d.saved), 1.5)
  end
  if d.stop then
    -- The linkage binding: a solid block across the arc.
    lcd.color(colors.text)
    dialBar(cx, cy, r + 9, r - t - 9, clampUnit(d.stop), math.max(3, r / 14))
  end

  -- The horn: a tapered arm from the hub, rounded at the tip.
  local a = math.pi / 2 - pos * SWING
  local reach = floor(r * 0.82)
  local tx, ty = cx + floor(reach * cos(a) + 0.5), cy - floor(reach * sin(a) + 0.5)
  local hw = math.max(4, floor(r * 0.09))
  local px, py = floor(sin(a) * hw + 0.5), floor(cos(a) * hw + 0.5)
  lcd.color(d.side and pos ~= 0 and colors.active or colors.surface)
  lcd.drawFilledTriangle(tx, ty, cx + px, cy + py, cx - px, cy - py)
  lcd.drawFilledCircle(tx, ty, math.max(2, floor(hw / 2)))
  lcd.color(colors.body)
  lcd.drawFilledCircle(cx, cy, hw + 2)

  if d.back and pos ~= 0 then
    -- Just inside the arc, from the horn towards the centre.
    local dir = pos > 0 and -1 or 1
    local ar = r - t - floor(r * 0.16)
    local f1 = pos + dir * 0.06
    local f2 = pos + dir * 0.28
    lcd.color(colors.text)
    dialArc(cx, cy, ar + 1, math.min(f1, f2), math.max(f1, f2), 2)
    local hx, hy = dialPoint(cx, cy, ar, f2 + dir * 0.08)
    local bx1, by1 = dialPoint(cx, cy, ar - 5, f2)
    local bx2, by2 = dialPoint(cx, cy, ar + 5, f2)
    lcd.drawFilledTriangle(hx, hy, bx1, by1, bx2, by2)
  end
end

-- Where a servo dial of radius r puts its arc ends (for their labels):
-- dx out from the centre, dy up from it.
function art.dialEnds(r)
  return floor(r * sin(SWING) + 0.5), floor(r * cos(SWING) + 0.5)
end

local cachedDark, cachedColors = nil, nil

function art.colors()
  local dark = lcd.darkMode and lcd.darkMode() or false
  if dark ~= cachedDark or not cachedColors then
    cachedDark = dark
    cachedColors = {
      body = dark and lcd.GREY(110) or lcd.GREY(150),
      surface = dark and lcd.GREY(170) or lcd.GREY(90),
      active = lcd.RGB(255, 165, 30),
      text = dark and lcd.GREY(240) or lcd.GREY(20),
      muted = dark and lcd.GREY(170) or lcd.GREY(90),
    }
  end
  return cachedColors
end

package.loaded["grsuite.app.setup_wizard_art"] = art
return art
