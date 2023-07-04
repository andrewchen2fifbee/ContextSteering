--!strict

--[[ DESCRIPTION
Defines behavior parameter table types.
For use in Behaviors, and any modules which create and modify parameters before passing them to a behavior function.
]]
local BehaviorParams = {}

BehaviorParams.DEFAULT_RESOLUTION = 8 -- num discrete directions to use in each interest map

-- TODO consider allowing passing falloff functions as params

-- Generic set of behavior parameters
-- Behaviors may use some or all of these depending on implementation
export type GenericParams = {
	--[[
	Optional name for what this thing represents. Doesn't change any behavior
	]]
	DebugName: string,
	
	--[[
	How many slots the interest map should have
	Should be int but floats work (truncated to int)
	]]
	Resolution: number, -- any int > 2
	
	--[[
	Targets will only be considered if (RangeMin <= range <= RangeMax)
	]]
	-- Constraint: (RangeMax > RangeMin)
	RangeMin: number, -- any number >= 0
	RangeMax: number, -- any number > 0
	
	--[[
	Interests will be returned in range [0, InterestMax]
	]]
	-- TODO may be worth readding InterestMin later
	InterestMax: number, -- any number > 0

	--[[
	How wide of an arc to write interest values in
	Affects how far away from the desired direction is still considered OK (but less desirable) to move towards
	Recommend at least 120 (more for low resolution maps, less for high resolution maps, don't go too low)
	Angular falloff is always applied across the entire interest cone
	]]
	InterestConeArcDegrees: number, -- any number > 0

	--[[
	Affects where distance interest falloff starts / ends
	range <= start			-> interest == InterestMax
	start < range < end		-> 0 < interest < InterestMax
	end <= range				-> interest == 0
	]]
	-- Constraint: (DistanceFalloffEnd > DistanceFalloffStart)
	DistanceFalloffStart: number, -- any number >= 0
	DistanceFalloffEnd: number, -- any number > 0

	--[[
	Affects what direction the NPC is interested in, relative to the thing it's looking at
	Examples: 
		Forward = 1, Right = 0 -> Move towards target
		Forward = 1, Right = 2 -> Move slightly towards target (33%), and circle around the target's right (67%)
		Forward = -1, Right = -1 -> Move away from target (50%), and circle around the target's left (50%)
	Note to self: fwd:Cross(up) = right, up:Cross(fwd) = left
	]]
	-- Constraint: (Forward ~= 0 or Right ~= 0)
	DirectionModifierWeightForward: number, -- any number
	DirectionModifierWeightRight: number, -- any number
	
	-- unused: possibly useful for moving NPC/moving target interactions
	--RelativeVelocityMultiplier: number, -- any number >= 0
}

-- Optional override values when constructing new GenericParams
-- See GenericParams for full descriptions of parameters, including additional constraints
-- A GenericParams can be used as a GenericParamsConstructorOverrrides (see Behaaviors.Flee)
export type GenericParamsConstructorOverrides = {
	DebugName: string?,

	Resolution: number?, -- any int > 2

	RangeMin: number?, -- any number >= 0
	RangeMax: number?, -- any number > 0

	InterestMax: number?, -- any number > 0
	
	InterestConeArcDegrees: number?, -- any number > 0
	
	DistanceFalloffStart: number?, -- any number >= 0
	DistanceFalloffEnd: number?, -- any number > 0

	DirectionModifierWeightForward: number?, -- any number
	DirectionModifierWeightRight: number?, -- any number
	
	--RelativeVelocityMultiplier: number?, -- any number >= 0
}

function BehaviorParams.NewGenericParams(overrides: GenericParamsConstructorOverrides?): GenericParams
	local overrides = (overrides or {}) :: GenericParamsConstructorOverrides
	
	local params = {
		DebugName = overrides.DebugName or "",
		
		Resolution = overrides.Resolution or BehaviorParams.DEFAULT_RESOLUTION,
		
		RangeMin = overrides.RangeMin or 0,
		RangeMax = overrides.RangeMax or 100,
		
		InterestMax = overrides.InterestMax or 1,
		
		-- Falloff start/end ranges handled below: Defaults are derived from values in params
		
		InterestConeArcDegrees = overrides.InterestConeArcDegrees or 180,
		
		DirectionModifierWeightForward = overrides.DirectionModifierWeightForward or 1,
		DirectionModifierWeightRight = overrides.DirectionModifierWeightRight or 0,
	}
	
	-- Potentially derived properties
	params.DistanceFalloffStart = overrides.DistanceFalloffStart or params.RangeMin
	params.DistanceFalloffEnd = overrides.DistanceFalloffEnd or params.RangeMax
	
	return params
end

-- Testing/debug: Verifies that params doesn't violate any constraints
function BehaviorParams.VerifyGenericParams(params: GenericParams): (boolean, string?)
	local valid = true
	local errStart = "[ContextSteering] BehaviorParams verification failed: "
	
	if not (params.Resolution > 2) then
		return false, errStart .. "Resolution must be greater than 2! Anything less is too small to be useful."
	end
	
	if not (params.RangeMin >= 0) then
		return false, errStart.. "RangeMin must be greater than or equal to 0!"
	end
	if not (params.RangeMax > 0) then
		return false, errStart .. "RangeMax must be greater than 0!"
	end
	if not (params.RangeMax > params.RangeMin) then
		return false, errStart .. "RangeMax must be greater than RangeMin!"
	end
	
	if not (params.InterestMax > 0) then
		return false, errStart .. "InterestMax must be greater than 0!"
	end
	
	if not (params.InterestConeArcDegrees > 0) then
		return false, errStart .. "InterestConeArcDegrees must be greater than 0!"
	end
	
	if not (params.DistanceFalloffStart >= 0) then
		return false, errStart .. "DistanceFalloffStart must be greater than or equal to 0!"
	end
	if not (params.DistanceFalloffEnd > 0) then
		return false, errStart .. "DistanceFalloffEnd must be greater than 0!"
	end
	if not (params.DistanceFalloffEnd > params.DistanceFalloffStart) then
		return false, errStart .. "DistanceFalloffEnd must be greater than or equal to DistanceFalloffStart!"
	end
	
	if not (params.DirectionModifierWeightForward ~= 0 or params.DirectionModifierWeightRight ~= 0) then
		return false, errStart .. "DirectionModifierWeightForward and DirectionModifierWeightRight cannot both be 0!"
	end
	
	return true
end

return BehaviorParams