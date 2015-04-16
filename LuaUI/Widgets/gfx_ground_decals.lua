function widget:GetInfo()
  return {
    name      = "Ground Decals",
    desc      = "Draws decals on the ground where specified by unsynced.",
    author    = "eronoobos",
    date      = "April 2015",
    license   = "WTFPL",
    layer     = 5,
    enabled   = true  --  loaded by default?
  }
end

-- localization

local gMapSizeX, gMapSizeZ = Game.mapSizeX, Game.mapSizeZ

local spEcho = Spring.Echo

local mRandom = math.random

local tInsert = table.insert

-- Variables
local displayList = 0
local decals = {}

-- local functions

local function QuadCoordinates(x, z, hw, hh)
	-- determine groundquad rectangle coordinates
	-- clamped within map edges, so that decals do not become squished at the edges
	local x1, rx1 = x-hw, -0.5
	if x1 < 0 then
		rx1 = ((hw + x1) / hw) * -0.5
		x1 = 0
	end
	local z1, rz1 = z-hw, -0.5
	if z1 < 0 then
		rz1 = ((hh + z1) / hh) * -0.5
		z1 = 0
	end
	local x2, rx2 = x+hw, 0.5
	if x2 > gMapSizeX then
		local d = hw - (x2 - gMapSizeX)
		rx2 = (d / hw) * 0.5
		x2 = gMapSizeX
	end
	local z2, rz2 = z+hh, 0.5
	if z2 > gMapSizeZ then
		local d = hh - (z2 - gMapSizeZ)
		rz2 = (d / hh) * 0.5
		z2 = gMapSizeZ
	end
	return x1, z1, x2, z2, rx1, rz1, rx2, rz2
end

local function DrawDecals()
	gl.MatrixMode(GL.TEXTURE) -- Switch to texture matrix mode

    gl.PolygonOffset(-25, -2)
    gl.Culling(GL.BACK)
    gl.DepthTest(true)
	for filename, dcls in pairs(decals) do
		gl.Texture(filename)
		for i, d in pairs(dcls) do
			gl.Color(d.r, d.g, d.b, d.a)
			if d.blendMode then gl.Blending(d.blendMode) end
			gl.PushMatrix()
			gl.Translate(0.5, 0.5, 0)
			gl.Rotate( d.rotation, 0, 0, 1)
			gl.DrawGroundQuad(d.x1, d.z1, d.x2, d.z2, false, d.rx1, d.rz1, d.rx2, d.rz2)
			gl.PopMatrix()
			if d.blendMode then gl.Blending('alpha') end
		end
    	gl.Texture(false)
	end
	gl.Color(1, 1, 1, 1)
    gl.DepthTest(false)
    gl.Culling(false)
    gl.PolygonOffset(false)

	gl.MatrixMode(GL.MODELVIEW) -- Restore Modelview matrix
end

local function ReceiveGroundDecal(filename, x, z, width, height, rotation, r, g, b, a, blendMode)
	height = height or width
	rotation = rotation or mRandom(0, 360)
	decals[filename] = decals[filename] or {}
	local x1, z1, x2, z2, rx1, rz1, rx2, rz2 = QuadCoordinates(x, z, width/2, height/2)
	r, g, b, a = r or 1, g or 1, b or 1, a or 1
	local decal = { x1=x1, z1=z1, x2=x2, z2=z2, rx1=rx1, rz1=rz1, rx2=rx2, rz2=rz2, rotation=rotation, r=r, g=g, b=b, a=a, blendMode=blendMode }
	tInsert(decals[filename], decal)
	displayList = gl.CreateList(DrawDecals)
	-- spEcho("got ground decal", filename, x, z, width, height)
end

local function ClearGroundDecals()
	decals = {}
	displayList = 0
end

-- callins

function widget:Initialize()
	widgetHandler:RegisterGlobal("ReceiveGroundDecal", ReceiveGroundDecal)
	widgetHandler:RegisterGlobal("ClearGroundDecals", ClearGroundDecals)
	local msg = "Ground Decal Widget Loaded"
	Spring.SendLuaGaiaMsg(msg)
	Spring.SendLuaRulesMsg(msg)
end

function widget:DrawWorldPreUnit()
	gl.CallList(displayList)
end