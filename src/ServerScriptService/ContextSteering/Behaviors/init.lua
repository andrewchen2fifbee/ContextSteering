--!strict
local DistanceFalloff = require(script.Parent.DistanceFalloff)
local AngularFalloff = require(script.Parent.AngularFalloff)
local InfoTypes = require(script.Parent.InfoGetters.InfoTypes)
local BehaviorParams = require(script.BehaviorParams)

--[[ DESCRIPTION
A collection of movement behaviors, used to help make context steering decisions. 
Returned interest maps can be used to indicate either interest or danger. 

Most behaviors follow this general format.
	Some are special (ex. EmptyMap only takes map resolution number)
PARAMS
	npcInfo <- information the NPC needs to know about itself to make this decision
	thingInfos <- information the NPC needs to know about the things it cares about to make this decision
	params <- behavior-specific type of table containing needed parameters
RETURN
	interests <- how interested (or afraid) the NPC is in the directions around it
]]

-- TODO additional behaviors
local Behaviors = {}

Behaviors.EPSILON = 1e-6 -- arbitrary small fudging number

Behaviors.FORWARD = Vector3.new(0, 0, -1)
Behaviors.RIGHT = Vector3.new(1, 0, 0)
Behaviors.UP = Vector3.new(0, 1, 0)

-- For those times when you need to pass an empty interest map (all slots 0)
function Behaviors.ConstantMap(resolution: number, value: number): {number}
	return table.create(resolution, value)
end

-- With default direction modifiers (Forward == 1, Right == 0), move towards things
function Behaviors.Seek(npcInfo: CFrame, thingInfos: {CFrame}, params: BehaviorParams.GenericParams): {number}
	-- Guarantee returned interest map has correct size, when #thingInfos == 0
	local interests = table.create(params.Resolution, 0)
	
	ErrorIfNan(npcInfo, "npcInfo")
	for _, thingInfo in thingInfos do
		ErrorIfNan(thingInfo, "thingInfo")
		
		local differencePos = thingInfo.Position - npcInfo.Position
		local differencePosFlat = Vector3.new(differencePos.X, 0, differencePos.Z)
		
		local distance = differencePosFlat.Magnitude
		if distance < params.RangeMin or distance > params.RangeMax then
			continue
		end
		
		-- Nearby -> higher interest
		local distanceFalloffDistance = math.max(distance - params.DistanceFalloffStart, 0)
		local distanceFalloffRange = params.DistanceFalloffEnd - params.DistanceFalloffStart
		local distanceInterestFraction = DistanceFalloff.Linear(distanceFalloffDistance, 1 / distanceFalloffRange)
		
		-- Which direction are we interested in?
		local directionModifier = Vector3.new(params.DirectionModifierWeightRight, 0, -params.DirectionModifierWeightForward)
		local desiredSlot = CalcDesiredSlot(differencePosFlat, directionModifier, params.Resolution)
		
		WriteNearbySlots(interests, desiredSlot, distanceInterestFraction, params.InterestMax, params.InterestConeArcDegrees)
	end
	
	return interests
end

-- With default direction modifiers, move away from things
function Behaviors.Flee(npcInfo: CFrame, thingInfos: {CFrame}, params: BehaviorParams.GenericParams): {number}
	local paramsModified = BehaviorParams.NewGenericParams(params)
	paramsModified.DirectionModifierWeightForward = -paramsModified.DirectionModifierWeightForward
	paramsModified.DirectionModifierWeightRight = -paramsModified.DirectionModifierWeightRight

	return Behaviors.Seek(npcInfo, thingInfos, paramsModified)
end

-- TODO impl
--function Behaviors.Orbit(...): {number}
--	assert(false, "func unimplemented")

--	local interests = {}

--	return interests
--end

-- Seek predicted future position, based on relative velocity / relative distance
function Behaviors.Pursue(npcInfo: InfoTypes.CFrameAndVelocity, thingInfos: {InfoTypes.CFrameAndVelocity}, params: BehaviorParams.GenericParams): {number}
	local futureThingCFrames: {CFrame} = {}

	ErrorIfNan(npcInfo, "npcInfo")
	for _, thingInfo in thingInfos do
		ErrorIfNan(thingInfo, "thingInfo")
		
		-- the missile knows where it is because it knows where it isn't
		local differencePos = thingInfo.CFrame.Position - npcInfo.CFrame.Position
		local differencePosFlat = Vector3.new(differencePos.X, 0, differencePos.Z)
		
		local distance = differencePosFlat.Magnitude
		if distance < params.RangeMin or distance > params.RangeMax then
			continue
		end
		
		-- The predicted future position can be outside of RangeMax, in which case the thing is ignored
		-- TODO based on distance, dVel: get a nicer approx time-to-target
		-- local differenceVel = thingInfo.Velocity - npcInfo.Velocity
		-- local differenceVelFlat = Vector3.new(differenceVel.X, 0, differenceVel.Z)

		-- TEMP: good enough for now
		local t: number = distance / npcInfo.Velocity.Magnitude
		local cframe = thingInfo.CFrame + t * thingInfo.Velocity
		table.insert(futureThingCFrames, cframe)
		
		-- TODO eventually do calcs instead of use seek, for better behavior
	end

	-- that's right! the square hole! https://www.youtube.com/watch?v=cUbIkNUFs-4
	return Behaviors.Seek(npcInfo.CFrame, futureThingCFrames, params)
end

function Behaviors.Evade(npcInfo: InfoTypes.CFrameAndVelocity, thingInfos: {InfoTypes.CFrameAndVelocity}, params: BehaviorParams.GenericParams): {number}
	local paramsModified = BehaviorParams.NewGenericParams(params)
	paramsModified.DirectionModifierWeightForward = -paramsModified.DirectionModifierWeightForward
	paramsModified.DirectionModifierWeightRight = -paramsModified.DirectionModifierWeightRight

	return Behaviors.Pursue(npcInfo, thingInfos, paramsModified)
end

function Behaviors.Avoid(npcInfo: InfoTypes.CFrameAndVelocity, thingInfos: {InfoTypes.CFrameAndVelocity}, params: BehaviorParams.GenericParams): {number}
	-- TODO impl
	assert(false, "func unimplemented")

	local interests = {}

	-- for ... in ... do ... end

	return interests
end

-- Internal functions
-- =========================

-- Given a vector pointing from NPC to target, and a vector describing the direction the NPC wants to move relative to target...
--	... for an interest map with numSlots slots, return the slot number matching the desired movement direction for that target
function CalcDesiredSlot(differencePos: Vector3, directionModifier: Vector3, numSlots: number)
	local playerAngleRadians = CalcYRotationAngleRad(differencePos.Unit)
	local modifierAngleRadians = CalcYRotationAngleRad(directionModifier)
	local slotAngleRadians = (playerAngleRadians + modifierAngleRadians) % (2 * math.pi)
	return RadToSlot(slotAngleRadians, numSlots)
end

-- Write interest values with included angular falloff to an interest map
-- If the interest value for a slot is less than the existing value, nothing changes in that slot
function WriteNearbySlots(interests: {number}, desiredSlot: number, interestFraction: number, interestMax: number, arcDegrees: number): ()
	local maxAngle = arcDegrees / 2
	for i = 1, #interests do
		local slotAngleDegrees = CalcSlotAngleDeg(desiredSlot, i, #interests)
		local angularInterestLerpFraction = AngularFalloff.Linear(slotAngleDegrees, 1 / maxAngle)
		local lerpFraction = interestFraction * angularInterestLerpFraction
		local slotInterest = lerp(lerpFraction, 0, interestMax)
		interests[i] = math.max(slotInterest, interests[i])
	end
end

-- Get the y axis rotation angle needed, in radians, for...
--	...for a new vector to line up with existing vector, when projected onto the horizontally flat XZ plane
--	Returns 0 when vectorFlat == Vector3.new(0, 0, 0)
function CalcYRotationAngleRad(vector: Vector3): number
	local vectorFlat = Vector3.new(vector.X, 0, vector.Z)
	return Behaviors.FORWARD:Angle(vectorFlat, Behaviors.UP)
end

-- Calculate shortest angle between the two slots, in degrees
function CalcSlotAngleDeg(a: number, b: number, numSlots: number): number
	-- slotAngleSlots is, in fact, measured in slots
	local slotAngleSlots = math.min(
		-- There's probably a better way to do this, but this is good enough 
		-- Doesn't work for all a, b: Keep a - b in [-1.5 * numSlots, 1.5 * numSlots]
		math.abs(a - b),
		math.abs(a - b + numSlots),
		math.abs(a - b - numSlots)
	)
	return slotAngleSlots / numSlots * 360
end

-- Convert an angle, in radians, into the corresponding context map slot number
-- Fractional slots allowed as floats, range [1, resolution + 0.99...)
-- 		When slot > resolution: is between the first and last slots, almost a full rotation
function RadToSlot(angleRadians: number, numSlots: number): number
	local slot = ( (angleRadians / (2 * math.pi) ) * numSlots) + 1
	if slot >= numSlots + 1 then
		error(`Slot {slot} exceeds upper bound {numSlots + 0.99}...! (angleRadians is {angleRadians})`)
	end
	return slot
end

function ErrorIfNan<T>(thing: T, name: string): ()
	if thing ~= thing then
		error(`[ContextSteering] {name} is/contains NaN!`)
	end
end

function lerp(x: number, start: number, finish: number): number
	return start + x * (finish - start)
end

return Behaviors
