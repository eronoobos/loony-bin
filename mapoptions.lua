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
	--// Craters
	{
		key  = "randomseed",
		name = "Seed",
		desc = "Seed for initializing the random number generator. The same seed with the same parameters will generate the same map.",
		type = "number",
		def  = 1,
		section = 'Craters',
		min = 1,
		max = 99,
		step = 1,
	},
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
		key  = "mirror",
		name = "Symmetry",
		desc = "type of map symmetry",
		type = "list",
		def  = "rotational",
		section = 'Craters',
		items = {
			{ key = "rotational",  name = "180-Degree Rotational", desc = "symmetry is rotated around the map center by 180 degrees" },
			{ key = "reflectionalx",   name = "X-Axis", desc = "east and west are symmetrical" },
			{ key = "none", name = "None", desc = "no symmetry" },
		},
	},
	{
		key  = "ramps",
		name = "Ramps",
		desc = "ramps to allow vehicle passage in and out of craters",
		type = "bool",
		def  = "false",
		section = 'Craters',
	},
	{
		key  = "waterlevel",
		name = "Water Level",
		desc = "water level: dry, shallow pools, lakes, or ocean",
		type = "list",
		def  = "dry",
		section = 'Craters',
		items = {
			{ key = "dry",  name = "Dry",  desc = "no water" },
			{ key = "pools",  name = "Crater Pools",  desc = "shallow pools in deeper craters" },
			{ key = "lakes",   name = "Crater Lakes",   desc = "every crater is a lake" },
			{ key = "ocean", name = "Ocean", desc = "only crater rims are above water" },
		},
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
			{ key = "day",   name = "Day",   desc = "Light Side" },
			{ key = "night", name = "Night", desc = "Dark Side" }
		},
	},

	--// Economy
	{
		key  = "metals",
		name = "Metal Spots",
		desc = "target number of metal spots. may not be reached",
		type = "number",
		def  = 24,
		section = 'Economy',
		min = 12,
		max = 36,
		step = 4,
	},
	{
		key  = "geothermals",
		name = "Geothermal Vents",
		desc = "target number of geothermal vents. may not be reached",
		type = "number",
		def  = 4,
		section = 'Economy',
		min = 0,
		max = 8,
		step = 2,
	},
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