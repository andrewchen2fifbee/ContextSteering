--!strict
local CollectionService = game:GetService("CollectionService")

local instances = {}

-- quick whitebox npc setup
for _, npcType: Instance in script:GetChildren() do
	if not npcType:IsA("ModuleScript") then return end
	
	local npcModule = require(npcType)
	instances[npcType] = {}
	
	CollectionService:GetInstanceAddedSignal(npcType.Name):Connect(function(npc)
		if not instances[npcType][npc] then
			instances[npcType][npc] = npcModule.new(npc)
		end
	end)
	
	CollectionService:GetInstanceRemovedSignal(npcType.Name):Connect(function(npc)
		-- npcModule.Destroy(npc)
		instances[npcType][npc] = nil
	end)
	
	for _, npc in CollectionService:GetTagged(npcType.Name) do
		if not instances[npcType][npc] then
			instances[npcType][npc] = npcModule.new(npc)
		end
	end
end
