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



----- SPRING SYNCED ------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-------------------------------------------------------

local Loony = include "LoonyModule/loony.lua"
local myWorld
local heightRenderComplete, metalRenderComplete

function gadget:Initialize()
	myWorld = Loony.World(Game.mapX, Game.mapY, 5, 100)
	myWorld.mirror = "rotational"
	myWorld:MeteorShower(10)
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
		-- write height map array to spring map when finished rendering
		local baselevel = renderer.world.baselevel
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