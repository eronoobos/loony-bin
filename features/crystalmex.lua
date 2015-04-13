-----------------------------------------------------------------------------
--  crystalmex
-----------------------------------------------------------------------------
local featureDef	=	{
	name				= "crystalmex",
	blocking			= false,
	category			= "metal",
	damage				= 100,
	description			= "crystal mex",
	energy				= 0,

	flammable			= false,
	footprintX			= 2,
	footprintZ			= 2,
	height				= "36",
	hitdensity			= "5",
	metal				= 0,
	object				= "features/crystallMex.s3o",
	reclaimable			= false,
	autoreclaimable		= false, 	
	world				= "All Worlds",
	customparams = { 
		randomrotate		= "true", 
	}, 
}
return lowerkeys({[featureDef.name] = featureDef})