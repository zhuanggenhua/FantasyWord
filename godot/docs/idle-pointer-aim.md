# Idle pointer aim: source target/body split
Locked Unity source: `31629d53a110dd4c87d4c85e6ad5a387fbafb931`.

`Movable.MotionRuntime.HasActiveMovementIntent` includes raw direction above the source idle threshold, any outstanding MoveOrder, push order, or last successful movement squared above .0001. The native motion body now exposes this predicate instead of equating “idle” with zero current velocity.

`idle_pointer_aim.gd` maps CharacterMovement.TryUpdateIdlePointerTargetDirection and the target-update branch of CharacterPlayerControl.Update. Its explicit host supplies the actual body, target owner, authored world pivot, enabled flag, active gameplay pointer and current Camera2D. The caller must already have passed current-player identity, local-control, capability and interaction-refresh gates. Forbidden target updates preserve overrides. Eligible failed probes reset them. This is not the entire CharacterPlayerControl lifecycle and does not install itself in the scene.

`movable_direction_state.gd` separately owns body facing and optional target direction. MovementBased skill aim cannot change body facing. TargetBased can. Reset removes the override and only publishes the nonzero source-facing direction above its source threshold. These state signals do not implement animation strategy or GAS routing.

The base Actor sets pointer aim on and refers to Static Pivot, but that pivot is inherited through nested prefab parents. Its local (0,.4) is not a proven world/root offset. This slice deliberately requires the actual resolved pivot node rather than adding an invented root offset or visual Body offset to ClickMoveTest. The full effective source hierarchy and formal owner scheduling remain to be integrated.

Native test `test_idle_pointer_aim.gd` dispatches InputEventMouseMotion into a real viewport, projects through its actual Camera2D transform and uses a parented pivot fixture. It checks body/aim divergence, blocked-update retention, outstanding MoveOrder reset, inactive pointer, idle threshold and TargetBased behavior. The fixture pivot is explicitly not claimed as the source hierarchy. No screenshot or whole-game completion claim.
