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
local mCos = math.cos
local mSin = math.sin
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
local sentDecals = false
local myWorld
local heightRenderComplete, metalRenderComplete
local metalSpots = {}
local metalSpotFeatureNames = {
	-- "GreyRock6",
	-- "brock_2",
	-- "brock_1",
	-- "agorm_rock4",
	-- "agorm_rock5",
	-- "pdrock4",
	"crystalmex",
}
local metalSpotFeatureRadius = 0 -- 55 -- how far away from metal spot to place features
local metalSpotFeatureNumberMin = 1 -- 3 -- how many features per spot minimum
local metalSpotFeatureNumberMax = 1 -- 5 -- how many features per spot maximum
local waterlevel = "dry"

function gadget:Initialize()
	-- default config values
	local number = 10
	local minDiameter, maxDiameter = 15, 1500
	local metersPerElmo = 8
	local gravity = (Game.gravity / 130) * 9.8
	local density = (Game.mapHardness / 100) * 2500
	local mirror = "rotational"
	local metalTarget = 20
	local geothermalTarget = 4
	local showerRamps = false
	-- get map options
	local options = spGetMapOptions()
	if options ~= nil then
		if options.number ~= nil then
			number = tonumber(options.number)
		end
		if options.waterlevel ~= nil then
			waterlevel = options.waterlevel
		end
		if options.size == "large" then
			minDiameter, maxDiameter = 50, 1200
		elseif options.size == "medium" then
			minDiameter, maxDiameter = 15, 1200
		elseif options.size == "small" then
			minDiameter, maxDiameter = 1, 100
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
	-- render crater map through Loony
	myWorld = Loony.World(Game.mapX, Game.mapY, metersPerElmo, gravity, density, mirror, metalTarget, geothermalTarget, showerRamps)
	myWorld:MeteorShower(number, minDiameter, maxDiameter)
	myWorld:RenderHeight()
	myWorld:RenderMetal()
	-- i have to change the height map here and not through GameFrame so that it happens before pathfinding & team LOS initialization
	local i = 1
	while not heightRenderComplete or not metalRenderComplete do
		myWorld:RendererFrame(i)
	end
	local featureslist = myWorld:GetFeaturelist() -- get geovents from Loony
	-- add metal spot features
	--[[
	local ni = 1
	for i, spot in pairs(metalSpots) do
		for j = 1, mRandom(metalSpotFeatureNumberMin, metalSpotFeatureNumberMax) do
			local x, z = CirclePos( spot.x, spot.z, metalSpotFeatureRadius * (1+(mRandom()*0.1)) )
			local fDef = { x = x, z = z, name = metalSpotFeatureNames[ni], rot = mRandom(1, 359) }
			tInsert(featureslist, fDef)
			ni = ni + 1
			if ni > #metalSpotFeatureNames then ni = 1 end
		end
	end
	]]--
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
	if sentDecals then return end
	if msg ~= "Ground Decal Widget Loaded" then return end
	-- for i, spot in pairs(metalSpots) do
	-- 	SendToUnsynced('GroundDecal', "maps/mex.png", spot.x, spot.z, myWorld.metalSpotRadius*2)
	-- end
	sentDecals = true
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

local function GroundDecalToLuaUI(_, filename, x, z, width, height, rotation, blendMode)
  Script.LuaUI.ReceiveGroundDecal(filename, x, z, width, height, rotation, blendMode)
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction('GroundDecal', GroundDecalToLuaUI)
end

end
--------------------------------------------------------
