function widget:GetInfo()
  return {
    name      = "Map Generation Report",
    desc      = "Tells the player that the map is generating.",
    author    = "eronoobos",
    date      = "May 2015",
    license   = "WTFPL",
    layer     = 5,
    enabled   = true  --  loaded by default?
  }
end

local titleTxt = 'Generating map...'
local subtitleTxt = 'Please wait. Map generation may take a few minutes.'

local myFont

local displayList = 0
local countDown = 100
local stopReceived
local bgAlpha = 0.5
local txtAlpha = 1

local function DrawReport()
	local viewX, viewY, posX, posY = Spring.GetViewGeometry()
	local centerX = (viewX / 2)
	local centerY = (viewY / 2)
	local smallDim = math.min(viewX, viewY)
	local titleSize = math.ceil(smallDim / 25)
	local subtitleSize = math.ceil(smallDim / 50)
	local between = math.ceil(titleSize * 1.33)
	gl.Color(0, 0, 0, bgAlpha)
	gl.Rect(0, 0, viewX, viewY)
	gl.Color(1, 1, 1, txtAlpha)
	gl.Text(titleTxt, centerX, centerY, titleSize, "cvn")
	gl.Text(subtitleTxt, centerX, centerY-between, subtitleSize, "cvn")
end

local function ReceiveStopMapGenRep()
	stopReceived = true
end

function widget:Initialize()
	widgetHandler:RegisterGlobal("ReceiveStopMapGenRep", ReceiveStopMapGenRep)
	displayList = gl.CreateList(DrawReport)
end

function widget:DrawScreen()
	gl.CallList(displayList)
end

function widget:Update()
	if stopReceived then
		if countDown == 0 then
			displayList = 0
			widgetHandler:RemoveWidget()
			return
		end
		local countRatio = countDown / 100
		bgAlpha = 0.5 * countRatio
		txtAlpha = countRatio
		gl.DeleteList(displayList)
		displayList = gl.CreateList(DrawReport)
		countDown = countDown - 1
	end
end

function widget:Shutdown()
	gl.DeleteList(displayList)
end