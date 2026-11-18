-- The 3D model: a low-poly car drawn at a given attitude inside a box. Used
-- by the Alignment page (app/alignment_visual.lua) and the Setup Wizard's
-- Sensors step. (The file keeps the name it had when it drew aircraft.)
--
-- The car is the Configurator's preview car (gripora-configurator
-- src/js/car_model.js) in low poly: orange body, dark cabin, four six-sided
-- wheels with grey hubs, a rear wing, headlights and red tail lights. Its
-- numbers are that file's, in the same glTF-style axes (x = width, y = up,
-- z = aft, nose at -z).
--
--   plane3d.draw(x, y, w, h, roll, pitch, yaw[, zoom])   -- from paint
--   plane3d.service()          -- from wakeup, on every page that draws it
--   local ux, uy = plane3d.noseDirection(roll, pitch, yaw)
--
-- Ethos stops any callback that runs 20000 Lua instructions, so neither the
-- mesh build nor a frame happens in paint: service() does one step per wakeup
-- (a build stage, or one of four frame stages) and finishes a frame into a
-- display list of screen triangles; draw() records the view it wants and
-- replays the last finished frame for that box. A new view shows a few
-- wakeups later; a live attitude runs a frame behind.
--
-- Angles are degrees in MSP_ATTITUDE's sense. Yaw 0 shows the model from
-- behind, as the driver sees it standing behind the car; callers that follow
-- the live heading subtract their own reference yaw first. draw() sizes the
-- model so it fits the box in any attitude (at zoom 1) and clips to the box.
--
-- The mesh is written in the glTF file's own coordinates (x = width, y = up,
-- z = aft) so its numbers can be checked against it, and converted once, at
-- build, to this renderer's X = nose(+)/tail(-), Y = width (+ is the left
-- seen from behind), Z = up(+)/down(-).
--
-- Rendering, per frame: the attitude becomes one rotation matrix (built by
-- passing the three axes through rotatePoint(), the orientation the
-- Alignment page was tuned with), every vertex is rotated and projected
-- once into reused buffers, faces of closed parts that point away from the
-- camera are dropped, the rest are flat-shaded from a fixed light and drawn
-- far-to-near. The camera sits CAMERA_ELEVATION above the model's level
-- plane, so the top of a level car stays visible. No tables are allocated
-- per paint or frame; shaded colours are built once per theme, the mesh once.

if package.loaded["grsuite.app.plane3d"] then
  return package.loaded["grsuite.app.plane3d"]
end

local cos = math.cos
local sin = math.sin
local rad = math.rad
local floor = math.floor
local sqrt = math.sqrt
local max = math.max
local min = math.min
local t_sort = table.sort

local BASE_VIEW_PITCH_R = rad(-90)
local BASE_VIEW_YAW_R = rad(90)
local CAMERA_DIST = 7.0
local CAMERA_NEAR_EPS = 0.25
local CAMERA_ELEVATION_R = rad(18)
local CAM_EC = cos(CAMERA_ELEVATION_R)
local CAM_ES = sin(CAMERA_ELEVATION_R)

local function rotatePoint(x, y, z, pitchR, yawR, rollR)
  local cbp = cos(BASE_VIEW_PITCH_R)
  local sbp = sin(BASE_VIEW_PITCH_R)
  local px = x
  local py = y * cbp - z * sbp
  local pz = y * sbp + z * cbp

  local cby = cos(BASE_VIEW_YAW_R)
  local sby = sin(BASE_VIEW_YAW_R)
  local bx = px * cby + pz * sby
  local by = py
  local bz = -px * sby + pz * cby

  local cz = cos(rollR)
  local sz = sin(rollR)
  local cx = cos(pitchR)
  local sx = sin(pitchR)
  local cy = cos(yawR)
  local sy = sin(yawR)

  local x1 = bx * cz - by * sz
  local y1 = bx * sz + by * cz
  local z1 = bz

  local x2 = x1
  local y2 = y1 * cx - z1 * sx
  local z2 = y1 * sx + z1 * cx

  local x3 = x2 * cy + z2 * sy
  local y3 = y2
  local z3 = -x2 * sy + z2 * cy

  return x3, y3, z3
end

---------------------------------------------------------------------------
-- Mesh
---------------------------------------------------------------------------

-- glTF -> renderer scale; the glTF origin is the car's centre, so it turns
-- about it.
local MODEL_SCALE = 0.70

local MAT_BODY = 1
local MAT_SURFACE = 2
local MAT_WHITE = 3
local MAT_CANOPY = 4
local MAT_PROP = 5
local MAT_TYRE = 7
local MAT_TAIL = 8

local MX, MY, MZ = {}, {}, {}
local vertexCount = 0

-- Faces: up to four vertex indices (FD = 0 for a triangle), a material,
-- and whether the face is a flat plate seen from both sides (the rear wing
-- and lights) or one side of a closed part (culled when facing away).
local FA, FB, FC, FD, FMAT, FTWO = {}, {}, {}, {}, {}, {}
local faceCount = 0

local MODEL_RADIUS = 1

local function vtx(gx, gy, gz)
  vertexCount = vertexCount + 1
  MX[vertexCount] = -gz * MODEL_SCALE
  MY[vertexCount] = gx * MODEL_SCALE
  MZ[vertexCount] = gy * MODEL_SCALE
  return vertexCount
end

local function pushFace(a, b, c, d, mat, twoSided)
  faceCount = faceCount + 1
  FA[faceCount], FB[faceCount], FC[faceCount], FD[faceCount] = a, b, c, d or 0
  FMAT[faceCount] = mat
  FTWO[faceCount] = twoSided
end

local function plate(a, b, c, d, mat)
  pushFace(a, b, c, d, mat, true)
end

-- One face of a closed part. (rx, ry, rz) is a glTF point inside the part
-- next to this face; the winding is flipped if needed so the normal points
-- away from it, which is all the back-face test needs.
local function solid(a, b, c, d, mat, rx, ry, rz)
  local ix = -rz * MODEL_SCALE
  local iy = rx * MODEL_SCALE
  local iz = ry * MODEL_SCALE
  local ux, uy, uz = MX[b] - MX[a], MY[b] - MY[a], MZ[b] - MZ[a]
  local vx, vy, vz = MX[c] - MX[a], MY[c] - MY[a], MZ[c] - MZ[a]
  local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
  local n = d and 4 or 3
  local gx = (MX[a] + MX[b] + MX[c] + (d and MX[d] or 0)) / n - ix
  local gy = (MY[a] + MY[b] + MY[c] + (d and MY[d] or 0)) / n - iy
  local gz = (MZ[a] + MZ[b] + MZ[c] + (d and MZ[d] or 0)) / n - iz
  if nx * gx + ny * gy + nz * gz < 0 then
    if d then a, b, c, d = a, d, c, b else b, c = c, b end
  end
  pushFace(a, b, c, d, mat, false)
end

---------------------------------------------------------------------------
-- The car. Parts are prisms: a side profile of {z, y} points
-- (convex, in order around it) pushed out across the car's width.
---------------------------------------------------------------------------

-- A closed prism: the profile at x = cx - hw and x = cx + hw, its sides in
-- mat and its two end caps in capMat.
local function prism(profile, cx, hw, mat, capMat)
  local n = #profile
  local left, right = {}, {}
  local cz, cy = 0, 0
  for i = 1, n do
    local p = profile[i]
    left[i] = vtx(cx + hw, p[2], p[1])
    right[i] = vtx(cx - hw, p[2], p[1])
    cz, cy = cz + p[1], cy + p[2]
  end
  cz, cy = cz / n, cy / n
  for i = 1, n do
    local j = (i % n) + 1
    solid(left[i], left[j], right[j], right[i], mat, cx, cy, cz)
  end
  for i = 2, n - 1 do
    solid(left[1], left[i], left[i + 1], nil, capMat, cx, cy, cz)
    solid(right[1], right[i], right[i + 1], nil, capMat, cx, cy, cz)
  end
end

local CAR_BODY = {{-3.05, -0.33}, {-3.05, 0.00}, {-2.20, 0.28}, {2.40, 0.38}, {3.00, 0.32}, {3.00, -0.33}}
local CAR_CABIN = {{-1.10, 0.30}, {-0.15, 0.92}, {1.25, 0.92}, {2.05, 0.36}}
local CAR_WHEELS = {{1.50, -1.95}, {-1.50, -1.95}, {1.50, 2.00}, {-1.50, 2.00}}

local function carWheel(k)
  local w = CAR_WHEELS[k]
  local hex = {}
  for i = 1, 6 do
    local a = (i - 1) * math.pi / 3
    hex[i] = {w[2] + 0.62 * cos(a), -0.32 + 0.62 * sin(a)}
  end
  prism(hex, w[1], 0.28, MAT_TYRE, MAT_PROP)
end

-- Building: one stage per service() call, a few thousand instructions each.
local STAGES = {
  function()
    vertexCount, faceCount = 0, 0
    prism(CAR_BODY, 0, 1.42, MAT_BODY, MAT_BODY)
  end,
  function()
    prism(CAR_CABIN, 0, 1.12, MAT_CANOPY, MAT_CANOPY)
    -- Chassis plate under the body
    prism({{-3.0, -0.51}, {-3.0, -0.33}, {3.0, -0.33}, {3.0, -0.51}}, 0, 1.35, MAT_SURFACE, MAT_SURFACE)
  end,
  function() carWheel(1) carWheel(2) end,
  function() carWheel(3) carWheel(4) end,
  function()
    -- Rear wing on two struts
    plate(vtx(-1.35, 0.90, 2.45), vtx(1.35, 0.90, 2.45), vtx(1.35, 0.90, 3.05), vtx(-1.35, 0.90, 3.05), MAT_SURFACE)
    for _, x in ipairs({-0.75, 0.75}) do
      plate(vtx(x, 0.37, 2.61), vtx(x, 0.88, 2.61), vtx(x, 0.88, 2.89), vtx(x, 0.37, 2.89), MAT_SURFACE)
    end
    -- Headlights and tail lights, so the heading reads at a glance
    for _, s in ipairs({-1, 1}) do
      plate(vtx(0.62 * s, -0.05, -3.07), vtx(1.18 * s, -0.05, -3.07), vtx(1.18 * s, 0.09, -3.07), vtx(0.62 * s, 0.09, -3.07), MAT_WHITE)
      plate(vtx(0.62 * s, 0.14, 3.02), vtx(1.18 * s, 0.14, 3.02), vtx(1.18 * s, 0.26, 3.02), vtx(0.62 * s, 0.26, 3.02), MAT_TAIL)
    end
  end,
  function()
    MODEL_RADIUS = 0
    for i = 1, vertexCount do
      MODEL_RADIUS = max(MODEL_RADIUS, sqrt(MX[i] * MX[i] + MY[i] * MY[i] + MZ[i] * MZ[i]))
    end
  end,
}


---------------------------------------------------------------------------
-- Shading
---------------------------------------------------------------------------

-- Light from above, to the left and in front of the screen (view space:
-- x right, y up, z towards the viewer).
local LIGHT_X, LIGHT_Y, LIGHT_Z
do
  local lx, ly, lz = -0.45, 0.75, 0.50
  local l = sqrt(lx * lx + ly * ly + lz * lz)
  LIGHT_X, LIGHT_Y, LIGHT_Z = lx / l, ly / l, lz / l
end
local AMBIENT = 0.45
local DIFFUSE = 0.65
local SHADE_LEVELS = 8

local BASE_COLORS = {
  -- Body in Gripora orange; the car's cabin glass is MAT_CANOPY, its hubs MAT_PROP.
  dark = {
    [MAT_BODY] = {255, 95, 31},
    [MAT_SURFACE] = {78, 80, 88},
    [MAT_WHITE] = {235, 235, 230},
    [MAT_CANOPY] = {70, 85, 105},
    [MAT_PROP] = {160, 160, 165},
    [MAT_TYRE] = {48, 48, 54},
    [MAT_TAIL] = {225, 40, 30},
  },
  light = {
    [MAT_BODY] = {240, 85, 20},
    [MAT_SURFACE] = {45, 45, 52},
    [MAT_WHITE] = {215, 215, 210},
    [MAT_CANOPY] = {45, 55, 70},
    [MAT_PROP] = {120, 120, 125},
    [MAT_TYRE] = {30, 30, 34},
    [MAT_TAIL] = {200, 30, 25},
  },
}

local shadeCache = {}

local function shadeTable(isDark)
  local key = isDark and "dark" or "light"
  local cached = shadeCache[key]
  if cached then return cached end
  cached = {}
  for mat, rgb in pairs(BASE_COLORS[key]) do
    local levels = {}
    for i = 1, SHADE_LEVELS do
      local s = AMBIENT + DIFFUSE * (i - 1) / (SHADE_LEVELS - 1)
      levels[i] = lcd.RGB(min(255, floor(rgb[1] * s)), min(255, floor(rgb[2] * s)), min(255, floor(rgb[3] * s)))
    end
    cached[mat] = levels
  end
  shadeCache[key] = cached
  return cached
end

-- MSP_ATTITUDE degrees -> the angles rotatePoint() takes.
local function toRadians(roll, pitch, yaw)
  return rad(-(pitch or 0)), rad(-(yaw or 0)), rad(-(roll or 0))
end

---------------------------------------------------------------------------
-- Frames. draw() asks for a view and replays the last finished frame (a
-- display list of screen triangles); service() computes the next one in
-- four stages (rotate and project; cull and shade, in two halves; sort and list), so
-- paint only ever replays. Each stage is a few thousand instructions.
---------------------------------------------------------------------------

local buildStage = 1
local ready = false          -- the whole mesh is built
local version = 0            -- bumps when the mesh is built

-- The view draw() last asked for.
local wantX, wantY, wantW, wantH, wantRoll, wantPitch, wantYaw, wantZoom, wantDark

-- The frame being computed.
local prepStage = 0
local pX, pY, pW, pH, pRoll, pPitch, pYaw, pZoom, pDark, pVersion, pScale
local VX, VY, VZ, SX, SY = {}, {}, {}, {}, {}
local faceDepth, faceColor = {}, {}
local drawOrder, drawCount = {}, 0

-- The finished frame: triangles and their colours, and the view it shows.
local LX1, LY1, LX2, LY2, LX3, LY3, LCOL = {}, {}, {}, {}, {}, {}, {}
local listCount = 0
local listX, listY, listW, listH, listRoll, listPitch, listYaw, listZoom, listDark, listVersion

-- The frame's projection centre.
local pcx, pcy = 0, 0

local function fartherFirst(a, b)
  return faceDepth[a] < faceDepth[b]
end

local function listTriangle(x1, y1, x2, y2, x3, y3, color)
  listCount = listCount + 1
  LX1[listCount], LY1[listCount], LX2[listCount], LY2[listCount] = x1, y1, x2, y2
  LX3[listCount], LY3[listCount], LCOL[listCount] = x3, y3, color
end

-- Faces from..to: those that show go on drawOrder (from prepCount on), with
-- their depth and shaded colour. From 1 starts a frame's list.
local prepCount = 0
local function shadeFaces(from, to)
  local shades = shadeTable(pDark)
  local count = (from == 1) and 0 or prepCount
  for i = from, to do
    local a, b, c, d = FA[i], FB[i], FC[i], FD[i]
    if SX[a] and SX[b] and SX[c] and (d == 0 or SX[d]) then
      local x0, y0, z0 = VX[a], VY[a], VZ[a]
      local ux, uy, uz = VX[b] - x0, VY[b] - y0, VZ[b] - z0
      local wx, wy, wz = VX[c] - x0, VY[c] - y0, VZ[c] - z0
      local nx, ny, nz = uy * wz - uz * wy, uz * wx - ux * wz, ux * wy - uy * wx
      local facing = nx * -x0 + ny * -y0 + nz * (CAMERA_DIST - z0)
      local visible = true
      if facing < 0 then
        if FTWO[i] then
          nx, ny, nz = -nx, -ny, -nz
        else
          visible = false
        end
      end
      if visible then
        local len = sqrt(nx * nx + ny * ny + nz * nz)
        local lambert = 0
        if len > 0 then
          lambert = (nx * LIGHT_X + ny * LIGHT_Y + nz * LIGHT_Z) / len
          if lambert < 0 then lambert = 0 end
        end
        count = count + 1
        drawOrder[count] = i
        if d == 0 then
          faceDepth[i] = (z0 + VZ[b] + VZ[c]) / 3
        else
          faceDepth[i] = (z0 + VZ[b] + VZ[c] + VZ[d]) * 0.25
        end
        faceColor[i] = shades[FMAT[i]][floor(lambert * (SHADE_LEVELS - 1) + 0.5) + 1]
      end
    end
  end
  prepCount = count
  if to >= faceCount then
    for i = count + 1, drawCount do drawOrder[i] = nil end
    drawCount = count
  end
end

local PREP = {
  -- Rotate and project every vertex.
  function()
    pX, pY, pW, pH = wantX, wantY, wantW, wantH
    pRoll, pPitch, pYaw, pZoom, pDark, pVersion = wantRoll, wantPitch, wantYaw, wantZoom, wantDark, version
    pScale = max(4, (min(pW, pH) * 0.5 - 4) / MODEL_RADIUS * pZoom)
    pcx, pcy = pX + floor(pW * 0.5), pY + floor(pH * 0.5)
    local pitchR, yawR, rollR = toRadians(pRoll, pPitch, pYaw)
    -- The images of the three model axes, then the camera elevation (a
    -- tilt about the screen's horizontal axis).
    local ax, ay, az = rotatePoint(1, 0, 0, pitchR, yawR, rollR)
    local bx, by, bz = rotatePoint(0, 1, 0, pitchR, yawR, rollR)
    local cx3, cy3, cz3 = rotatePoint(0, 0, 1, pitchR, yawR, rollR)
    ay, az = ay * CAM_EC - az * CAM_ES, ay * CAM_ES + az * CAM_EC
    by, bz = by * CAM_EC - bz * CAM_ES, by * CAM_ES + bz * CAM_EC
    cy3, cz3 = cy3 * CAM_EC - cz3 * CAM_ES, cy3 * CAM_ES + cz3 * CAM_EC
    local cx, cy, scale = pcx, pcy, pScale
    for i = 1, vertexCount do
      local x, y, z = MX[i], MY[i], MZ[i]
      local vx = x * ax + y * bx + z * cx3
      local vy = x * ay + y * by + z * cy3
      local vz = x * az + y * bz + z * cz3
      VX[i], VY[i], VZ[i] = vx, vy, vz
      local denom = CAMERA_DIST - vz
      if denom <= CAMERA_NEAR_EPS then
        SX[i] = false
      else
        local f = CAMERA_DIST / denom * scale
        SX[i] = cx + vx * f
        SY[i] = cy - vy * f
      end
    end
  end,
  -- Drop faces turned away (closed parts), shade the rest: the first half
  -- of the faces here, the rest in the next stage.
  function() shadeFaces(1, floor(faceCount / 2)) end,
  function() shadeFaces(floor(faceCount / 2) + 1, faceCount) end,
  -- Far to near, into the display list.
  function()
    if drawCount > 1 then t_sort(drawOrder, fartherFirst) end
    local old = listCount
    listCount = 0
    for k = 1, drawCount do
      local i = drawOrder[k]
      local a, b, c, d = FA[i], FB[i], FC[i], FD[i]
      local col = faceColor[i]
      listTriangle(SX[a], SY[a], SX[b], SY[b], SX[c], SY[c], col)
      if d ~= 0 then listTriangle(SX[a], SY[a], SX[c], SY[c], SX[d], SY[d], col) end
    end
    for i = listCount + 1, old do
      LX1[i], LY1[i], LX2[i], LY2[i], LX3[i], LY3[i], LCOL[i] = nil, nil, nil, nil, nil, nil, nil
    end
    listX, listY, listW, listH = pX, pY, pW, pH
    listRoll, listPitch, listYaw, listZoom, listDark, listVersion = pRoll, pPitch, pYaw, pZoom, pDark, pVersion
  end,
}

-- The view asked for differs from the finished frame (or the model changed).
local function frameWanted()
  return wantX ~= nil and (listVersion ~= version or listX ~= wantX or listY ~= wantY or listW ~= wantW
    or listH ~= wantH or listRoll ~= wantRoll or listPitch ~= wantPitch or listYaw ~= wantYaw
    or listZoom ~= wantZoom or listDark ~= wantDark)
end

local plane3d = {}

-- Ask for the model at (roll, pitch, yaw) inside the box, and draw the last
-- finished frame if it was made for this box (its attitude may be a step
-- behind: service() catches up). At zoom 1 (the default) the model's radius
-- is fitted to the box's shorter side, so it stays inside at any attitude;
-- perspective can push a tip pointing at the camera slightly further, which
-- the clip catches. A caller whose model only tilts a little can zoom in
-- and let the clip take the rare overflow.
function plane3d.draw(x, y, w, h, roll, pitch, yaw, zoom)
  if w < 8 or h < 8 then return end
  wantX, wantY, wantW, wantH = x, y, w, h
  wantRoll, wantPitch, wantYaw, wantZoom = roll or 0, pitch or 0, yaw or 0, zoom or 1
  wantDark = lcd.darkMode() and true or false
  if listCount == 0 or listX ~= x or listY ~= y or listW ~= w or listH ~= h or listDark ~= wantDark then return end
  local sw, sh = lcd.getWindowSize()
  lcd.setClipping(x, y, w, h)
  local last = nil
  for i = 1, listCount do
    local col = LCOL[i]
    if col ~= last then lcd.color(col); last = col end
    lcd.drawFilledTriangle(LX1[i], LY1[i], LX2[i], LY2[i], LX3[i], LY3[i])
  end
  lcd.setClipping(0, 0, sw, sh)
end

-- The background work, one step per call: a build stage or a frame stage.
-- Call it from wakeup on any page that draws the car.
-- Returns true when it did something; invalidates the screen when a frame
-- is finished.
function plane3d.service()
  if buildStage > 0 then
    STAGES[buildStage]()
    if buildStage < #STAGES then
      buildStage = buildStage + 1
    else
      buildStage, ready = 0, true
      version = version + 1
    end
    return true
  end
  if not ready then return false end
  if prepStage == 0 then
    if not frameWanted() then return false end
    prepStage = 1
  end
  PREP[prepStage]()
  if prepStage < #PREP then
    prepStage = prepStage + 1
  else
    prepStage = 0
    if lcd.invalidate then lcd.invalidate() end
  end
  return true
end

-- Where the nose points on screen, as a unit vector (x right, y up), or
-- nil when it points straight at or away from the viewer.
function plane3d.noseDirection(roll, pitch, yaw)
  local pitchR, yawR, rollR = toRadians(roll, pitch, yaw)
  local nx, ny, nz = rotatePoint(2.2, 0.0, 0.0, pitchR, yawR, rollR)
  local tx, ty, tz = rotatePoint(-2.2, 0.0, 0.0, pitchR, yawR, rollR)
  local nd, td = CAMERA_DIST - nz, CAMERA_DIST - tz
  if nd <= CAMERA_NEAR_EPS or td <= CAMERA_NEAR_EPS then return nil end
  local dx = nx * CAMERA_DIST / nd - tx * CAMERA_DIST / td
  local dy = ny * CAMERA_DIST / nd - ty * CAMERA_DIST / td
  local mag = sqrt(dx * dx + dy * dy)
  if mag <= 0.001 then return nil end
  return dx / mag, dy / mag
end

package.loaded["grsuite.app.plane3d"] = plane3d
return plane3d
