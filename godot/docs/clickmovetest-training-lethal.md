# ClickMoveTest: training actor lethal hit

This slice follows locked Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`.
The active training target inherits `0_CharacterActor_Base`, 220 HP and the
regular Human directional libraries. The inherited formal death key is
`SpinDie`, not a generic `Death` fallback.

* `CharacterBase.dead` is the live formal HP-zero test; its invincibility
  includes that result immediately. Marking the body as dead in the host is
  later. A second ordinary sourced attack does not apply another hit in this gap.
  The original unresolved/no-source executor branch is not changed.
* CurrentHealth changes of the attached attributes (not just one damage hook)
  drive the positive-to-zero event. The safe stage interrupts actions first,
  rereads HP and destruction, then commits once. The target terminates its
  current voluntary move and uses the authored no-voluntary-movement-after-death
  rule. `ResetMovement` does not invent a cancellation of an already-applied push.
* With the explicitly loaded original trainer contract, the same target's
  AnimationPlayer locks nonlooping SpinDie, then the existing host death callback
  runs without waiting for the animation. There is no fallback animation and no
  automatic removal of the body. Earlier Dmg-only appearance fixtures may still
  be mounted; they do not certify death visuals.
* `tools/extract_training_target_animation.py --include-death` validates the
  inherited state, source clip, original asset metadata and external LFS bytes.
  Verified SpinDie: 1.5 s, 8 fps, 12 original frames per direction and terminal
  repeated key at 1.5 s. The contract and artwork stay private.

Verification: `test_clickmovetest_training_damage.gd` stages a living target
one hit from death and then uses the existing normalized charged attack,
timeline task, real hit area, and formal effect phase. It tests HP-zero admission,
same-phase repeat rejection, safe ordering, movement reset, and single callback.
`FORMAL_TRAINER_DEATH` additionally checks actual original atlas animation and
terminal lock. This does not add the original corpse inventory, reward/kill
notifications, buff cleansing or the full controller/ability teardown, which
still belong to the formal host. No Unity pixel parity is implied.
