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


----- SPRING SYNCED ------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-------------------------------------------------------

local Loony = include "LoonyModule/loony.lua"
local myWorld

function gadget:Initialize()
	myWorld = Loony.World(Game.mapX, Game.mapY, 4, 100)
	myWorld.mirror = "rotational"
	myWorld:MeteorShower(10)
	myWorld:RenderHeight()
end

function gadget:GameFrame(frame)
	myWorld:RendererFrame(frame)
end

-- Loony callins

function Loony.CompleteRenderer(renderer)
	if renderer.renderType == "Height" then
		-- write height map array to spring map when finished rendering
		local mapRuler = renderer.mapRuler
		local baselevel = renderer.world.baselevel
		spSetHeightMapFunc(function()
			for x, yy in pairs(renderer.data) do
				for y, height in pairs(yy) do
					local sx, sz = mapRuler:XYtoXZ(x, y)
					spSetHeightMap(sx, sz, baselevel+height)
				end
			end
		end)
	end
end

--------------------------------------------------------
end