## ADDED Requirements

### Requirement: Character Equipment Must Be A Character Component Boundary

`FantasyWord` MUST expose RPG equipment ownership through a character-owned equipment component or equivalent prefab-visible formal boundary, instead of storing RPG equipment slot truth in `Hero` or in a weapon-handling component.

#### Scenario: Equipment target is resolved by component capability

- **WHEN** runtime code equips or unequips equipment for a target character
- **THEN** the target is valid if it is a `CharacterBase` with the formal equipment boundary
- **AND** the target does not need to be a `Hero`
- **AND** missing equipment boundary fails as an invalid target instead of silently falling back to a hero-only path

#### Scenario: RPG equipment truth is not stored in CharacterHandleWeapon

- **WHEN** `CharacterHandleWeapon` exists on a character
- **THEN** it may own weapon handling, current held weapon, weapon attachment, weapon execution, animation, or weapon feedback responsibilities
- **AND** it MUST NOT own RPG equipment slot loadout, equipment stat contribution, equipment-granted ability source truth, or equipment save/restore orchestration

#### Scenario: RPG equipment remains richer than TopDown weapon inventory

- **WHEN** FantasyWord references TopDown `CharacterHandleWeapon`, `CharacterInventory`, or Koala weapon items
- **THEN** those references prove only component visibility, character weapon handling, and weapon-inventory separation
- **AND** they do not replace FantasyWord's RPG equipment slots, stat contribution, equipment-granted abilities, or save semantics

#### Scenario: Hero no longer exposes equipment runtime APIs

- **WHEN** runtime code needs to query, equip, unequip, transfer, or lifecycle-remove character equipment
- **THEN** it MUST target the formal character equipment boundary directly
- **AND** `Hero` MUST NOT remain as a parallel equipment query or command surface
- **AND** growth-specific `Hero` responsibilities remain separate from equipment ownership

#### Scenario: Corpse equipment transfer is character-based

- **WHEN** a character with equipment dies and corpse transfer runs
- **THEN** equipped items are transferred through the formal equipment boundary if the character has one
- **AND** this behavior is not limited to `Hero`

### Requirement: TopDown Ability Component Terminology Must Not Override RPG/GAS Ability Assets

`FantasyWord` MUST distinguish TopDown-style character function modules from RPG/GAS ability assets.

#### Scenario: Character function modules are component-visible

- **WHEN** docs or code refer to TopDown-style ability components
- **THEN** the term means character function modules such as movement, weapon handling, inventory, interaction, dash, or pause
- **AND** the term does not require each `AbilitySheet`, `ActiveAbilitySheet`, or GAS `AbilityAsset` to become a separate MonoBehaviour component

#### Scenario: CharacterAbilitySet remains the RPG/GAS ability collection boundary

- **WHEN** a character gains, loses, suppresses, activates, cools down, saves, or restores RPG/GAS abilities
- **THEN** `CharacterAbilitySet` or the formal ability collection boundary owns the collection and rule bridge
- **AND** TopDown component structure does not force the project to split every RPG skill into a prefab-visible component
