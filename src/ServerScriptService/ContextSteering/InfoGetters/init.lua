--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local InfoTypes = require(script.InfoTypes)

--[[ DESCRIPTION
Functions which get information from the world, so behavior functions can use that information to make decisions.
If you want to get information from the workspace, this is the place to do it.
]]
local InfoGetters = {}

--[[
PARAMS
	none
RETURN
	cframes <- table of CFrames for all players with (player.Character ~= nil)
]]
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

--[[
PARAMS
	tag <- string ContextService tag for which you want tagged Instance CFrames
RETURN
	cframes <- table of CFrames for all supported types of tagged Instance
NOTES
	Supported types: PVInstance (BasePart, Model), Attachment
]]
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

--[[
PARAMS
	npcCFrame <- CFrame to get random points around
	numPoints <- how many random points to get
	minDistance <- random points are at least this far away, in studs
	maxDistance <- random points are at most this far away, in studs
RETURN
	cframes <- table of randomly placed nearby CFrames, on the same horizontal plane that npcCFrame is on
		(npcCFrame.Position.Y = randomCFrame.Position.Y)
]]
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

--[[
PARAMS
	none
RETURN
	cframesAndVelocities <- table of CFrameAndVelocitys for all players with 
		(player.Character ~= nil and player.Character.PrimaryPart ~= nil)
]]
function InfoGetters.GetPlayerCFramesAndVelocities(): {InfoTypes.CFrameAndVelocity}
	local cframesAndVelocities: {InfoTypes.CFrameAndVelocity} = {}
	
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character.PrimaryPart then
			-- SECURITY NOTE: This is "correct" but wrong, exploit clients can modify their own velocity
			-- Get velocity with a different method if that's an important problem
			local cframeAndVelocity: InfoTypes.CFrameAndVelocity = {
				CFrame = character:GetPivot(),
				Velocity = character.PrimaryPart.AssemblyLinearVelocity
			}
			table.insert(cframesAndVelocities, cframeAndVelocity)
		end
	end
	
	return cframesAndVelocities
end

--[[
PARAMS
	tag <- string ContextService tag for which you want tagged Instance CFrameAndVelocitys
RETURN
	cframesAndVelocities <- table of CFrameAndVelocitys for all supported types of tagged Instance
NOTES
	Supported types: 
		BasePart, 
		Model (requires Model.PrimaryPart ~= nil), 
		Attachment (requires Attachment.Parent:IsA("BasePart") or Attachment.Parent:IsA("Model"))
]]
function InfoGetters.GetTaggedCFramesAndVelocities(tag: string): {InfoTypes.CFrameAndVelocity}
	local cframesAndVelocities: {InfoTypes.CFrameAndVelocity} = {}
	
	for _, thing in CollectionService:GetTagged(tag) do
		if thing:IsA("Model") then
			if not thing.PrimaryPart then
				continue
			end
			local cframeAndVelocity: InfoTypes.CFrameAndVelocity = {
				CFrame = thing:GetPivot(),
				Velocity = thing.PrimaryPart.AssemblyLinearVelocity
			}
			table.insert(cframesAndVelocities, cframeAndVelocity)
		elseif thing:IsA("BasePart") then
			local cframeAndVelocity: InfoTypes.CFrameAndVelocity = {
				CFrame = thing:GetPivot(),
				Velocity = thing.AssemblyLinearVelocity
			}
			table.insert(cframesAndVelocities, cframeAndVelocity)
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
			table.insert(cframesAndVelocities, cframeAndVelocity)
		else
			warn(`[ContextSteering] GetTaggedCFramesAndVelocities does not support tagged objects of type {thing.ClassName}! Skipping...`)
		end
	end

	return cframesAndVelocities
end

-- TODO avoidance infogetter: may want to know about object radius, or other spatial description, to avoid something


-- Internal functions
-- =========================
-- n/a

return InfoGetters
