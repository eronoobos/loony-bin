--------------------------------------------------------------------------------------------------------
-- Start location settings
--------------------------------------------------------------------------------------------------------

--[[

local Loony = VFS.Include "LoonyModule/loony.lua"

local mFloor = math.floor
local mRandomSeed = math.randomseed
Spring.Echo(math, math.floor, math.abs, math.random, math.randomseed)
local tInsert = table.insert
local spGetMapOptions = Spring.GetMapOptions

local Game = {
	gravity = mapinfo.gravity,
	mapHardness = mapinfo.maphardness,
	mapX = 12,
	mapY = 12,
	mapSizeX = 12 * 512,
	mapSizeZ = 12 * 512,
}

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

-- create crater map
mRandomSeed(randomseed)
local myWorld = Loony.World(Game.mapX, Game.mapY, metersPerElmo, gravity, density, mirror, metalTarget, geothermalTarget, showerRamps)
-- myWorld.blastRayCraterNumber = mRandom(1, #blastRayDecals)
local number = mCeil(metalTarget / 2)
local try = 0
local spots = {}
while #spots < metalTarget and try < metalTarget do
	myWorld:Clear()
	myWorld:MeteorShower(number, minDiameter, maxDiameter)
	number = number + 1
	try = try + 1
	spots = myWorld:GetMetalSpots()
end

-- find start locations
local starts = {}
for n = 3, 1, -1 do
	for i, m in pairs(myWorld.meteors) do
		if #m.impact.metalSpots == n and not m.geothermal then
			tInsert(starts, {x = m.sx, z = m.sz})
		end
	end
end

-- create teams table
local teams = {}
for i = 0, 7 do
	local start = starts[i+1] or { x = mFloor(Game.mapSizeX/(i+1)), z = mFloor(Game.mapSizeZ/(i+1)) }
	teams[i] = { startPos = start }
end

return teams

]]--