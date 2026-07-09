# Design: Character Equipment Composition Realignment

## Principle

The foundation is not being reset. This change corrects one reference-alignment error:

TopDown is a structural reference for character components. It is not the business source for FantasyWord's RPG equipment rules.

Therefore:

- Keep FantasyWord's richer RPG equipment behavior.
- Move that behavior out of `Hero`/`CharacterHandleWeapon` into a formal character equipment component.
- Keep weapon handling separate from equipment slot ownership.
- Keep GAS/RPG ability collection in `CharacterAbilitySet`.

## Current State Audit

| Area | Current Evidence | Reference Judgment | Decision |
| --- | --- | --- | --- |
| Player prefab component visibility | `0_Hero_Base.prefab` has `CharacterPlayerControl`, `CharacterAbilitySet`, `CharacterMovement`, `CharacterButtonActivation`, `CharacterInventory`, `CharacterHandleWeapon` | TopDown-like visible component composition started | Keep; add/replace equipment boundary |
| Ability collection | `CharacterAbilitySet` owns source counts, suppression, equipped ability slots, GAS formal rule bridge | Valid for RPG/GAS; not equivalent to TopDown per-module abilities | Keep |
| Inventory owner | `CharacterInventory` binds `CharacterBase` and owns main/weapon/hotbar flags | Aligns with character inventory boundary | Keep |
| Weapon/equipment boundary | `CharacterHandleWeapon` requires `Hero` and owns `HeroEquippedItemLoadout` | Misaligned: TopDown handle weapon means weapon handling, not RPG equipment loadout | Split |
| Equipment target resolution | `InventorySystem` resolves equipment target as `Hero` | Misaligned with multi-character target | Change to character equipment component |
| Corpse transfer | `TransferCharacterEquipmentToCorpse` exits unless `character is Hero` | Misaligned with NPC/party character equipment | Change to component-based transfer |
| Hero API | `Hero` no longer publishes equipment runtime APIs; growth-facing code stays local to `Hero`, equipment calls go straight to `CharacterEquipment` | Correct: player growth host is not the equipment owner | Keep `Hero` focused on progression and player-death semantics |

## Proposed Runtime Shape

### `CharacterEquipment`

Owns RPG equipment semantics:

- equipment slot loadout
- equip/unequip validation
- stat contribution
- equipment-granted ability source application/removal
- equipment ability suppression by alteration/transformation/infection sources
- equipment snapshot creation/restoration
- force unequip for death/corpse lifecycle

Required binding:

- `RequireComponent(typeof(CharacterBase))`
- serialized `CharacterBase m_character`
- no `Hero` requirement

Naming cleanup:

- `HeroEquippedItemLoadout` should become `CharacterEquippedItemLoadout` or be replaced by an equivalent character-owned class.
- `HeroEquipmentSlotChange` should become `CharacterEquipmentSlotChange`.
- Slot snapshot helpers should also use character-owned naming. Current runtime has already been realigned to `CharacterEquipmentSlotData` and `CharacterAbilitySlotData`; only the surrounding `HeroDataBlock` field names remain as part of the player-growth save block shape.

### `CharacterHandleWeapon`

Owns weapon handling only:

- current held weapon / active weapon executor
- weapon attachment or presentation hook
- weapon use state, firing, buffering, reload, aim, animation/feedback hooks if implemented

It does not own:

- RPG equipment slots
- stat contribution
- equipment-granted abilities
- equipment save snapshots

If FantasyWord has no separate held-weapon runtime yet, `CharacterHandleWeapon` may remain thin, but it must not continue pretending to be the RPG equipment owner.

### `InventorySystem`

Must route equipment operations by explicit owner and explicit target:

- `TryEquip(sourceOwner, CharacterBase targetCharacter, Equipment equipment)` resolves `CharacterEquipment`, not `Hero`.
- `TryUnequip(destinationOwner, CharacterBase targetCharacter, EEquipmentType type)` resolves `CharacterEquipment`, not `Hero`.
- no-argument equip/unequip may continue to default to current controlled character, but the execution target must be component-based.
- corpse transfer uses `CharacterEquipment` if present.

### `Hero`

May keep:

- experience and progression data for the current player-facing hero concept
- save data compatibility fields if changing them would break existing serialized data

Must not be treated as:

- the only equipment-capable character
- the equipment runtime truth
- an equipment query/command forwarding surface
- proof of prefab composition completion by itself

## Non-Goals And Guardrails

- Do not introduce `Profile`, `fallback`, adapter, facade, or compatibility layers.
- Do not wrap both old and new equipment systems. Pick `CharacterEquipment` as the runtime truth.
- Do not copy TopDown InventoryEngine or weapon item business.
- Do not rewrite `CharacterAbilitySet` unless a concrete reference-backed defect is found.
- Do not report this change complete after only documentation or only prefab edits.

## Validation Plan

Static validation:

- Search verifies `CharacterHandleWeapon` no longer requires `Hero`.
- Search verifies RPG equipment loadout fields no longer live in `CharacterHandleWeapon`.
- Search verifies equipment target resolution no longer requires `ResolveEquipmentTargetHero`.
- Search verifies corpse equipment transfer is component-based.

Prefab validation:

- `0_Hero_Base.prefab` has a visible `CharacterEquipment` component or equivalent equipment boundary.
- `CharacterHandleWeapon` fields, if present, no longer expose equipment loadout ownership.

Runtime smoke:

- Two characters with independent inventory and equipment owners can equip/unequip independently.
- Equipment-granted ability is added by source and removed on unequip.
- Transformation/infection suppression can suppress equipment-granted abilities and restore correctly.
- Death/corpse transfer moves both bag items and equipped items for a non-Hero character with equipment.

Documentation validation:

- References distinguish TopDown weapon handling from RPG equipment slots.
- "Ability component" is documented as a character function module boundary, not one MonoBehaviour per RPG skill asset.
