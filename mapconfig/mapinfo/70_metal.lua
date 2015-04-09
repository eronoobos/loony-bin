--------------------------------------------------------------------------------------------------------
-- Metal settings
--------------------------------------------------------------------------------------------------------

if (Spring.GetMapOptions().metal == "low") then
	return {
		maxmetal = 0.75,
	}
elseif (Spring.GetMapOptions().metal == "normal") then
	return {
		maxmetal = 1.0,
	}
elseif (Spring.GetMapOptions().metal == "high") then
	return {
		maxmetal = 1.5,
	}
end
