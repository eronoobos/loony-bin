function gadget:GetInfo()
	return {
		name 	= "Loony Bin",
		desc 	= "randomized crater map flavored to taste",
		author 	= "eronoobos",
		date 	= "April 2015",
		license = "WTFPL",
		layer	= 0,
		version = "1",
		enabled = true,
	}
end

-- function localization

local spEcho = Spring.Echo
local spSetHeightMapFunc	= Spring.SetHeightMapFunc
local spSetHeightMap		= Spring.SetHeightMap
local spAddHeightMap		= Spring.AddHeightMap 
local spLevelHeightMap		= Spring.LevelHeightMap
local spSetMetalAmount = Spring.SetMetalAmount
local spCreateFeature = Spring.CreateFeature
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMapOptions = Spring.GetMapOptions

local twicePi = math.pi * 2
local mRandom = math.random
local mRandomSeed = math.randomseed
local mCos = math.cos
local mSin = math.sin
local mSqrt = math.sqrt
local mCeil = math.ceil
local mFloor = math.floor

local tInsert = table.insert

-- local functions

local function tGetRandom(fromTable)
  return fromTable[mRandom(1, #fromTable)]
end

local function CirclePos(cx, cy, dist, angle)
  angle = angle or mRandom() * twicePi
  local x = cx + dist * mCos(angle)
  local y = cy + dist * mSin(angle)
  return x, y
end


----- SPRING SYNCED ------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-------------------------------------------------------

local Loony = include "LoonyModule/loony.lua"
local myWorld
local heightRenderComplete, metalRenderComplete
local metalSpots = {}
local waterlevel = "dry"
local thisGameID = 0

local blastRayDecals = {
	{image = 'maps/blastrays1.png', innerWidth = 37, width = 256 },
	{image = 'maps/blastrays2.png', innerWidth = 20, width = 256 },
	{image = 'maps/blastrays3.png', innerWidth = 27, width = 256 },
}
for i, d in pairs(blastRayDecals) do
	blastRayDecals[i].widthRatio = d.width / d.innerWidth
end

function gadget:GameID(gameID)
	thisGameID = gameID
end

function gadget:Initialize()
	spEcho("initializing loony bin gadget...")
	-- default config values
	local randomseed = 1
	local minDiameter, maxDiameter = 5, 400
	local metersPerElmo = 8
	local gravity = (Game.gravity / 130) * 9.8
	local density = (Game.mapHardness / 100) * 2500
	local mirror = "rotational"
	local metalTarget = 24
	local geothermalTarget = 4
	local showerRamps = false
	-- get map options
	local options = spGetMapOptions()
	if options ~= nil then
		if options.randomseed ~= nil then
			randomseed = tonumber(options.randomseed)
		end
		if options.waterlevel ~= nil then
			waterlevel = options.waterlevel
		end
		if options.size == "large" then
			minDiameter, maxDiameter = 25, 800
		elseif options.size == "medium" then
			minDiameter, maxDiameter = 5, 400
		elseif options.size == "small" then
			minDiameter, maxDiameter = 1, 200
		end
		mirror = options.mirror or "rotational"
		if options.metals ~= nil then
			metalTarget = tonumber(options.metals)
		end
		if options.geothermals ~= nil then
			geothermalTarget = tonumber(options.geothermals)
		end
		if options.ramps ~= nil then
			showerRamps = tonumber(options.ramps) == 1
		end
	end
	-- get team start locations
	local starts = {}
	if Game.startPosType ~= 2 then
		for i, teamID in pairs(Spring.GetTeamList()) do
			if teamID ~= Spring.GetGaiaTeamID() then
				local x, y, z = Spring.GetTeamStartPosition(teamID)
				tInsert(starts, {x=x, z=z})
			end
		end
	end
	-- create crater map
	mRandomSeed(randomseed)
	myWorld = Loony.World(Game.mapX, Game.mapY, metersPerElmo, gravity, density, mirror, metalTarget, geothermalTarget, showerRamps)
	myWorld.blastRayCraterNumber = mRandom(1, #blastRayDecals)
	local number = mCeil(metalTarget / 2)
	local try = 0
	local spots = {}
	while #spots < metalTarget and try < metalTarget do
		myWorld:Clear()
		myWorld:MeteorShower(number, minDiameter, maxDiameter)
		for i, start in pairs(starts) do
			-- sx, sz, diameterImpactor, velocityImpactKm, angleImpact, densityImpactor, age, metal, geothermal, seedSeed, ramps, mirrorMeteor, noMirror
			local m = myWorld:AddMeteor(start.x, start.z, 120, nil, nil, nil, nil, 3, false, nil, nil, nil, true)
			m.metalGeothermalRampSet = true
		end
		myWorld:SetMetalGeothermalRamp()
		myWorld:ResetMeteorAges()
		number = number + 1
		try = try + 1
		spots = myWorld:GetMetalSpots()
	end
	-- render crater map
	myWorld:RenderHeight()
	myWorld:RenderMetal()
	-- i have to change the height map here and not through GameFrame so that it happens before pathfinding & team LOS initialization
	local i = 1
	while not heightRenderComplete or not metalRenderComplete do
		myWorld:RendererFrame(i)
	end
	local featureslist = myWorld:GetFeaturelist() -- get geovents from Loony
	-- create features on map
	for i,fDef in pairs(featureslist) do
		local stop = false
		if fDef.name == "GeoVent" then
			-- don't put geovents underwater
			local y = spGetGroundHeight(fDef.x, fDef.z)
			if y < 0 then stop = true end
		end
		if not stop then
			local flagID = spCreateFeature(fDef.name, fDef.x, spGetGroundHeight(fDef.x,fDef.z)+5, fDef.z, fDef.rot)
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg ~= "Ground Decal Widget Loaded" then return end
	SendToUnsynced('ClearGroundDecals')
	-- add metal spot decals
	for i, spot in pairs(metalSpots) do
		SendToUnsynced('GroundDecal', "maps/geothermal.png", spot.x, spot.z, myWorld.metalSpotRadius*8, nil, nil, 0.5, 0, 0, 0.25)
	end
	-- add geotermal decals
	for i, m in pairs(myWorld.meteors) do
		local width = mSqrt(((myWorld.geothermalRadius * 2)^2) * 2) * 2
		if m.geothermal then
			SendToUnsynced('GroundDecal', 'maps/geothermal.png', m.sx, m.sz, width, nil, nil, 0, 0, 0, 1)
		end
	end
	-- add blastray decals to at most three tiny craters
	local n = 0
	local bri = 1
	for i = #myWorld.meteors, 1, -1 do
		local m = myWorld.meteors[i]
		if m.impact.craterRadius < 50 then
			local d = blastRayDecals[bri]
			local filename = d.image
			local width = m.impact.craterRadius * 2 * d.widthRatio
			local g = mRandom() * 0.33
			local r = mRandom() * (0.33 - g)
			SendToUnsynced('GroundDecal', filename, m.sx, m.sz, width, nil, nil, r, g, 1, 0.2, "alpha_add")
			bri = bri + 1
			if bri > #blastRayDecals then bri = 1 end
			n = n + 1
			if n == 3 then break end
		end
	end
end

-- Loony callins

function Loony.CompleteRenderer(renderer)
	local mapRuler = renderer.mapRuler
	if renderer.renderType == "Height" then
		-- determine base level
		local baselevel = 200 - renderer.heightBuf.minHeight
		if waterlevel == "dry" then
			baselevel = 200 - renderer.heightBuf.minHeight
		elseif waterlevel == "pools" then
			baselevel = (0-renderer.heightBuf.minHeight) * 0.5
		elseif waterlevel == "lakes" then
			baselevel = renderer.heightBuf.maxHeight * 0.25
		elseif waterlevel == "ocean" then
			baselevel = 0 - (renderer.heightBuf.maxHeight * 0.25)
		end
		-- write height map array to spring
		spSetHeightMapFunc(function()
			for x, yy in pairs(renderer.data) do
				for y, height in pairs(yy) do
					local sx, sz = mapRuler:XYtoXZ(x, y)
					spSetHeightMap(sx, sz, baselevel+height)
				end
			end
		end)
		heightRenderComplete = true
	elseif renderer.renderType == "Metal" then
		-- write metal map array to spring
		for x, yy in pairs(renderer.data) do
			for y, mAmount in pairs(yy) do
				spSetMetalAmount(x, y, mAmount)
			end
		end
		metalSpots = renderer.metalSpots
		metalRenderComplete = true
	end
end

--------------------------------------------------------
else
----- SPRING UNSYNCED ------------------------------------------

local function GroundDecalToLuaUI(_, filename, x, z, width, height, rotation, r, g, b, a, blendMode)
  Script.LuaUI.ReceiveGroundDecal(filename, x, z, width, height, rotation, r, g, b, a, blendMode)
end

local function ClearGroundDecalsToLuaUI(_)
  Script.LuaUI.ClearGroundDecals()
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction('GroundDecal', GroundDecalToLuaUI)
	gadgetHandler:AddSyncAction('ClearGroundDecals', ClearGroundDecalsToLuaUI)
end

end
--------------------------------------------------------
