--!strict

--[[ DESCRIPTION
Custom thing-information type definitions.
For use in InfoGetters, and any modules which work with return values from InfoGetters (ex. Behaviors).
TODO IS THIS USEFUL?
	Figure out if want to use this
	Alternative: Interpolate to various future points w/ different interest weights
]]

export type CFrameAndVelocity = {
	CFrame: CFrame,
	Velocity: Vector3,
}

return nil
