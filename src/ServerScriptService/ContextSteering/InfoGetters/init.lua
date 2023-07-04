--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local InfoTypes = require(script.InfoTypes)

--[[ DESCRIPTION
Gets information from the world, so behavior functions can use it to help make decisions
TODO desc me
]]
local InfoGetters = {}

-- Return CFrame for all players with (player.Character ~+ nil)
function InfoGetters.GetPlayerCFrames(): {CFrame}
	local cframes: {CFrame} = {}
	
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(cframes, character:GetPivot())
		end
	end
	
	return cframes
end

-- Generic tagged-thing infogetter, supporting PVInstance (BasePart, Model) and Attachment types
function InfoGetters.GetTaggedCFrames(tag: string): {CFrame}
	local cframes: {CFrame} = {}
	
	for _, thing in CollectionService:GetTagged(tag) do
		if thing:IsA("PVInstance") then
			table.insert(cframes, thing:GetPivot())
		elseif thing:IsA("Attachment") then
			table.insert(thing.WorldCFrame)
		else
			warn(`[ContextSteering] GetTaggedCFrames does not support tagged objects of type {thing.ClassName}! Skipping...`)
		end
	end
	
	return cframes
end

function InfoGetters.GetRandomCFramesNearby(npcCFrame: CFrame, numPoints: number, minDistance: number, maxDistance: number): {CFrame}
	local cframes: {CFrame} = {}
	
	for i = 1, numPoints do
		local offsetUnrotated = Vector3.new(0, 0, -math.random(minDistance, maxDistance))
		local offsetRotationY = math.random(0, 2 * math.pi)
		local up = Vector3.new(0, 1, 0)
		local rotationCFrame = CFrame.fromAxisAngle(up, offsetRotationY)
		local offset = rotationCFrame:VectorToWorldSpace(offsetUnrotated)
		table.insert(cframes, npcCFrame + offset)
		-- TODO all generated CFrames currently have same rotation as npcCFrame
	end
	
	return cframes
end

-- Return CFrameAndVelocity for all players with (player.Character ~+ nil and player.Character.PrimaryPart ~= nil)
-- Make sure characters have PrimaryPart set!
function InfoGetters.GetPlayerCFramesAndVelocities(): {InfoTypes.CFrameAndVelocity}
	local cframesandvelocities: {InfoTypes.CFrameAndVelocity} = {}
	
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character.PrimaryPart then
			-- SECURITY NOTE: This is "correct" but wrong, exploit clients can modify their own velocity
			-- Get velocity with a different method if that's an important problem
			local cframeAndVelocity: InfoTypes.CFrameAndVelocity = {
				CFrame = character:GetPivot(),
				Velocity = character.PrimaryPart.AssemblyLinearVelocity
			}
			table.insert(cframesandvelocities, cframeAndVelocity)
		end
	end
	
	return cframesandvelocities
end

-- Generic tagged-thing infogetter, supporting BasePart, Model (sometimes), and Attachment (sometimes) types
-- Make sure Models have PrimaryPart set!
-- Make sure Attachments are parented to a supported type (BasePart, Model w/ PrimaryPart)!
function InfoGetters.GetTaggedCFramesAndVelocities(tag: string): {InfoTypes.CFrameAndVelocity}
	local cframesandvelocities: {InfoTypes.CFrameAndVelocity} = {}
	
	for _, thing in CollectionService:GetTagged(tag) do
		if thing:IsA("Model") then
			if not thing.PrimaryPart then
				continue
			end
			local cframeAndVelocity: InfoTypes.CFrameAndVelocity = {
				CFrame = thing:GetPivot(),
				Velocity = thing.PrimaryPart.AssemblyLinearVelocity
			}
			table.insert(cframesandvelocities, cframeAndVelocity)
		elseif thing:IsA("BasePart") then
			local cframeAndVelocity: InfoTypes.CFrameAndVelocity = {
				CFrame = thing:GetPivot(),
				Velocity = thing.AssemblyLinearVelocity
			}
			table.insert(cframesandvelocities, cframeAndVelocity)
		elseif thing:IsA("Attachment") then
			local parentIsBasePart = thing.Parent and thing.Parent:IsA("BasePart")
			local parentIsValidModel = thing.Parent and thing.Parent:IsA("Model") and thing.Parent.PrimaryPart
			local parentIsSupportedType = parentIsBasePart or parentIsValidModel
			if not parentIsSupportedType then
				continue
			end
			local velocitySource: BasePart = parentIsBasePart and thing.Parent or thing.Parent.PrimaryPart
			local cframeAndVelocity: InfoTypes.CFrameAndVelocity = {
				CFrame = thing.Parent:GetPivot(),
				Velocity = velocitySource.AssemblyLinearVelocity
			}
			table.insert(cframesandvelocities, cframeAndVelocity)
		else
			warn(`[ContextSteering] GetTaggedCFramesAndVelocities does not support tagged objects of type {thing.ClassName}! Skipping...`)
		end
	end

	return cframesandvelocities
end

-- TODO pursuit/evade future position infogetter: will also require knowledge of relative velocity, etc
-- TODO avoidance infogetter: where a thing can have a size radius, or other spatial description, taken into account


-- Internal functions
-- =========================

function FindDescendantWhichIsA(instance: Instance, inheritedClassName: string): Instance?
	for _, descendant: Instance in instance:GetDescendants() do
		if descendant:IsA(inheritedClassName) then
			return descendant
		end
	end
	return nil
end


return InfoGetters
