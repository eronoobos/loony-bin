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
local spSetSmoothMeshFunc = Spring.SetSmoothMeshFunc
local spSetSmoothMesh = Spring.SetSmoothMesh
local spSetMetalAmount = Spring.SetMetalAmount
local spCreateFeature = Spring.CreateFeature
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMapOptions = Spring.GetMapOptions

local pi = math.pi
local twicePi = math.pi * 2
local mRandom = math.random
local mRandomSeed = math.randomseed
local mCos = math.cos
local mSin = math.sin
local mAtan2 = math.atan2
local mSqrt = math.sqrt
local mCeil = math.ceil
local mFloor = math.floor
local mMax = math.max
local mMin = math.min
local mAbs = math.abs

local tInsert = table.insert
local tRemove = table.remove

local gMapSizeX = Game.mapSizeX
local gMapSizeZ = Game.mapSizeZ
local centerX = Game.mapSizeX / 2
local centerZ = Game.mapSizeZ / 2
local smallestMapDimension = mMin(Game.mapSizeX, Game.mapSizeZ)
local halfSmallestMapDimension = smallestMapDimension / 2

-- local functions

local function tGetRandom(fromTable)
  return fromTable[mRandom(1, #fromTable)]
end

local function tRemoveRandom(fromTable)
	if not fromTable or #fromTable == 0 then return end
	return tRemove(fromTable, mRandom(1, #fromTable))
end

local function AngleAdd(angle1, angle2)
  return (angle1 + angle2) % twicePi
end

local function AngleXYXY(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return mAtan2(dy, dx), dx, dy
end

local function AngleDist(angle1, angle2)
  return mAbs((angle1 + pi -  angle2) % twicePi - pi)
end

local function CirclePos(cx, cy, dist, angle)
  angle = angle or mRandom() * twicePi
  local x = cx + dist * mCos(angle)
  local y = cy + dist * mSin(angle)
  return x, y
end

local function WithinBox(x, z, box)
	-- spEcho(box[1], box[2], box[3], box[4], "within?", x, z)
	if #box == 2 then
		local angle, dx, dy = AngleXYXY(centerX, centerZ, x, z)
		return AngleDist(angle, box[1]) < box[2]
	elseif #box == 4 then
		return x > box[1] and z > box[2] and x < box[3] and z < box[4]
	end
end

local function FeedWatchDog()
	if Spring.ClearWatchDogTimer then
		Spring.ClearWatchDogTimer()
	end
end

----- SPRING SYNCED ------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-------------------------------------------------------

local Loony = include "LoonyModule/loony.lua"
local myWorld
local heightRenderComplete, metalRenderComplete
local metalSpots = {}
local thisGameID = 0
local groundDecalWidgetLoaded
local crazyeyes = {}

local precalcStartBoxes = {
	-- [number of allyTeams] = {
		--    {xmin, zmin, xmax, zmax}
		-- or {angle, angledistance}
	-- }
	[2] = {
		{0, 0, 0.5, 1},
		{0.5, 0, 1, 1}
	},
	-- starts further in the corner so that they don't end up right next to each other
	[-2] = {
		{0, 0, 0.25, 1},
		{0.75, 0, 1, 1}
	},
	[3] = {}, -- will be replaced by radial angle start box
	[4] = {
		{0, 0, 0.5, 0.5},
		{0.5, 0.5, 1, 1},
		{0, 0.5, 0.5, 1},
		{0.5, 0, 1, 0.5}
	},
	-- starts further in the corner so that they don't end up right next to each other
	[-4] = {
		{0, 0, 0.25, 0.25},
		{0.75, 0.75, 1, 1},
		{0, 0.75, 0.25, 1},
		{0.75, 0, 1, 0.25}
	},
	[5] = {}, -- will be replaced by radial angle start box
	[6] = {}, -- will be replaced by radial angle start box
	[7] = {}, -- will be replaced by radial angle start box
	[8] = {}, -- will be replaced by radial angle start box
}
for num, boxes in pairs(precalcStartBoxes) do
	for i, box in pairs(boxes) do
		if #box == 4 then
			for ii, coord in pairs(box) do
				if i == 1 or i == 2 then
					coord = coord * Game.mapSizeX
				else
					coord = coord * Game.mapSizeZ
				end
				precalcStartBoxes[num][i][ii] = coord
			end
		end
	end
	if #boxes == 0 then
		local newBoxes = {}
		local inc = twicePi/num
		for a = 1, num do
			local box = { inc*(a-1), inc }
			newBoxes[a] = box
		end
		precalcStartBoxes[num] = newBoxes
	end
end

local rockFeatureNames = {
	"GreyRock6",
	"brock_2",
	"brock_1",
	"agorm_rock4",
	"agorm_rock5",
	"pdrock4",
}

local blastRayDecals = {
	{image = 'maps/blastrays1.png', innerWidth = 37, width = 256 },
	{image = 'maps/blastrays2.png', innerWidth = 20, width = 256 },
	{image = 'maps/blastrays3.png', innerWidth = 27, width = 256 },
}
for i, d in pairs(blastRayDecals) do
	blastRayDecals[i].widthRatio = d.width / d.innerWidth
end

local function GenerateMap(randomseed)
	spEcho('generating loony bin map...')

	-- default config values
	randomseed = randomseed or 1
	local minDiameter, maxDiameter = 5, 400
	local metersPerElmo = 8
	local gravity = (Game.gravity / 130) * 9.8
	local density = (Game.mapHardness / 100) * 2500
	local showerRamps = false
	local startSize = 150

	-- get map options
	local options = spGetMapOptions()
	if options ~= nil then
		if options.size == "large" then
			minDiameter, maxDiameter = 25, 700
		elseif options.size == "medium" then
			minDiameter, maxDiameter = 5, 400
		elseif options.size == "small" then
			minDiameter, maxDiameter = 1, 200
		end
		if options.ramps ~= nil then
			showerRamps = tonumber(options.ramps) == 1
		end
	end
	spEcho("randomseed " .. randomseed, "maxDiameter " .. maxDiameter, "showerRamps " .. tostring(showerRamps))
	
	-- get number of allyTeams
	local gaiaTeamInfo = { Spring.GetTeamInfo(Spring.GetGaiaTeamID()) }
	local gaiaAllyTeamID = gaiaTeamInfo[6]
	local allyTeams = {}
	local allyTeamsByID = {}
	for i, allyTeamID in pairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= gaiaAllyTeamID then
			tInsert(allyTeams, allyTeamID)
			allyTeamsByID[allyTeamID] = i
		end
	end
	local mirror = false
	if #allyTeams >= 2 and #allyTeams <= 8 then
		mirror = true
	end

	-- get startboxes
	local startBoxes = {}
	for i, allyTeamID in pairs(allyTeams) do
		if Game.startPosType == 2 then
			-- choosen in-game, no need for picking locations for them
			-- startBoxes[allyTeamID] = { Spring.GetAllyTeamStartBox(allyTeamID) }
		elseif mirror then
			startBoxes[allyTeamID] = precalcStartBoxes[#allyTeams][i]
		else
			startBoxes[allyTeamID] = {0, 0, Game.mapSizeX, Game.mapSizeZ}
		end
		spEcho("allyTeamID", allyTeamID, "startbox", startBoxes[allyTeamID][1], startBoxes[allyTeamID][2], startBoxes[allyTeamID][3], startBoxes[allyTeamID][4])
	end
	local firstStartBox = startBoxes[allyTeams[1]] or {0, 0, Game.mapSizeX, Game.mapSizeZ}
	if precalcStartBoxes[-#allyTeams] then
		firstStartBox = precalcStartBoxes[-#allyTeams][1]
	end

	-- get number of teams & sort into allyTeams
	local teamsByAlly = {}
	local teamCount = 0
	for i, teamID in pairs(Spring.GetTeamList()) do
		if teamID ~= Spring.GetGaiaTeamID() then
			local teamInfo = { Spring.GetTeamInfo(teamID) }
			local allyTeamID = teamInfo[6]
			teamsByAlly[allyTeamID] = teamsByAlly[allyTeamID] or {}
			tInsert(teamsByAlly[allyTeamID], teamID)
			teamCount = teamCount + 1
		end
	end
	local maxTeamsPerAlly = 0
	for allyTeamID, teams in pairs(teamsByAlly) do
		if #teams > maxTeamsPerAlly then
			maxTeamsPerAlly = #teams
		end
	end
	local startMeteorNumber = teamCount
	if mirror then startMeteorNumber = maxTeamsPerAlly end
	spEcho(teamCount .. " teamCount", maxTeamsPerAlly .. " maxTeamsPerAlly", startMeteorNumber .. " startMeteorNumber")

	local metalTarget = (teamCount * 6) + (#allyTeams * 3)
	local geothermalTarget = teamCount
	local metalSpotMaxPerCrater = 3 -- anything higher than this leads to funky assymetry of metal spots
	spEcho("metalTarget " .. metalTarget, "geothermalTarget " .. geothermalTarget, "metalSpotMaxPerCrater " .. metalSpotMaxPerCrater)
	local unMirroredMetalTarget = metalTarget
	if mirror then unMirroredMetalTarget = unMirroredMetalTarget / #allyTeams end

	-- create crater map
	mRandomSeed(randomseed)
	myWorld = Loony.World(Game.mapX, Game.mapY, metersPerElmo, gravity, density, "none", metalTarget, geothermalTarget, showerRamps)
	myWorld.metalSpotMaxPerCrater = metalSpotMaxPerCrater
	myWorld.generateBlastNoise = false
	myWorld.underlyingPerlin = true
	local testM = myWorld:AddMeteor(1, 1, startSize) -- test start crater radius
	local startRadius = testM.impact.craterRadius
	local fromEdges = startRadius * 1.25
	testM:Delete()
	local number = 12
	-- local number = mMax(17, teamCount * 8)
	-- if mirror then number = number / #allyTeams end
	-- if #startBoxes[1] == 2 then number = number * 2 end -- rotational symmetry is more limited in where metal & geos can occur
	local try = 0
	local spots = {}
	local highestMetal = 0
	local highestMeteors = {}
	while #spots < metalTarget and try < 20 do
		FeedWatchDog()
		myWorld:Clear()
		myWorld:MeteorShower(number, minDiameter, maxDiameter)
		-- add start meteors
		for n = 1, startMeteorNumber do
			local x, z
			if #firstStartBox == 2 then
				local angle = AngleAdd(firstStartBox[1], firstStartBox[2]/2)
				x, z = CirclePos(centerX, centerZ, halfSmallestMapDimension-(fromEdges*2), angle)
			elseif #firstStartBox == 4 then
				x = mRandom(firstStartBox[1]+fromEdges, firstStartBox[3]-fromEdges)
				z = mRandom(firstStartBox[2]+fromEdges, firstStartBox[4]-fromEdges)
			end
			if x then myWorld:AddStartMeteor(x, z, startSize) end
		end
		if mirror then
			if #allyTeams == 2 then
				myWorld:MirrorAll(3)
			elseif #allyTeams == 4 then
				myWorld:MirrorAll(1, 2, 3)
			elseif #allyTeams == 3 or (#allyTeams >= 5 and #allyTeams <= 8) then
				local mirrorIndices = {}
				local inc = 360/#allyTeams
				for a = 1, #allyTeams-1 do
					tInsert(mirrorIndices, -inc*a)
				end
				myWorld:MirrorAll(mirrorIndices)
			end
			myWorld:SetMetalGeothermalRampPostMirrorAll()
			myWorld:ResetMeteorAges()
		else
			myWorld:SetMetalGeothermalRamp()
			myWorld:ResetMeteorAges()
		end
		spots = myWorld:GetMetalSpots()
		spEcho("try " .. try, "number " .. number, "maxDiameter " .. maxDiameter, "spots " .. #spots)
		if #spots > highestMetal then
			highestMetal = #spots
			highestMeteors = myWorld.meteors
		end
		number = number + 1
		try = try + 1
		maxDiameter = maxDiameter + 5
	end
	spEcho("found crater map in " .. try-1 .. " tries")
	if #spots < metalTarget and highestMetal > #spots then
		-- use the map with the most metal if target not met
		myWorld.meteors = highestMeteors
	end
	spEcho(#myWorld.meteors .. " craters", maxDiameter-5 .. " maxDiameter", #spots .. " metal spots (target: " .. metalTarget .. ")")

	-- give team start locations to luarules gadget
	for i, m in pairs(myWorld.meteors) do
		if m.start then
			local tID
			for allyTeamID, box in pairs(startBoxes) do
				if teamsByAlly[allyTeamID] and #teamsByAlly[allyTeamID] > 0 and WithinBox(m.sx, m.sz, box) then
					tID = tRemoveRandom(teamsByAlly[allyTeamID])
					if tID then break end
				end
			end
			if tID then
				Spring.SendLuaRulesMsg('DynamicStartPositions set ' .. tID .. ' ' .. m.sx .. ' ' .. m.sz)
			end
		end
	end

	-- render crater map
	myWorld:RenderHeight()
	myWorld:RenderMetal()
	-- i have to change the height map here and not through GameFrame so that it happens before pathfinding & team LOS initialization
	local i = 1
	while not heightRenderComplete or not metalRenderComplete do
		FeedWatchDog()
		myWorld:RendererFrame(i)
	end

	local featureslist = myWorld:GetFeaturelist() -- get geovents

	-- add reclaimable rocks to empty craters
	local rockCount = 0
	local maxRocks = mFloor(#myWorld.meteors * 0.2)
	local rfi = mRandom(1, #rockFeatureNames)
	for i = #myWorld.meteors, 1, -1 do
		local m = myWorld.meteors[i]
		if not m.geothermal and #m.impact.metalSpots == 0 then
			local offsetX = mFloor( (m.impact.craterRadius/6) - (mRandom() * (m.impact.craterRadius/3)) )
			local offsetZ = mFloor( (m.impact.craterRadius/6) - (mRandom() * (m.impact.craterRadius/3)) )
			tInsert(featureslist, {name = rockFeatureNames[rfi], x = m.sx+offsetX, z = m.sz+offsetZ, rot = mRandom(0, 360)})
			rfi = rfi + 1
			if rfi > #rockFeatureNames then rfi = 1 end
			rockCount = rockCount + 1
			if rockCount == maxRocks then break end
		end
	end
	spEcho(rockCount .. " rocks created of " .. maxRocks .. " maximum")

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

	Spring.SendLuaRulesMsg('HangTimeoutManager reset')

	spEcho('loony bin map generated')
end

local function SendGroundDecals()
	if not groundDecalWidgetLoaded then return end
	SendToUnsynced('ClearGroundDecals')
	-- add metal spot decals
	for i, spot in pairs(metalSpots) do
		SendToUnsynced('GroundDecal', "maps/mex.png", spot.x, spot.z, myWorld.metalSpotRadius*6, nil, nil, 0.5, 0, 0, 0.25)
	end
	-- add geothermal decals
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
	spEcho(n .. ' blast ray decals')
end

function gadget:GameID(gameID)
	thisGameID = gameID
	local rseed = 0
	local rstr = tostring(gameID)
	for i = 1, string.len(rstr) do
		local byte = string.byte(string.sub(rstr, i))
		rseed = rseed + byte
	end
	spEcho("random seed: " .. rseed)
	crazyeyes = {}
	for i, teamID in pairs(Spring.GetTeamList()) do
		if teamID ~= Spring.GetGaiaTeamID() then
			for x = 0, gMapSizeX, centerX do
				for z = 0, gMapSizeZ, centerZ do
					local unitID = Spring.CreateUnit("crazyeye", x, 1000, z, 0, teamID)
					tInsert(crazyeyes, unitID)
				end
			end
		end
	end
	GenerateMap(rseed)
end

function gadget:GameStart()
	-- if they're destroyed before game start, the team dies
	for i, unitID in pairs(crazyeyes) do
		Spring.DestroyUnit(unitID, false, true)
	end
end

function gadget:GameFrame(frame)
	-- have to send them late, otherwise the height map hasn't yet updated
	if frame == 100 then
		SendGroundDecals()
	end
end


function gadget:Initialize()
	
end


function gadget:RecvLuaMsg(msg, playerID)
	if msg ~= "Ground Decal Widget Loaded" then return end
	groundDecalWidgetLoaded = true
	SendGroundDecals() -- so that someone new joining the game will get decals
end

-- Loony callins

function Loony.CompleteRenderer(renderer)
	local mapRuler = renderer.mapRuler
	if renderer.renderType == "Height" then
		local baselevel = 200 - renderer.heightBuf.minHeight -- minHeight is negative
		-- write height map array to spring
		spSetHeightMapFunc(function()
			for x, yy in pairs(renderer.data) do
				FeedWatchDog()
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
			FeedWatchDog()
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
