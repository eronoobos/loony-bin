--------------------------------------------------------------------------------------------------------
-- Gravity settings
--------------------------------------------------------------------------------------------------------

if (Spring.GetMapOptions().wind == "low") then
	return {
		minWind = 0,
		maxWind = 10,
	}
elseif (Spring.GetMapOptions().wind == "medium") then
	return {
		minWind = 5,
		maxWind = 20,
	}
elseif (Spring.GetMapOptions().wind == "high") then
	return {
		minWind = 10,
		maxWind = 30,
	}
end
