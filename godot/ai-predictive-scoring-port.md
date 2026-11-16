# Predictive target steering

Source lock: Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`; Godot base `a2b93d4`.

The original `DefaultContextSteeringProfile2D.asset` predictive-target group contains enabled Pursuit, Arrive, ObstacleAvoidance, Separation and SideStep contributions, all weight 1. The latter three have the same serialized values and ordering as the migrated transit group. This additive module reuses that scoring implementation rather than inventing a chase formula.

- `PursuitSteeringBehaviour2D.cs`: target position plus target velocity times **0.75 seconds**. This is a fixed prediction horizon, not distance divided by current speed.
- `ArriveSteeringBehaviour2D.cs`: actual, nonpredicted target distance determines the speed limit. Stop radius defaults to **0.1**; nonnegative frame arrival radius overrides it, including zero. Slow radius is max(**1.5**, stop + **0.01**). At or inside stop radius the speed is zero, otherwise the interval is clamped to [0,1]. Arrive adds no interest direction.
- `ContextSteeringSolver2D.cs`: direction × max speed × speed scale × strength. A negative max-speed override selects the profile's 1.0. Arrival does not erase directional score arrays.
- All inputs remain Unity XY. Y reflection belongs at the physics/display boundary, not inside scoring.

The test covers moving and stationary targets, prediction coinciding with the observer, slowing boundaries, radius overrides, absence of target, input immutability, shared obstacle/neighbour contributions and velocity scaling. Comparisons use tolerance 1e-5, except the 0.01-wide slow interval at radius 2 where float32 cancellation requires 3e-5. This is not a claim of cross-engine trigonometric bit equality.

Not yet implemented here: actual NPC steering host, dynamic RVO/contact safe velocity, route selection, combat-wander, body facing or full scene acceptance. A successful pure scorer test is not post-attack chase acceptance.
