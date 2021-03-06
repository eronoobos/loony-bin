--------------------------------------------------------------------------------------------------------
-- Night settings
--------------------------------------------------------------------------------------------------------

if (Spring.GetMapOptions().timeofday ~= "night") then
	return
end

local function Scale(tag, scale)
	local value = loadstring("return mapinfo." .. tag:lower())()
	assert(type(value) == "number")
	loadstring("mapinfo." .. tag:lower() .. " = " .. value * scale)()
end

local function ColorShift(tag, shift)
	local color = loadstring("return mapinfo." .. tag:lower())()
	assert(type(color) == "table")
	color[1] = color[1] * shift[1]
	color[2] = color[2] * shift[2]
	color[3] = color[3] * shift[3]
end

------------------------------------------------------------
-- Relative Settings

local blueShift = {0.4, 0.3, 0.6}
local blackShift = {0.05, 0.05, 0.07}

ColorShift("lighting.groundambientcolor",  blueShift)
ColorShift("lighting.grounddiffusecolor",  blueShift)
ColorShift("lighting.groundspecularcolor", blueShift)
ColorShift("lighting.unitambientcolor",    blueShift)
ColorShift("lighting.unitdiffusecolor",    blueShift)
ColorShift("lighting.unitspecularcolor",   blueShift)
Scale("lighting.groundshadowdensity", 0.4)
Scale("lighting.unitshadowdensity",   0.4)

ColorShift("atmosphere.skycolor", blackShift)
ColorShift("atmosphere.fogcolor", blackShift)
Scale("atmosphere.fogstart", 0.5)
Scale("atmosphere.fogend",   0.7)


------------------------------------------------------------
-- Absolute Settings

local cfg = {
	atmosphere = {
		--skybox       = "nightmoon2.dds",
		suncolor     = {0.5, 0.5, 0.3},
		cloudColor   = {0, 0, 0},
	},
	lighting = {
		sunDir              = {0.1, 1, -0.3},
	},
}


return cfg