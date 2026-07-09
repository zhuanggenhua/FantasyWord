# Tasks

## 1. Audit And Scope Lock

- [x] Confirm TopDown `CharacterHandleWeapon` is weapon handling, not a full RPG equipment slot system.
- [x] Confirm current `CharacterHandleWeapon` owns RPG equipment slot/loadout responsibilities and is still `Hero`-bound.
- [x] Confirm `InventorySystem` still resolves equipment target through `Hero`.
- [x] Confirm current docs need terminology correction around TopDown ability components vs RPG skills.
- [x] Review all equipment-related call sites and classify them as equipment slot, weapon handling, inventory transfer, UI display, save/load, or compatibility forwarding.

## 2. Specification

- [x] Create proposal and design with reference matrix.
- [x] Add spec delta for character equipment component boundary.
- [x] Validate OpenSpec change strictly.

## 3. Implementation

- [x] Add `CharacterEquipment` or equivalent formal equipment component.
- [x] Move RPG equipment loadout, stat contribution, equipment-granted abilities, suppression rules, snapshot/restore, and force-unequip lifecycle from `CharacterHandleWeapon` to the equipment component.
- [x] Rename runtime helper types away from `Hero*` naming where serialization compatibility allows.
- [x] Change `CharacterHandleWeapon` to `CharacterBase` binding or leave it as a thin weapon-handling component with no RPG equipment ownership.
- [x] Change `InventorySystem` equip/unequip target resolution from `Hero` to component-based `CharacterEquipment`.
- [x] Change corpse equipment transfer to component-based transfer.
- [x] Remove obsolete `Hero` equipment forwarding APIs once formal callers have moved to `CharacterEquipment`.
- [x] Update `0_Hero_Base.prefab` and inherited player prefab to expose the formal equipment boundary.

## 4. Validation

- [x] Static search: no RPG equipment loadout truth remains in `CharacterHandleWeapon`.
- [x] Static search: equipment operations no longer require a `Hero` target.
- [x] Prefab audit: player prefab exposes role/control/ability/inventory/equipment/movement/interaction/weapon boundaries.
- [x] Runtime smoke: two character equipment owners equip/unequip independently.
- [x] Runtime smoke: equipment-granted abilities add/remove by source.
- [x] Runtime smoke: transformation/infection suppression affects equipment-granted abilities reversibly.
- [x] Runtime smoke: non-Hero character equipment transfers to corpse inventory.

## 5. Completion Guard

- [x] Do not archive until every in-scope implementation and validation task is either complete or explicitly split with user approval.
- [x] Final report must distinguish documentation completion, implementation completion, prefab completion, and runtime verification.
