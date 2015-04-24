function gadget:GetInfo()
	return {
		name 	= "Hang Timeout Manager",
		desc 	= "set hang timeouts",
		author 	= "eronoobos",
		date 	= "April 2015",
		license = "WTFPL",
		layer	= 0,
		version = "1",
		enabled = true,
	}
end

local initTimeout = 999999 -- set timeout to this on initialize

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


----- SPRING SYNCED ------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-------------------------------------------------------

local origTimeout = 10 -- a guess

local function SetHangTimeout(timeout)
	if not timeout then return end
	pcall(Spring.SetConfigInt,"HangTimeout",timeout,1)
	pcall(Spring.SetConfigInt,"HangTimeout",timeout,true)
	spEcho("HangTimeout set to " .. tostring(timeout))
end

function gadget:Initialize()
	origTimeout = Spring.GetConfigInt("HangTimeout")
	spEcho("original timeout " .. tostring(origTimeout))
	if initTimeout then SetHangTimeout(initTimeout) end
end

function gadget:RecvLuaMsg(msg, playerID)
	if not StringBegins(msg, 'HangTimeoutManager') then return end
	local words = splitIntoWords(msg)
	if words[2] then
		local timeout = tonumber(words[2]) or origTimeout
		SetHangTimeout(timeout)
	end
end

function gadget:Shutdown()
	SetHangTimeout(origTimeout)
end

----- SPRING UNSYNCED ------------------------------------------
else
--------------------------------------------------------


---------------------------------------------------------
end
---------------------------------------------------------
