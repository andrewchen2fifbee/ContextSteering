--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ContextSteering = require(ServerScriptService.ContextSteering)
local Behaviors = require(ServerScriptService.ContextSteering.Behaviors)
local BehaviorParams = require(ServerScriptService.ContextSteering.Behaviors.BehaviorParams)
local InfoGetters = require(ServerScriptService.ContextSteering.InfoGetters)

-- testing pursuit at higher speeds
local module = {}

function module.new(npc: Model)
	local self = {
		model = npc,
		rootPart = (npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")) :: BasePart,
		maxSpeed = npc:GetAttribute("SpeedMax"),
        linearVelocity = npc:FindFirstChild("LinearVelocity", true) :: LinearVelocity,
        alignOrientation = npc:FindFirstChild("AlignOrientation", true) :: AlignOrientation,
	}
	setmetatable(self, {__index = module})
	
	assert(self.rootPart, "HomingProjectile missing root part!")
    assert(self.linearVelocity, "HomingProjectile missing LinearVelocity!")
    assert(self.alignOrientation, "HomingProjectile missing AlignOrientation!")

    self.linearVelocity.VectorVelocity = Vector3.new(0, 0, -self.maxSpeed)
    self.alignOrientation.CFrame = CFrame.new(Vector3.new(), self.linearVelocity.VectorVelocity.Unit)
	
	task.spawn(function()
		local t = 0
		while self and self.model do
			local dt = RunService.Heartbeat:Wait()
            t += dt

			local npcCFrameAndVelocity = {
				CFrame = self.model:GetPivot(),
				Velocity = self.rootPart.AssemblyLinearVelocity
			}

			local interests = {} :: {{number}}
			table.insert(
				interests,
				Behaviors.Pursue(
					npcCFrameAndVelocity,
					InfoGetters.GetPlayerCFramesAndVelocities(),
					BehaviorParams.NewGenericParams(
                        {
                            RangeMax = 2000
                        }
                    )
				)
			)
            
            local dangers = {Behaviors.ConstantMap(#interests[1], 0)}
			
			local moveDirection, moveInterest = 
				ContextSteering.CalculateMovement(
					ContextSteering.Mask(
						ContextSteering.Combine(interests), 
						ContextSteering.Combine(dangers)
					)
				)
			
			if moveInterest == 0 then
                -- fly straight ahead: no change
			else
                -- fly towards movedir
                self.alignOrientation.CFrame = CFrame.new(Vector3.new(), moveDirection)
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
