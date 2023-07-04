--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

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
	thingInfos <- invormation the NPC needs to know about the things it cares about to make this decision
	params <- behavior-specific type of table containing needed parameters
RETURN
	interests <- how interested (or afraid) the NPC is in the directions around it
]]

-- TODO eventually support custom distance + angle falloff functions, etc
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
	local resolution = params.Resolution
	local interestConeArcDegrees = params.InterestConeArcDegrees
	local maxRange = params.RangeMax
	
	-- guarantee returned interest map has correct size, when #thingInfos == 0
	local interests = table.create(resolution, 0)
	
	if npcInfo ~= npcInfo then
		error(`[ContextSteering] Behavior cannot use npcInfo containing NaN!`)
	end
	for _, thingInfo in thingInfos do
		if thingInfo.Position ~= thingInfo.Position then
			error(`[ContextSteering] Behavior cannot use thingInfo containing NaN!`)
		end
		
		local difference = thingInfo.Position - npcInfo.Position
		local differenceFlat = Vector3.new(difference.X, 0, difference.Z)
		
		local distance = differenceFlat.Magnitude
		if distance < params.RangeMin or distance > params.RangeMax then
			continue
		end
		
		-- Nearby -> higher interest
		local distanceFalloffDistance = math.max(distance - params.DistanceFalloffStart, 0)
		local distanceFalloffRange = params.DistanceFalloffEnd - params.DistanceFalloffStart
		local distanceInterestLerpFraction = DistanceFalloff.Linear(distanceFalloffDistance, 1 / distanceFalloffRange)
		
		-- Which direction are we interested in?
		local playerAngleRadians = getYRotationAngleRad(differenceFlat.Unit)
		local desiredSlotRaw = radToSlot(playerAngleRadians, resolution)

		local directionModifier = Vector3.new(params.DirectionModifierWeightRight, 0, -params.DirectionModifierWeightForward)
		local desiredSlotModifier = radToSlot(Behaviors.FORWARD:Angle(directionModifier, Behaviors.UP), resolution) - 1
		local desiredSlot = desiredSlotRaw + desiredSlotModifier
		
		-- Write interest to slots
		local maxAngle = params.InterestConeArcDegrees / 2
		for i = 1, resolution do
			local slotAngleDegrees = calcSlotAngleDeg(desiredSlot, i, resolution)
			local angularInterestLerpFraction = AngularFalloff.Linear(slotAngleDegrees, 1 / maxAngle)
			local lerpFraction = distanceInterestLerpFraction * angularInterestLerpFraction
			local slotInterest = lerp(lerpFraction, 0, params.InterestMax)
			interests[i] = slotInterest
		end
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

--function Behaviors.OrbitPlayers(position: Vector3, orbitDistance: number): {number}
--	-- TODO impl
--	assert(false, "func unimplemented")

--	local interests = {}

--	for _, player in Players:GetPlayers() do

--	end

--	return interests
--end

-- TODO Pursue/Evade -> takes relative velocity into account

-- TODO should this use CFrameAndVelocity, or CFrame + developer handling interpolating to future positions manually?
function Behaviors.Avoid(npcInfo: InfoTypes.CFrameAndVelocity, thingInfos: {InfoTypes.CFrameAndVelocity}): {number}
	-- TODO impl
	assert(false, "func unimplemented")

	local interests = {}

	-- for ... in ... do ... end

	return interests
end

-- Internal functions
-- =========================

-- Get the y axis rotation angle needed, in radians, for...
--	...for a new vector to line up with existing vector, when projected onto the horizontally flat XZ plane
--	Returns 0 when vectorFlat == Vector3.new(0, 0, 0)
function getYRotationAngleRad(vector: Vector3): number
	local vectorFlat = Vector3.new(vector.X, 0, vector.Z)
	return Behaviors.FORWARD:Angle(vectorFlat, Behaviors.UP)
end

-- Convert an angle, in radians, into the corresponding context map slot number
-- Fractional slots allowed as floats, range [1, resolution + 0.99...)
-- 		When slot > resolution: is between the first and last slots, almost a full rotation
function radToSlot(angleRadians: number, numSlots: number)
	local slot = ( (angleRadians / (2 * math.pi) ) * numSlots) + 1
	assert(slot < numSlots + 1, `Slot {slot} exceeds upper bound {numSlots + 1}! (angleRadians is {angleRadians})`)
	return slot
end

-- Calculate shortest angle between the two slots, in degrees
function calcSlotAngleDeg(a: number, b: number, numSlots: number): number
	-- slotAngleSlots is, in fact, measured in slots
	local slotAngleSlots = math.min(
		-- There's probably a better way to do this, but this is good enough 
		-- Doesn't work for all a, b: Keep a, b in [0, numSlots + 1)
		math.abs(a - b),
		math.abs(a - b + numSlots),
		math.abs(a - b - numSlots)
	)
	return slotAngleSlots / numSlots * 360
end

function lerp(x: number, start: number, finish: number): number
	return start + x * (finish - start)
end

return Behaviors
