--!strict

-- !! THIS MODULE USES DEGREES, NOT RADIANS !!
-- Apply additional clamping, falloff start ranges, etc to returned results
local AngularFalloff = {}

function AngularFalloff.Linear(angularDistanceDegrees: number, falloffPerDegree: number)
	return math.clamp(1 - (angularDistanceDegrees * falloffPerDegree), 0, 1)
end

return AngularFalloff
