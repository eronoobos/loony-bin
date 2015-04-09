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
		key  = 'metal',
		name = 'Metal Production',
		desc = 'Metal production levels - How much metal is produced per second',
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