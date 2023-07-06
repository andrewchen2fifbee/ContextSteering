--!strict
local Debris = game:GetService("Debris")

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
		
		local differencePos = FlattenVector3(thingInfo.Position - npcInfo.Position)
		
		local distance = differencePos.Magnitude
		if distance < params.RangeMin or distance > params.RangeMax then
			continue
		end
		
		-- Nearby -> higher interest
		local distanceFalloffDistance = math.max(distance - params.DistanceFalloffStart, 0)
		local distanceFalloffRange = params.DistanceFalloffEnd - params.DistanceFalloffStart
		local distanceInterestFraction = DistanceFalloff.Linear(distanceFalloffDistance, 1 / distanceFalloffRange)
		
		-- Which direction are we interested in?
		local directionModifier = Vector3.new(params.DirectionModifierWeightRight, 0, -params.DirectionModifierWeightForward)
		local desiredSlot = CalcDesiredSlot(differencePos, directionModifier, params.Resolution)
		
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

-- Seek predicted future position using an iterative solver to find an approximate intercept point
-- 		Less "optimal" than trigonometry, but feels better in practice
--		May be safer than Behaviors.PursueTrig
function Behaviors.Pursue(npcInfo: InfoTypes.CFrameAndVelocity, thingInfos: {InfoTypes.CFrameAndVelocity}, params: BehaviorParams.GenericParams): {number}
	local interests = table.create(params.Resolution, 0)

	ErrorIfNan(npcInfo, "npcInfo")
	for _, thingInfo in thingInfos do
		ErrorIfNan(thingInfo, "thingInfo")
		
		local differencePos = FlattenVector3(thingInfo.CFrame.Position - npcInfo.CFrame.Position)
		
		local distance = differencePos.Magnitude
		if distance < params.RangeMin or distance > params.RangeMax then
			continue
		end
		
		local npcVelocityFlat = FlattenVector3(npcInfo.Velocity)
		local thingVelocityFlat = FlattenVector3(thingInfo.Velocity)

		local nextDifference: Vector3 = nil
		local nextDistance: number = distance
		for i = 1, 3 do
			local nextT = nextDistance / (npcVelocityFlat.Magnitude + Behaviors.EPSILON)
			local nextThingMovement = nextT * thingVelocityFlat
			local nextPos = FlattenVector3(thingInfo.CFrame.Position + nextThingMovement)
			nextDifference = FlattenVector3(nextPos - npcInfo.CFrame.Position)
			nextDistance = nextDifference.Magnitude
		end

		-- Will sometimes look dumb, but prioritizing closest is good enough
		local distanceFalloffDistance = math.max(distance - params.DistanceFalloffStart, 0)
		local distanceFalloffRange = params.DistanceFalloffEnd - params.DistanceFalloffStart
		local distanceInterestFraction = DistanceFalloff.Linear(distanceFalloffDistance, 1 / distanceFalloffRange)

		local directionModifier = Vector3.new(params.DirectionModifierWeightRight, 0, -params.DirectionModifierWeightForward)
		local desiredSlot = CalcDesiredSlot(nextDifference, directionModifier, params.Resolution)
		
		WriteNearbySlots(interests, desiredSlot, distanceInterestFraction, params.InterestMax, params.InterestConeArcDegrees)
	end

	return interests
end

-- Evade target's predicted future position using an iterative solver to move away from an approximate intercept point
-- 		Less "optimal" than trigonometry, but feels better in practice
--		May be safer than Behaviors.EvadeTrig
function Behaviors.Evade(npcInfo: InfoTypes.CFrameAndVelocity, thingInfos: {InfoTypes.CFrameAndVelocity}, params: BehaviorParams.GenericParams): {number}
	local paramsModified = BehaviorParams.NewGenericParams(params)
	paramsModified.DirectionModifierWeightForward = -paramsModified.DirectionModifierWeightForward
	paramsModified.DirectionModifierWeightRight = -paramsModified.DirectionModifierWeightRight

	return Behaviors.Pursue(npcInfo, thingInfos, paramsModified)
end

-- Seek predicted future position by solving for the best possible target interception (ignoring potential changes in velocity)
function Behaviors.PursueTrig(npcInfo: InfoTypes.CFrameAndVelocity, thingInfos: {InfoTypes.CFrameAndVelocity}, params: BehaviorParams.GenericParams): {number}
	local interests = table.create(params.Resolution, 0)

	ErrorIfNan(npcInfo, "npcInfo")
	for _, thingInfo in thingInfos do
		ErrorIfNan(thingInfo, "thingInfo")
		
		local differencePos = FlattenVector3(thingInfo.CFrame.Position - npcInfo.CFrame.Position)
		
		local distance = differencePos.Magnitude
		if distance < params.RangeMin or distance > params.RangeMax then
			continue
		end

		local npcVelocityFlat = FlattenVector3(npcInfo.Velocity)
		local thingVelocityFlat = FlattenVector3(thingInfo.Velocity)

		-- https://zulko.github.io/blog/2013/11/11/interception-of-a-linear-trajectory-with-constant-speed/
		--		Page LaTeX display is broken. View the page source to see math expressions.
		--		Note: norm == magnitude for vectors
		local farPoint = FlattenVector3(thingInfo.CFrame.Position + 1000 * thingVelocityFlat)
		-- local vecAF = FlattenVector3(farPoint - npcInfo.CFrame.Position)
		local vecBA = FlattenVector3(npcInfo.CFrame.Position - thingInfo.CFrame.Position)
		local vecBF = FlattenVector3(farPoint - thingInfo.CFrame.Position)
		-- local distAF = vecAH.Magnitude
		local distBA = vecBA.Magnitude
		local distBF = vecBF.Magnitude
		
		local determinant = (vecBA.X * vecBF.Z - vecBA.Z * vecBF.X)

		local sinB = determinant / ((distBA * distBF) + Behaviors.EPSILON)
		local sinA = (thingVelocityFlat.Magnitude / (npcVelocityFlat.Magnitude + Behaviors.EPSILON)) * sinB
		local sinC = (sinA * math.sqrt(1 - sinB * sinB)) + (sinB * math.sqrt(1 - sinA * sinA))
		local distBC = distBA * sinA / (sinC + Behaviors.EPSILON)
		
		local direction: Vector3 = nil
		local canIntercept = distBC == distBC --math.abs(sinA) <= 1
		if not canIntercept then
			-- Can't intercept yet, run parallel for now
			direction = SafeUnitVector3(thingVelocityFlat)
			direction = direction.Magnitude > 0 and direction or differencePos
		else
			local interceptPoint = thingInfo.CFrame.Position + distBC * SafeUnitVector3(vecBF) 
			direction = FlattenVector3(interceptPoint - npcInfo.CFrame.Position)
		end
		
		-- Will sometimes look dumb, but prioritizing closest is good enough
		local distanceFalloffDistance = math.max(distance - params.DistanceFalloffStart, 0)
		local distanceFalloffRange = params.DistanceFalloffEnd - params.DistanceFalloffStart
		local distanceInterestFraction = DistanceFalloff.Linear(distanceFalloffDistance, 1 / distanceFalloffRange)

		local directionModifier = Vector3.new(params.DirectionModifierWeightRight, 0, -params.DirectionModifierWeightForward)
		local desiredSlot = CalcDesiredSlot(direction, directionModifier, params.Resolution)
		
		WriteNearbySlots(interests, desiredSlot, distanceInterestFraction, params.InterestMax, params.InterestConeArcDegrees)
	end

	return interests
end

-- Evade target's future position by moving away from the expected interception point (ignoring potential changes in velocity)
function Behaviors.EvadeTrig(npcInfo: InfoTypes.CFrameAndVelocity, thingInfos: {InfoTypes.CFrameAndVelocity}, params: BehaviorParams.GenericParams): {number}
	local paramsModified = BehaviorParams.NewGenericParams(params)
	paramsModified.DirectionModifierWeightForward = -paramsModified.DirectionModifierWeightForward
	paramsModified.DirectionModifierWeightRight = -paramsModified.DirectionModifierWeightRight

	return Behaviors.PursueTrig(npcInfo, thingInfos, paramsModified)
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
function CalcDesiredSlot(direction: Vector3, directionModifier: Vector3, numSlots: number)
	local playerAngleRadians = CalcYRotationAngleRad(direction)
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
--	Returns 0 when FlattenVector3(vector) == Vector3.new(0, 0, 0)
function CalcYRotationAngleRad(vector: Vector3): number
	return Behaviors.FORWARD:Angle(FlattenVector3(vector), Behaviors.UP)
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
		local typename = typeof(thing) == "Instance" and thing.ClassName or typeof(thing)
		error(`[ContextSteering] {name} ({typename}) is/contains NaN! Contents: {thing}`)
	end
end

-- Onto XZ plane
function FlattenVector3(vec: Vector3): Vector3
	return Vector3.new(vec.X, 0, vec.Z)
end

-- Avoid NaN from Vector3(0, 0, 0).Unit
function SafeUnitVector3(vec: Vector3): Vector3
	return vec.Magnitude > 0 and vec.Unit or vec
end

function lerp(x: number, start: number, finish: number): number
	return start + x * (finish - start)
end

-- Debug visuals
-- =========================

function DebugDrawBeam(start: Vector3, finish: Vector3, color: Color3?, lifetime: number?)
	local _color = color or Color3.new(1, 0, 0)
	local _lifetime = lifetime or 0.25
	
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Transparency = 1
	local att0 = Instance.new("Attachment")
	att0.Position = start
	att0.Parent = part
	local att1 = Instance.new("Attachment")
	att1.Position = finish
	att1.Parent = part
	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Color = ColorSequence.new(_color)
	beam.FaceCamera = true
	beam.Parent = part
	
	Debris:AddItem(part, _lifetime)
	part.Parent = workspace
end

return Behaviors
