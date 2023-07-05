--!strict

--[[ DESCRIPTION
Implements context steering: http://www.gameaipro.com/ -> GameAIPro2, Chapter 18: Context Steering 

Context steering allows NPCs to make situationally aware decisions based on their surroundings. 
	Context steering is not a replacement for PathfindingService. 
		Context steering is a greedy algorithm - decisions may be questionable in hindsight. 
		Example: NPCs using context steering will struggle with concave terrain shapes (getting stuck in dead ends). 
	Think about how you can help NPCs make better decisions by changing the information you give them. 

This library is intended for movement on a horizontal plane. 
	Vertical movement (jumping, flying up/down, ...) requires extra NPC movement logic and/or library changes. 

Obvious use case: Creating interesting NPC movement without PathfindingService. 
	You can probably find other uses for context steering. 
]]
-- TODO add testing: integration (bottom-up), some unit on critical components? look into this
-- 			integration: BehaviorParams + InfoGetters -> Behaviors, Behaviors -> ContextSteering
--			test intentionally breaking constraints to make sure it fails in a predictable way
local ContextSteering = {}

--[[
PARAMS
	contextMap <- int-indexed table containing numbers >= 0, #contextMap > 0
RETURN
	direction, interest <- desired movement vector, how interested NPC is in that direction
NOTES
	index 1 points in -Z direction (0, 0, -1)
	subsequent indices are laid out in counterclockwise order around the point of evaluation
]]
function ContextSteering.CalculateMovement(contextMap: {number}): (Vector3, number)
	local max = contextMap[1]
	local maxIdx = 1
	for i, interest in contextMap do
		if interest > max then
			max = interest
			maxIdx = i
		end
	end
	
	-- TODO MAYBE support passing own custom interpolation
	
	local slot, interest = InterpolateMaxSlotAndInterest(contextMap, maxIdx)
	local radians = 2 * math.pi * ((slot - 1) / #contextMap)
	local direction = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), radians).LookVector
	return direction, interest
end

--[[
PARAMS
	contextMaps <- table containing int-indexed tables of numbers >= 0 and #t > 0, where...
		#a == #b for any two tables a, b in contextMaps
RETURN
	combinedMap <- int-indexed table similar to context maps in contextMaps, where...
		each slot contains the max value out of all corresponding contextMaps values
		#contextMap == #contextMaps[1] for any contextMap in contextMaps
]]
function ContextSteering.Combine(contextMaps: {{number}}): {number}
	if #contextMaps <= 0 then
		error("[ContextSteering] Nothing to combine! (contextMaps is empty)")
	end
	local resolution = #contextMaps[1]
	local combinedMap = table.create(resolution, 0)
	for _, contextMap in contextMaps do
		if #contextMap ~= resolution then
			error(`[ContextSteering] Bad map resolution! (Expected {resolution}, but got {#contextMap})`)
		end
		for i = 1, #contextMap do
			combinedMap[i] = math.max(contextMap[i], combinedMap[i])
		end
	end
	
	return combinedMap
end

--[[
PARAMS
	contextMap <- int-indexed table containing numbers >= 0, #contextMap > 0
	maskMap <- int-indexed table similar to contextMap, #maskMap == #contextMap
RETURN
	maskedContextMap <- int indexed table similar to contextMap, where...
		contextMap values have been masked out by non-minimum maskMap values
		#maskedContextMap == #contextMap
]]
function ContextSteering.Mask(contextMap: {number}, maskMap: {number}): {number}
	if #contextMap ~= #maskMap then
		error(`[ContextSteering] Interest and danger map resolutions don't match! ({#contextMap} ~= {maskMap})`)
	end
	local min = maskMap[1]
	for _, danger in maskMap do
		min = math.min(danger, min)
	end
	
	local maskedContextMap = table.create(#contextMap)
	for i, interest in contextMap do
		maskedContextMap[i] = maskMap[i] <= min and interest or 0
	end
	
	return maskedContextMap
end

-- Internal functions
-- =========================

function CircularIndex(t: {}, i: number): number
	return ( (i - 1) % #t ) + 1
end

--[[
PARAMS
	contextMap <- int-indexed table containing numbers >= 0, #contextMap >= 5
RETURN
	slot, interest <- interpolated fractional max slot, max interest values
NOTES
	Interpolate the fractional slot number with the highest interest value, and the interest value there
	Performs line intersection using adjacent slots (up to two on each side)
]]
function InterpolateMaxSlotAndInterest(contextMap: {number}, maxIdx: number): (number, number)
	if contextMap[maxIdx] == 0 then
		-- a == 0, b == 0, a - b == 0 -> NaN values
		return maxIdx, 0
	end

	local idxL2 = CircularIndex(contextMap, maxIdx - 2)
	local idxL1 = CircularIndex(contextMap, maxIdx - 1)
	-- maxIdx in middle
	local idxR1 = CircularIndex(contextMap, maxIdx + 1)
	local idxR2 = CircularIndex(contextMap, maxIdx + 2)

	-- Line intersection
	-- ax + c = bx + d -> x = (d - c) / (a - b)
	local a = contextMap[idxL2] > 0 and contextMap[idxL1] - contextMap[idxL2] or contextMap[maxIdx] - contextMap[idxL1]
	local b = contextMap[idxR2] > 0 and contextMap[idxR2] - contextMap[idxR1] or contextMap[idxR1] - contextMap[maxIdx]
	-- Find c, d with y = mx + b -> b = y - mx
	-- NOTE: (maxIdx - 1) instead of idxL1 is intended
	--		Using idxL1 produces bug: maxIdx == 1, idxL1 == #map -> returns approx (#map/2, interest)
	local c = contextMap[idxL2] > 0 and contextMap[idxL1] - a * (maxIdx - 1) or contextMap[maxIdx] - a * maxIdx 
	local d = contextMap[idxR2] > 0 and contextMap[idxR1] - b * (maxIdx + 1) or contextMap[maxIdx] - b * maxIdx

	local slot = (d - c) / (a - b)
	local interest = a * slot + c

	return slot, interest
end

return ContextSteering
