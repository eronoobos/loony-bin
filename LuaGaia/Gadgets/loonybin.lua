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

local twicePi = math.pi * 2
local mRandom = math.random
local mRandomSeed = math.randomseed
local mCos = math.cos
local mSin = math.sin
local mSqrt = math.sqrt
local mCeil = math.ceil
local mFloor = math.floor
local mMax = math.max
local mMin = math.min

local tInsert = table.insert
local tRemove = table.remove

-- local functions

local function tGetRandom(fromTable)
  return fromTable[mRandom(1, #fromTable)]
end

local function tRemoveRandom(fromTable)
	if not fromTable then return end
	return tRemove(fromTable, mRandom(1, #fromTable))
end

local function CirclePos(cx, cy, dist, angle)
  angle = angle or mRandom() * twicePi
  local x = cx + dist * mCos(angle)
  local y = cy + dist * mSin(angle)
  return x, y
end

local function WithinBox(x, z, box)
	-- spEcho(box[1], box[2], box[3], box[4], "within?", x, z)
	return x > box[1] and z > box[2] and x < box[3] and z < box[4]
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

local precalcStartBoxes = {
	-- [number of allyteams] = {
		-- {xmin, zmin, xmax, zmax}
	-- }
	[2] = {
		{0, 0, 0.5, 1},
		{0.5, 0, 1, 1}
	},
	[4] = {
		{0, 0, 0.5, 0.5},
		{0.5, 0.5, 1, 1},
		{0, 0.5, 0.5, 1},
		{0.5, 0, 1, 0.5}
	},
}
for num, boxes in pairs(precalcStartBoxes) do
	for i, box in pairs(boxes) do
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

function gadget:GameID(gameID)
	thisGameID = gameID
end


function gadget:Initialize()
	spEcho("initializing loony bin gadget...")

	if not Spring.ClearWatchDogTimer then
		pcall(Spring.SetConfigInt,"HangTimeout",123456789,1)
		pcall(Spring.SetConfigInt,"HangTimeout",123456789,true)
	end

	-- default config values
	local randomseed = 1
	local minDiameter, maxDiameter = 5, 400
	local metersPerElmo = 8
	local gravity = (Game.gravity / 130) * 9.8
	local density = (Game.mapHardness / 100) * 2500
	local mirror = "auto"
	local showerRamps = false
	local startSize = 150

	-- get map options
	local options = spGetMapOptions()
	if options ~= nil then
		if options.randomseed ~= nil then
			randomseed = tonumber(options.randomseed)
		end
		if options.size == "large" then
			minDiameter, maxDiameter = 25, 800
		elseif options.size == "medium" then
			minDiameter, maxDiameter = 5, 400
		elseif options.size == "small" then
			minDiameter, maxDiameter = 1, 200
		end
		mirror = options.mirror or "rotational"
		if options.ramps ~= nil then
			showerRamps = tonumber(options.ramps) == 1
		end
	end
	spEcho("randomseed " .. randomseed, "maxDiameter " .. maxDiameter, "mirror " .. mirror, "showerRamps " .. tostring(showerRamps))

	
	-- get number of allyteams
	local gaiaTeamInfo = { Spring.GetTeamInfo(Spring.GetGaiaTeamID()) }
	local gaiaAllyTeamID = gaiaTeamInfo[6]
	local allyTeams = {}
	for i, allyTeamID in pairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= gaiaAllyTeamID then
			tInsert(allyTeams, allyTeamID)
		end
	end
	if mirror == "auto" then
		if #allyTeams % 2 == 0 then
			mirror = "rotational"
		else
			mirror = "none"
		end
		spEcho("mirror", mirror)
	end
	-- get startboxes
	local numPrimaryAllyTeams = #allyTeams
	if mirror ~= "none" then
		numPrimaryAllyTeams = #allyTeams / 2
	end
	local startBoxes = {}
	local primaryAllyTeams = {}
	for i, allyTeamID in pairs(allyTeams) do
		if Game.startPosType == 2 then
			startBoxes[allyTeamID] = { Spring.GetAllyTeamStartBox(allyTeamID) }
		elseif mirror == "none" then
			startBoxes[allyTeamID] = {0, 0, Game.mapSizeX, Game.mapSizeZ}
		else
			startBoxes[allyTeamID] = precalcStartBoxes[#allyTeams][i]
		end
		if (allyTeamID+1) % 2 ~= 0 then
			primaryAllyTeams[allyTeamID] = true
		end
		spEcho("allyteamID, start box", allyTeamID, startBoxes[allyTeamID][1], startBoxes[allyTeamID][2], startBoxes[allyTeamID][3], startBoxes[allyTeamID][4])
	end
	-- get number of teams & start meteors
	local startMeteorTeams = {}
	local teamsByAlly = {}
	local teamCount = 0
	for i, teamID in pairs(Spring.GetTeamList()) do
		if teamID ~= Spring.GetGaiaTeamID() then
			local teamInfo = { Spring.GetTeamInfo(teamID) }
			local allyTeamID = teamInfo[6]
			if primaryAllyTeams[allyTeamID] then
				tInsert(startMeteorTeams, {teamID=teamID, box=startBoxes[allyTeamID]})
				spEcho("primary ally, team", allyTeamID, teamID)
			else
				spEcho("mirror ally, team", allyTeamID, teamID)
			end
			teamsByAlly[allyTeamID] = teamsByAlly[allyTeamID] or {}
			tInsert(teamsByAlly[allyTeamID], teamID)
			teamCount = teamCount + 1
		end
	end
	spEcho(teamCount .. " teams")

	metalTarget = teamCount * 9
	geothermalTarget = teamCount
	local metalSpotMaxPerCrater = mMax(3, teamCount)
	spEcho("metalTarget " .. metalTarget, "geothermalTarget " .. geothermalTarget, "metalSpotMaxPerCrater " .. metalSpotMaxPerCrater)

	-- create crater map
	mRandomSeed(randomseed)
	myWorld = Loony.World(Game.mapX, Game.mapY, metersPerElmo, gravity, density, mirror, metalTarget, geothermalTarget, showerRamps)
	myWorld.metalSpotMaxPerCrater = metalSpotMaxPerCrater
	local testM = myWorld:AddMeteor(1, 1, startSize) -- test start crater radius
	local startRadius = testM.impact.craterRadius
	testM:Delete()
	local number = mCeil(metalTarget / 2)
	local try = 0
	local spots = {}
	local startMeteors = {}
	while #spots < metalTarget and try < 15 do
		FeedWatchDog()
		startMeteors = {}
		myWorld:Clear()
		myWorld:MeteorShower(number, minDiameter, maxDiameter)
		-- add start meteors
		for i, smt in pairs(startMeteorTeams) do
			local x = mRandom(smt.box[1]+startRadius, smt.box[3]-startRadius)
			local z = mRandom(smt.box[2]+startRadius, smt.box[4]-startRadius)
			-- spEcho(smt.box[1], smt.box[2], smt.box[3], smt.box[4], startRadius, x, z)
			local m = myWorld:AddMeteor(x, z, startSize, nil, nil, nil, nil, 3, false)
			if showerRamps then m:Add180Ramps() end
			m.metalGeothermalRampSet = true
			if m.mirrorMeteor then
				if showerRamps then m.mirrorMeteor:Add180Ramps() end
				m.mirrorMeteor.metalGeothermalRampSet = true
				tInsert(startMeteors, {meteor = m.mirrorMeteor})
			end
			-- spEcho("start meteor", m.sx, m.sz, "mirror", m.mirrorMeteor.sx, m.mirrorMeteor.sz)
			tInsert(startMeteors, {meteor = m, teamID = smt.teamID})
		end
		myWorld:SetMetalGeothermalRamp()
		myWorld:ResetMeteorAges()
		number = number + 1
		try = try + 1
		maxDiameter = maxDiameter + 5
		spots = myWorld:GetMetalSpots()
		spEcho("try " .. try, "number " .. number, "spots " .. #spots)
	end
	spEcho("found crater map in " .. try .. " tries")
	spEcho(number .. " craters", maxDiameter .. " maxDiameter", #spots .. " metal spots (target: " .. metalTarget .. ")")

	-- explicitly set start crater characteristics
	-- give team start locations to luarules gadget
	for i, sm in pairs(startMeteors) do
		local m = sm.meteor
		m.impact.bowlPower = 2
		m.impact.craterDepth = m.impact.craterDepth * 0.5
		local tID = sm.teamID
		if not tID then
			for allyTeamID, box in pairs(startBoxes) do
				if WithinBox(m.sx, m.sz, box) then
					tID = tRemoveRandom(teamsByAlly[allyTeamID])
					break
				end
			end
		end
		if tID then
			Spring.SendLuaRulesMsg('DynamicStartPositions add ' .. tID .. ' ' .. m.sx .. ' ' .. m.sz)
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
end


function gadget:RecvLuaMsg(msg, playerID)
	if msg ~= "Ground Decal Widget Loaded" then return end
	SendToUnsynced('ClearGroundDecals')
	-- add metal spot decals
	for i, spot in pairs(metalSpots) do
		SendToUnsynced('GroundDecal', "maps/mex.png", spot.x, spot.z, myWorld.metalSpotRadius*6, nil, nil, 0.5, 0, 0, 0.25)
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
