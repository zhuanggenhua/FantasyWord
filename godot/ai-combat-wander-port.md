# Combat wander: decision and intent slice

Baseline: `907e19bb7fbf4489eaa95db6db252a01794d779e`. Original Unity source: `31629d53a110dd4c87d4c85e6ad5a387fbafb931`.

Source correspondence:
- `Assets/Scripts/GameCore/Runtime/Controllers/CombatWanderRuntime2D.cs`: `ShouldUse`, `Tick`, `Reset` map to `game_core/ai/combat_wander_intent.gd`.
- `Assets/ProjectPlugins/ContextSteering2D/Runtime/SteeringWanderIntent2D.cs`: immutable-value intent sign/distance normalization.
- `Assets/Scripts/GameCore/Runtime/Controllers/AIController.BehaviourRuntime.cs`: `ApplyMovement` chooses combat wander **before** final approach or navigation resolution. `Stop` resets the cached intent.

Implemented boundary: pure branch selection and persistent intent generation. The caller supplies enabled/target state, distance to the controller's stored destination, authored ranges and resolved waypoint tolerance. No scene-specific constants are invented. Branch selection does not query navigation: an unavailable path must not prevent the earlier wander branch. Target position can remain last-known during the source sight-lost grace period; do not replace it with an omniscient live position.

Wander receives `Time.fixedDeltaTime` equivalent only while its movement branch executes. This is separate from the lifecycle sight-lost `Time.deltaTime` clock. Subtract clamped nonnegative delta using binary32 arithmetic. Renew on no intent or timer <= 0, setting the source 1.5-second interval without catch-up. A renewal requests Random.value then Random.Range, including equal range endpoints. Strict value > 0.5 chooses +1; otherwise -1. Attack range clamps to zero and maximum cannot be below minimum. Random providers are injected: no claim of Unity PRNG equivalence. Returning a copy preserves the source value-type cache semantics.

Validation: `tests/test_combat_wander_intent.gd` checks inclusive range/arrival boundaries, target requirement, precedence, random order/tie, constructor normalization, timer resets and binary32 decrements, negative/oversized delta, equal/clamped ranges, and cache isolation.

Not implemented/accepted by this slice: CombatWanderSteeringBehaviour2D obstacle-adjusted lateral interest, full profile-group composition, body movement, facing, actual NPC near-combat presentation, Unity screenshot comparison. Existing NPC fixtures are deliberately not wired to a partial wander solver. Passing these isolated checks is not full migration acceptance.
