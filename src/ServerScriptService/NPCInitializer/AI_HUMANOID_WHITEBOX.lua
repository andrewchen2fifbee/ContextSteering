--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ContextSteering = require(ServerScriptService.ContextSteering)
local Behaviors = require(ServerScriptService.ContextSteering.Behaviors)
local BehaviorParams = require(ServerScriptService.ContextSteering.Behaviors.BehaviorParams)
local InfoGetters = require(ServerScriptService.ContextSteering.InfoGetters)

local module = {}

function module.new(npc: Model)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	assert(humanoid)
	
	local self = {
		model = npc,
		humanoid = humanoid,
		rootPart = (npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")) :: BasePart,
		maxSpeed = humanoid.WalkSpeed,
	}
	setmetatable(self, {__index = module})
	
	assert(self.rootPart, "Whitebox NPC missing root part!")
	
	task.spawn(function()
		local t = 0
		while self and self.humanoid do
			t += RunService.Heartbeat:Wait()

			local npcCFrameAndVelocity = {
				CFrame = self.model:GetPivot(),
				Velocity = self.rootPart.AssemblyLinearVelocity
			}
			
			local interests = {} :: {{number}}
			-- table.insert(
			-- 	interests, 
			-- 	Behaviors.Seek(
			-- 		self.model:GetPivot(), 
			-- 		InfoGetters.GetPlayerCFrames(),
			-- 		BehaviorParams.NewGenericParams(
			-- 			{
			-- 				--Resolution = 23,
			-- 				--RangeMin = 10,
			-- 				--RangeMax = 30,
			-- 				--InterestMax = 0.5,
			-- 				--InterestConeArcDegrees = 90,
			-- 				--DistanceFalloffStart = 10,
			-- 				--DistanceFalloffEnd = 40,
			-- 				--DirectionModifierWeightForward = 1,
			-- 				--DirectionModifierWeightRight = 4,
			-- 			}
			-- 		)
			-- 	)
			-- )
			table.insert(
				interests, 
				Behaviors.PursueIterative(
					npcCFrameAndVelocity, 
					InfoGetters.GetPlayerCFramesAndVelocities(),
					BehaviorParams.NewGenericParams()
				)
			)
			
			-- TODO using mock danger map, add danger sensing behavior and test if danger masking works
			local dangers = {}
			table.insert(
				dangers,
				Behaviors.ConstantMap(#interests[1], 0) 
				-- Behaviors.Avoid(
				-- 	npcCFrameAndVelocity,
				-- 	InfoGetters.GetTaggedCFramesAndVelocities("Danger"),
				-- 	BehaviorParams.NewGenericParams()
				-- )
			)
			
			local moveDirection, moveInterest = 
				ContextSteering.CalculateMovement(
					ContextSteering.Mask(
						ContextSteering.Combine(interests), 
						ContextSteering.Combine(dangers)
					)
				)
			
			if moveInterest == 0 then
				self.humanoid.WalkSpeed = self.maxSpeed
				self.humanoid:MoveTo(self.rootPart.Position)
			else
				--self.model:PivotTo(CFrame.new(self.model:GetPivot().Position, self.model:GetPivot().Position + moveDirection) )
				self.humanoid.WalkSpeed = self.maxSpeed --* (moveInterest)
				self.humanoid:MoveTo(self.rootPart.Position + moveDirection * 100)
			end
		end
	end)
	
	return self
end

--[[
function module.Destroy(npc: Instance)
	
end
]]

return module
