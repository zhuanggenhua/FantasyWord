# Proposal: realign-character-equipment-composition

## Problem

The current character composition migration exposed several prefab-visible components, but the equipment boundary is still misleading:

- `CharacterHandleWeapon` currently owns the RPG equipment loadout, equipment-granted abilities, equipment stat contribution, suppression rules, and equipment save snapshots.
- `CharacterHandleWeapon` is still `Hero`-bound, while TopDown's `CharacterHandleWeapon` is a character weapon-handling ability and not a full RPG equipment system.
- `InventorySystem` still resolves equipment targets through `Hero`, so character equipment remains player-hero-specific even though the product target requires controllable characters, party members, NPCs, transformations, infection, corpse transfer, and RTS-style control.

This is not a reason to replace the whole foundation. The correction is narrower: preserve the RPG equipment system, but expose it as a proper character-owned component and keep TopDown as a component-structure reference, not as a business-logic replacement.

## Scope

This change covers:

- Creating a formal `CharacterEquipment` boundary for RPG equipment slots, stat contribution, equipment-granted abilities, suppression rules, and equipment persistence orchestration.
- Narrowing `CharacterHandleWeapon` back toward the TopDown-like weapon handling boundary: current/held weapon execution and weapon presentation, not full RPG equipment slot ownership.
- Removing `Hero` as the required equipment target for runtime equipment operations.
- Removing obsolete `Hero` public equipment APIs after callers have moved to the formal equipment boundary.
- Updating prefab composition so equipment ownership is visible as a character component.
- Updating documentation and validation so TopDown "ability component" means character function module, not one MonoBehaviour per RPG/GAS ability asset.

## Out Of Scope

- Do not replace `CharacterAbilitySet` or split every `AbilitySheet` into a MonoBehaviour.
- Do not import TopDown `InventoryEngine`, `InputManager`, `Health`, `GameManager`, `LevelManager`, or `GUIManager` as formal runtime truth.
- Do not implement networking, ECS, or a new world simulation layer.
- Do not redesign item content, equipment types, UI art, or balance data.
- Do not rename `Hero` in this change unless a later change explicitly handles serialized prefab and save compatibility.

## Reference Matrix

| Reference | Evidence | What It Proves | What It Does Not Prove | FantasyWord Decision |
| --- | --- | --- | --- | --- |
| TopDown `Koala.prefab` | `TopDownController2D`, `Character`, `CharacterMovement`, `CharacterHandleWeapon`, `CharacterInventory`, `CharacterButtonActivation` are separate components | Character function boundaries should be prefab-visible | RPG equipment slots should be copied from TopDown | Use as component-structure reference |
| TopDown `CharacterHandleWeapon.cs` | Comment says it describes the hand holding the weapon; fields include `InitialWeapon`, `WeaponAttachment`, `CurrentWeapon`, firing/buffering/feedback | Weapon handling should be a character module | Full RPG equipment loadout, stats, granted abilities, save slots belong there | Narrow our `CharacterHandleWeapon` to weapon handling |
| TopDown `CharacterInventory.cs` + `InventoryWeapon.cs` | Main/weapon/hotbar inventory names; `InventoryWeapon` equips through `CharacterHandleWeapon` | Character inventory and weapon inventory are separate visible responsibilities | TopDown InventoryEngine should replace GameCore inventory truth | Keep GameCore inventory, preserve explicit character owner |
| Current `Equipment`, `InventorySystem`, `HeroEquippedItemLoadout` | RPG equipment slots, stat contribution, bonus abilities, source-based ability grants | FantasyWord already has richer RPG equipment business than TopDown Koala | It should remain hidden behind `Hero` or be named `CharacterHandleWeapon` | Move to `CharacterEquipment` |
| GAS / current `CharacterAbilitySet` | AbilityAsset/AbilitySpec bridge, source-based grants/suppression, cooldown/cost lifecycle | A role-level ability set is valid for RPG/GAS rules | TopDown requires one MonoBehaviour per RPG skill | Preserve `CharacterAbilitySet` |

## Success Criteria

- A reviewer can inspect a controllable character prefab and identify distinct boundaries for role/identity, player control, ability set, inventory, equipment, movement, interaction, and weapon handling.
- Equipment operations can target any `CharacterBase` that has the formal equipment component, not only `Hero`.
- RPG equipment slot ownership, stat contribution, equipment-granted abilities, source suppression, save/load snapshots, corpse transfer, and inventory item transfers are owned by `CharacterEquipment` or an equivalently named formal equipment boundary.
- `CharacterHandleWeapon` no longer contains the RPG equipment slot/loadout truth.
- `CharacterAbilitySet` remains the RPG/GAS ability collection boundary and is not split into one component per skill asset.
- Validation evidence distinguishes documentation, static code alignment, prefab alignment, and runtime smoke. No phase is reported complete until its own evidence exists.
