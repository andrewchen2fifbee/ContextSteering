--!strict

-- Apply additional clamping, falloff start ranges, etc to returned results
local DistanceFalloff = {}

function DistanceFalloff.Linear(distanceStuds: number, falloffPerStud: number)
	return math.clamp(1 - (distanceStuds * falloffPerStud), 0, 1)
end

return DistanceFalloff
