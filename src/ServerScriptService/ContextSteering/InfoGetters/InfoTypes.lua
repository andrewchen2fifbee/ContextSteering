--!strict

--[[ DESCRIPTION
Custom thing-information type definitions.
For use in InfoGetters, and any modules which work with return values from InfoGetters (ex. Behaviors).
]]

export type CFrameAndVelocity = {
	CFrame: CFrame,
	Velocity: Vector3,
}

export type PhysicalDescriptor = {
	CFrame: CFrame,
	Velocity: Vector3,
	Acceleration: Vector3,
	SpeedMax: number,
	AccelerationMax: number,
	Radius: number, -- always treated as a cylinder
	Importance: number, -- TODO maybe keep + use in future to modify interest returns?
}

return nil
