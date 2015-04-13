function widget:GetInfo()
  return {
    name      = "Ground Decals",
    desc      = "Draws decals on the ground where specified by unsynced.",
    author    = "zoggop",
    date      = "April 2015",
    license   = "WTFPL",
    layer     = 5,
    enabled   = true  --  loaded by default?
  }
end

-- localization

local spEcho = Spring.Echo

local mRandom = math.random
local tInsert = table.insert

-- Variables
local displayList = 0
local decals = {}

-- local functions

local function DrawDecals()
	-- Switch to texture matrix mode
	gl.MatrixMode(GL.TEXTURE)

    gl.PolygonOffset(-25, -2)
    gl.Culling(GL.BACK)
    gl.DepthTest(true)
	gl.Color(1, 1, 1) -- fix color from other widgets
	for filename, ds in pairs(decals) do
		gl.Texture(filename)
		for i, d in pairs(ds) do
			if d.blendMode then gl.Blending(d.blendMode) end
			gl.PushMatrix()
			gl.Translate(0.5, 0.5, 0)
			gl.Rotate( d.rotation, 0, 0, 1)
			gl.DrawGroundQuad( d.x-d.hw, d.z-d.hh, d.x+d.hw, d.z+d.hh, false, -0.5,-0.5, 0.5,0.5)
			gl.PopMatrix()
			if d.blendMode then gl.Blending(false) end
		end
    	gl.Texture(false)
	end
    gl.DepthTest(false)
    gl.Culling(false)
    gl.PolygonOffset(false)

	-- Restore Modelview matrix
	gl.MatrixMode(GL.MODELVIEW)
end

local function ReceiveGroundDecal(filename, x, z, width, height, rotation, blendMode)
	height = height or width
	rotation = rotation or mRandom(0, 360)
	decals[filename] = decals[filename] or {}
	local decal = {x = x, z = z, width = width, height = height, hw = width / 2, hh = height / 2, rotation = rotation, blendMode = blendMode}
	tInsert(decals[filename], decal)
	displayList = gl.CreateList(DrawDecals)
	spEcho("got ground decal", filename, x, z, width, height)
end

local function ClearGroundDecals()
	decals = {}
	displayList = gl.CreateList(DrawDecals)
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