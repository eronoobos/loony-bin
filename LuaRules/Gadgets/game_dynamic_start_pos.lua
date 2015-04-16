function gadget:GetInfo()
	return {
		name 	= "Dynamic Start Positions",
		desc 	= "set team start positions after mapinfo",
		author 	= "eronoobos",
		date 	= "April 2015",
		license = "WTFPL",
		layer	= 0,
		version = "1",
		enabled = true,
	}
end

local tInsert = table.insert
local spEcho = Spring.Echo

local function StringBegins(str, beginStr)
	return string.sub(str, 1, string.len(beginStr)) == beginStr
end

local function splitIntoWords(s)
  local words = {}
  for w in s:gmatch("%S+") do tInsert(words, w) end
  return words
end

local startPositions = {}

function gadget:Initialize()
	-- replace Start Positions
	Spring.GetTeamStartPosition = function(teamID)
		local start = startPositions[teamID] or {x=0, z=0}
		return start.x, Spring.GetGroundHeight(start.x,start.z), start.z
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if not StringBegins(msg, 'DynamicStartPositions') then return end
	local words = splitIntoWords(msg)
	local cmd = words[2]
	if cmd == 'add' then
		local teamID = tonumber(words[3])
		local x = tonumber(words[4])
		local z = tonumber(words[5])
		spEcho('received start position', teamID, x, z)
		startPositions[teamID] = {x=x, z=z}
	end
end