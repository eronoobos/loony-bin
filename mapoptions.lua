----------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------
-- File:        MapOptions.lua
-- Description: Custom MapOptions file that makes possible to set up variable options before game starts, like ModOptions.lua
-- Author:      SirArtturi, Lurker, Smoth, jK
----------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------
--	NOTES:
--	- using an enumerated table lets you specify the options order
--
--	These keywords must be lowercase for LuaParser to read them.
--
--	key:			the string used in the script.txt
--	name:		 the displayed name
--	desc:		 the description (could be used as a tooltip)
--	type:		 the option type
--	def:			the default value
--	min:			minimum value for number options
--	max:			maximum value for number options
--	step:		 quantization step, aligned to the def value
--	maxlen:	 the maximum string length for string options
--	items:		array of item strings for list options
--	scope:		'all', 'player', 'team', 'allyteam'			<<< not supported yet >>>
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local options = {
--// Sections
	{
		key  = 'Map',
		name = 'Map Settings',
		desc = 'Settings affecting the characteristics of the map as a whole.',
		type = 'section',
	},

	{
		key  = 'Craters',
		name = 'Crater Settings',
		desc = 'Control the number, size, and mirroring of craters.',
		type = 'section',
	},

	{
		key  = 'Atmosphere',
		name = 'Atmosphere Settings',
		desc = 'Weather and time',
		type = 'section',
	},

	{
		key  = 'Economy',
		name = 'Economy Settings',
		desc = '',
		type = 'section',
	},

--// Options
	--// Map
	{
		key  = "gravity",
		name = "Gravity",
		desc = "gravity",
		type = "number",
		section = 'Map',
		def  = 75,
		min  = 25,
		max  = 200,
		step  = 25,
	},
	{
		key  = "symmetry",
		name = "Symmetry",
		desc = "create a symmetric map for fair gameplay",
		type = "bool",
		def  = true,
		section = 'Map',
	},

	--// Craters
	{
		key  = "size",
		name = "Size",
		desc = "Size of craters",
		type = "list",
		def  = "medium",
		section = 'Craters',
		items = {
			{ key = "small",  name = "Small",  desc = "Small" },
			{ key = "medium",   name = "Medium",   desc = "Medium" },
			{ key = "large", name = "Large", desc = "Large" }
		},
	},
	{
		key  = "ramps",
		name = "Ramps",
		desc = "ramps to allow vehicle passage in and out of craters",
		type = "bool",
		def  = false,
		section = 'Craters',
	},

	--// Atmosphere
	{
		key  = "timeofday",
		name = "Time of day",
		desc = "Night or day?",
		type = "list",
		def  = "day",
		section = 'Atmosphere',
		items = {
			{ key = "dawn",  name = "Dawn",  desc = "Dawn" },
			{ key = "day",   name = "Day",   desc = "Daytime" },
			{ key = "night", name = "Night", desc = "Nighttime" }
		},
	},

	--// Economy
	{
		key  = 'metal',
		name = 'Metal Production',
		desc = 'Metal production levels - How much each metal spot produces',
		type = 'list',
		section = 'Economy',
		def  = 'normal',
		items	= {
			{ key = 'low', name = "Low (1.5)", desc = "Low metal density (1.5 per spot)" },
			{ key = 'normal', name = "Normal (2.0)", desc = "Default metal density (2.0 per spot)" },
			{ key = 'high', name = "High (3.0)", desc = "High metal density (3.0 per spot)" },
		},
	},
}

return options