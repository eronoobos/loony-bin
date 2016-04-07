function gadget:GetInfo()
	return {
		name 	= "Loony Bin",
		desc 	= "randomized crater map flavored to taste",
		author 	= "eronoobos",
		date 	= "April 2015",
		license = "WTFPL",
		layer	= 0,
		version = "2",
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
  return ((angle1 + pi - angle2) % twicePi) - pi
end

local function CirclePos(cx, cy, dist, angle)
  angle = angle or mRandom() * twicePi
  local x = cx + dist * mCos(angle)
  local y = cy + dist * mSin(angle)
  return x, y
end

local function RandomVariance(variance)
  return (1-variance) + (mRandom() * variance * 2)
end

local function WithinBox(x, z, box)
	-- spEcho(box[1], box[2], box[3], box[4], "within?", x, z)
	if #box == 2 then
		local angle, dx, dy = AngleXYXY(centerX, centerZ, x, z)
		local adist = AngleDist(angle, box[1])
		return (adist < box[2] and adist > 0)
	elseif #box == 4 then
		return x > box[1] and z > box[2] and x < box[3] and z < box[4]
	end
end

local function DistanceSq(x1, y1, x2, y2)
  local dx = mAbs(x2 - x1)
  local dy = mAbs(y2 - y1)
  return (dx*dx) + (dy*dy)
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
		{0, 0, 0.33, 1},
		{0.67, 0, 1, 1}
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
		{0, 0, 0.33, 0.33},
		{0.67, 0.67, 1, 1},
		{0, 0.67, 0.33, 1},
		{0.67, 0, 1, 0.33}
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
		local off = mRandom() * twicePi
		for a = 1, num do
			local box = { off+(inc*(a-1)), inc }
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
	spEcho('generating loony bin map with randomseed ' .. randomseed)

	-- default config values
	randomseed = randomseed or 1
	local minRadius, maxRadius = 15, 1000
	local showerRamps = false
	local symmetry = true
	local metersPerElmo = 8
	local gravity = (Game.gravity / 130) * 9.8
	local density = (Game.mapHardness / 100) * 2500
	local startRadius = 380

	-- get map options
	local options = spGetMapOptions()
	if options ~= nil then
		if options.size == "large" then
			minRadius, maxRadius = 30, 2000
		elseif options.size == "medium" then
			minRadius, maxRadius = 15, 1000
		elseif options.size == "small" then
			minRadius, maxRadius = 1, 500
		end
		if options.ramps ~= nil then
			showerRamps = tonumber(options.ramps) == 1
		end
		if options.symmetry ~= nil then
			symmetry = tonumber(options.symmetry) == 1
		end
	end
	spEcho("maxRadius " .. maxRadius, "showerRamps " .. tostring(showerRamps))
	
	local fromEdges = startRadius * 1.25

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
	local mirror = symmetry and #allyTeams >= 2 and #allyTeams <= 8

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
	end
	local firstStartBox = startBoxes[allyTeams[1]] or {0, 0, Game.mapSizeX, Game.mapSizeZ}
	if precalcStartBoxes[-#allyTeams] then
		firstStartBox = precalcStartBoxes[-#allyTeams][1]
	end
	local startsWithinBox
	if #firstStartBox == 4 then
		firstStartBox[1] = firstStartBox[1] + fromEdges
		firstStartBox[2] = firstStartBox[2] + fromEdges
		firstStartBox[3] = firstStartBox[3] - fromEdges
		firstStartBox[4] = firstStartBox[4] - fromEdges
		local f = firstStartBox
		local dx = f[3] - f[1]
		local dz = f[4] - f[2]
		startsWithinBox = {
			{x = f[1], z = f[2]},
			{x = f[3], z = f[2]},
			{x = f[1], z = f[4]},
			{x = f[3], z = f[4]},
			{x = f[1]+(dx/2), z = f[2]+(dz/2)},
			{x = f[1], z = f[2]+(dz/2)},
			{x = f[3], z = f[2]+(dz/2)},
			{x = f[1]+(dx/2), z = f[2]},
			{x = f[1]+(dx/2), z = f[4]},
		}
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
	spEcho("allyTeams " .. #allyTeams, teamCount .. " teamCount", maxTeamsPerAlly .. " maxTeamsPerAlly", startMeteorNumber .. " startMeteorNumber")

	local metalTarget = (teamCount * 6) + (#allyTeams * 3)
	local geothermalTarget = teamCount
	local metalSpotMaxPerCrater = #allyTeams
	spEcho("metalTarget " .. metalTarget, "geothermalTarget " .. geothermalTarget, "metalSpotMaxPerCrater " .. metalSpotMaxPerCrater)
	local unMirroredMetalTarget = metalTarget
	if mirror then unMirroredMetalTarget = unMirroredMetalTarget / #allyTeams end

	-- create crater map
	mRandomSeed(randomseed)
	myWorld = Loony.World(Game.mapX, Game.mapY, metersPerElmo, gravity, density, "none", metalTarget, geothermalTarget, showerRamps)
	metersPerElmo = mFloor(myWorld.complexDiameter / 693) -- 693: target complex diamter in elmos
	spEcho("gravity: " .. gravity .. " meters per second squared", metersPerElmo .. " meters per elmo")
	myWorld.metersPerElmo = metersPerElmo
	myWorld.metalSpotMaxPerCrater = metalSpotMaxPerCrater
	myWorld.generateBlastNoise = false
	myWorld.generateAgeNoise = false
	myWorld.underlyingPerlin = true
	myWorld:Calculate()
	local testM = myWorld:AddMeteor(1, 1) -- test start crater diameter
	testM:Resize(startRadius)
	local startDiameterImpactor = mCeil(testM.diameterImpactor)
	testM:Resize(maxRadius)
	local maxDiameter = mCeil(testM.diameterImpactor)
	testM:Resize(minRadius)
	local minDiameter = mCeil(testM.diameterImpactor)
	testM:Delete()
	spEcho("minRadius " .. minRadius, "minDiameter " .. minDiameter)
	spEcho("maxRadius " .. maxRadius, "maxDiameter " .. maxDiameter)
	spEcho("startRadius " .. startRadius, "startDiameterImpactor " .. startDiameterImpactor)
	local number = 12
	if number * #allyTeams > 48 then
		number = 10
	elseif not mirror then
		number = 20
		maxDiameter = maxDiameter * 1.33
	end
	local try = 1
	local spots = {}
	local highestMetal = 0
	local highestMeteors = {}
	local emptyCenter = (smallestMapDimension / 6)
	local emptyCenterSq = emptyCenter ^ 2
	local largestDimensionSq = mMax(gMapSizeX, gMapSizeZ) ^ 2
	while #spots < metalTarget and try < 20 do
		FeedWatchDog()
		myWorld:Clear()
		myWorld:MeteorShower(number, minDiameter, maxDiameter)
		-- add a big crater if the center is empty and map symmetry is on
		if mirror then
			local lowestDistSq = largestDimensionSq
			for i, m in pairs(myWorld.meteors) do
				if m.impact.craterRadius >= myWorld.metalSpotMinRadius then
					local dx = mAbs(m.sx - centerX) - m.impact.craterRadius
					local dz = mAbs(m.sz - centerZ) - m.impact.craterRadius
					local distSq = (dx*dx) + (dz*dz)
					if distSq < lowestDistSq then
						lowestDistSq = distSq
					end
				end
			end
			if lowestDistSq > emptyCenterSq then
				-- sx, sz, diameterImpactor, velocityImpactKm, angleImpact, densityImpactor, age, metal, geothermal, seedSeed, ramps, mirrorMeteor, noMirror
				local m = myWorld:AddMeteor(centerX+RandomVariance(5), centerZ+RandomVariance(5), startDiameterImpactor*2, nil, nil, nil, nil, #allyTeams, false, nil, nil, nil, true)
				if myWorld.showerRamps then m:AddSomeRamps(3) end
	  			m.metalGeothermalRampSet = true
	  			m.dontMirror = true
	  			m:Resize( mSqrt(lowestDistSq) * 0.85 )
	  			spEcho("big central crater", m.impact.craterRadius)
			end
		end
		-- add start meteors
		local nn = 1
		for n = 1, startMeteorNumber do
			local x, z
			if #firstStartBox == 2 then
				local angle, dist
				if startMeteorNumber == 1 then
					angle = AngleAdd(firstStartBox[1], firstStartBox[2]/2)
					dist = mRandom(emptyCenter, halfSmallestMapDimension-fromEdges)
				else
					if nn == 1 then
						angle = AngleAdd(firstStartBox[1], firstStartBox[2]/3)
					elseif nn == 2 then
						angle = AngleAdd(firstStartBox[1], firstStartBox[2]/1.5)
					elseif nn == 3 then
						angle = AngleAdd(firstStartBox[1], firstStartBox[2]/2)
					end
					local dd = (halfSmallestMapDimension-fromEdges) - emptyCenter
					local inc = dd / (startMeteorNumber+1)
					dist = emptyCenter + (inc*n)
					nn = nn + 1
					if nn > 3 then nn = 1 end
				end
				x, z = CirclePos(centerX, centerZ, dist, angle)
			elseif #firstStartBox == 4 then
				if not mirror or startMeteorNumber == 1 or startMeteorNumber > 9 then
					x = mRandom(firstStartBox[1], firstStartBox[3])
					z = mRandom(firstStartBox[2], firstStartBox[4])
				else
					x = startsWithinBox[n].x
					z = startsWithinBox[n].z
				end
			end
			if x then myWorld:AddStartMeteor(x, z, startDiameterImpactor) end
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
		maxDiameter = maxDiameter + 2
	end
	spEcho("found crater map in " .. try-1 .. " tries")
	if #spots < metalTarget and highestMetal > #spots then
		-- use the map with the most metal if target not met
		myWorld.meteors = highestMeteors
		spots = myWorld:GetMetalSpots()
	end
	spEcho(#myWorld.meteors .. " craters", #spots .. " metal spots (target: " .. metalTarget .. ")")

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
	spEcho("rendering height & metal maps...")
	FeedWatchDog()
	myWorld:RenderHeight()
	FeedWatchDog()
	myWorld:RenderMetal()
	-- i have to change the height map here and not through GameFrame so that it happens before pathfinding & team LOS initialization
	local i = 1
	while not heightRenderComplete or not metalRenderComplete do
		myWorld:RendererFrame(i)
		i = i + 1
	end

	local featureslist = myWorld:GetFeaturelist() -- get geovents

	-- add reclaimable rocks to empty craters
	local rockCount = 0
	local maxRocks = mFloor(#myWorld.meteors * 0.35)
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
		SendToUnsynced('GroundDecal', "maps/mex.png", spot.x, spot.z, myWorld.metalSpotRadius*5, nil, nil, 1.0, 0.0, 0.0, 0.35)
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
		if m.impact.craterRadius < myWorld.noMirrorRadius then
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

function gadget:GameID(gameID)
	thisGameID = gameID
	local rseed = 0
	local unpacked = VFS.UnpackU8(thisGameID, 1, string.len(thisGameID))
	for i, part in ipairs(unpacked) do
		-- local mult = 256 ^ (#unpacked-i)
		-- rseed = rseed + (part*mult)
		rseed = rseed + part
	end
	spEcho("got randomseed from gameID: " .. rseed)
	if Game.version == '101.0' or tonumber(Game.version) >= 101 then
		Spring.Echo("engine version is 101.0 or higher, using Spring.SetGlobalLos")
		for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
			Spring.SetGlobalLos(allyTeamID, true)
		end
	end
	GenerateMap(rseed)
end

function gadget:GameStart()
	if Game.version ~= '101.0' and tonumber(Game.version) < 101 then
		Spring.Echo("engine version is lower than 101.0 spawning crazyeye units with 9999 losradius")
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
	end
end

function gadget:GameFrame(frame)
	-- if they're destroyed before game start, the team dies
	if frame == 1 then
		if Game.version == '101.0' or tonumber(Game.version) >= 101 then
			for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
				Spring.SetGlobalLos(allyTeamID, false)
			end
		else
			for i, unitID in pairs(crazyeyes) do
				Spring.DestroyUnit(unitID, false, true)
			end
		end
		SendToUnsynced('StopMapGenRep')
	end
	-- have to send them late, otherwise the height map hasn't yet updated
	if frame == 60 then
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

function Loony.FrameRenderer(renderer)
	FeedWatchDog()
end

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
					-- if sx < 8 then Spring.Echo(sx, x) end
					-- if sx > gMapSizeX-8 then Spring.Echo(sx, x) end
					-- if sz < 8 then Spring.Echo(sz, y) end
					-- if sz > gMapSizeZ-8 then Spring.Echo(sz, y) end
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
  Script.LuaUI.ReceiveClearGroundDecals()
end

local function StopMapGenRepToLuaUI(_)
	Script.LuaUI.ReceiveStopMapGenRep()
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction('GroundDecal', GroundDecalToLuaUI)
	gadgetHandler:AddSyncAction('ClearGroundDecals', ClearGroundDecalsToLuaUI)
	gadgetHandler:AddSyncAction('StopMapGenRep', StopMapGenRepToLuaUI)
end

end
--------------------------------------------------------
