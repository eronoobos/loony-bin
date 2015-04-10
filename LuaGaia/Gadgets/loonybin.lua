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



----- SPRING SYNCED ------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-------------------------------------------------------

local Loony = include "LoonyModule/loony.lua"
local myWorld
local heightRenderComplete, metalRenderComplete
local waterlevel = "dry"

function gadget:Initialize()
	local number = 10
	local minDiameter, maxDiameter = 15, 1500
	local metersPerElmo = 8
	local gravity = (Game.gravity / 130) * 9.8
	local density = (Game.mapHardness / 100) * 2500
	local mirror = "rotational"
	local metalTarget = 20
	local geothermalTarget = 4
	local showerRamps = false
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
	myWorld = Loony.World(Game.mapX, Game.mapY, metersPerElmo, gravity, density, mirror, metalTarget, geothermalTarget, showerRamps)
	myWorld:MeteorShower(number, minDiameter, maxDiameter)
	myWorld:RenderHeight()
	myWorld:RenderMetal()
	-- i have to change the height map here and not through GameFrame so that it happens before pathfinding & team LOS initialization
	local i = 1
	while not heightRenderComplete or not metalRenderComplete do
		myWorld:RendererFrame(i)
	end
	local featureslist = myWorld:GetFeaturelist()
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
		-- write height map array to spring map
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
		for x, yy in pairs(renderer.data) do
			for y, mAmount in pairs(yy) do
				spSetMetalAmount(x, y, mAmount)
			end
		end
		metalRenderComplete = true
	end
end

--------------------------------------------------------
end