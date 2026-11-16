# Damage action driver / recovery slice

Source lock: Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`.
Base migration: `907e19bb7fbf4489eaa95db6db252a01794d779e`.

## Implemented

`game_core/presentation/character_action_animator_driver.gd` translates the
runtime playback/restore subset of
`Assets/Scripts/Gameplay/Runtime/Presentation/EquipmentSystem/Runtime/CharacterActionAnimatorDriver.cs`:

- Require both an action database entry and an existing native AnimationPlayer
  animation. Resolve action name, then `Base Layer.` name. Missing states fail;
  never create a substitute animation or silently fall back.
- Play from zero and evaluate immediately; Dmg schedules restoration from the
  **currently assigned native clip's length**, not a universal damage constant.
- NaN/infinite/length < 0.05 seconds uses source fallback 0.35 seconds. A valid
  length of exactly 0.05 is retained. Editor/preview mode has no restore timer.
- Pending fallback initially uses default Idle, exactly as source does, even
  when the previous movement intent was nonzero. Later movement callbacks update
  it to Idle/Walk (`squared magnitude > 0.0001`). Movement does not steal damage,
  attack or other non-locomotion state ownership.
- At the scaled-time deadline, restore only if current action still matches the
  pending key; then clear pending state even if fallback playback failed.
- Repeated damage replays/reschedules; successful explicit action selection
  cancels pending restore, failed selection does not. Death/action locks retain
  the source acknowledgment behavior without replacing the locked animation.

The Node uses scaled Godot `_process(delta)` time. Its explicit clock advance
method permits deterministic tests without wall-clock sleeps. AnimationPlayer
is the playback authority; no fabricated current-action timer replaces it.

## Verified authored ownership, not a guessed Human animation

The following chain was inspected in the locked Unity Git objects:

1. `Assets/Prefabs/Entities/Characters/Heroes/玩家角色.prefab` inherits
   `0_CharacterActor_Base.prefab` (GUID `5865f29bb760d4342b20bf32a1e06ca8`).
2. Actor base's formal driver points to stripped Animator fileID
   `7513719263223177368`, source Animator `8844624622341381040` in
   `0_Character_Base.prefab` (GUID `35b65aa833459fb48a5da6b625c71835`).
3. Crucially, actor base **overrides** that nested Animator's controller to GUID
   `0be334fca6154804592795b046bebf5c`. Reading only the nested base controller
   would select the wrong controller.
4. That GUID resolves to
   `Assets/GameData/EquipmentSystem/Animations/换装共享动画状态机.controller`.
   Its Dmg state has speed 1, no active speed parameter, no transitions, and
   motion GUID `93990ba6069fc524f8a272cc3f1a533c`.
5. Motion resolves to `SharedClips/Dmg.anim`: sample rate 8, stop time 0.5,
   authored float-curve keys at 0, 0.125, 0.25, 0.375 and 0.5 seconds.
   These float values encode SpriteResolver labels, not ordinary sprite indices.

This slice does **not** publish/copy those clips, raw assets, or float/hash data.
The native test uses empty test clips (Dmg length 0.5 from the verified metadata).
They prove selection, real AnimationPlayer timing and recovery control flow,
not original sprite playback or pixel parity.

## Integration and acceptance still outstanding

`CharacterActor.TryPlayHitAnimation` dispatches to the formal driver; a configured
but failing driver reports an error and does not silently use the legacy driver.
`CharacterBase.Resources.PrepareFormalDamageHit` invokes hit animation before HP
change for non-silent damage. This slice does not yet wire that actor preparation
hook into the NPC diagnostic: it must be connected only with verified action
resources. Nor does this slice migrate the equipment/SpriteResolver rendering,
actual sprite timelines, shadow controls, editor preview, full action database
import or original authored scene. Existing rectangle fixtures remain diagnostics.

The post-attack chase validator still requires actual Dmg observation, recovery,
movement availability, retained target and displacement/distance after relocation.
These driver tests alone do not satisfy that end-to-end acceptance and must not
be reported as a completed FantasyWord migration.

Run `GODOT=/path/to/godot bash godot/tests/run.sh`. The new suite tests native
playback and deadline boundaries, locomotion non-interruption, repeat hits,
missing states/fallback, lock behavior, preview suppression, invalid durations,
and reading a changed native clip length rather than hardcoding 0.5 seconds.

Native playback explicitly seeks to zero after `play()`: unlike Unity's
`Play(state, 0, 0f)`, repeating Godot `play(state)` alone need not rewind.
The repeated-hit regression advances actual native playback to 0.3 before
replaying Dmg and checks it returned to zero. Float32 Unity `Time.time`
rounding after long uptime is not emulated by the Godot double-precision clock.

Final local validation: all 40 Godot suites passed, including 30 checks in the
new native driver suite. This is module/diagnostic coverage, not source-scene
or original rendering acceptance.
