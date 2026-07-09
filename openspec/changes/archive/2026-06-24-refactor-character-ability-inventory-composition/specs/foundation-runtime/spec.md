## ADDED Requirements

### Requirement: Character Prefab Composition Must Be Explicit

`FantasyWord` MUST define player and controllable-character prefab composition as an explicit formal contract instead of treating a single `Hero` script host as completion evidence.

#### Scenario: Player prefab composition is inspectable

- **WHEN** a player or controllable character prefab is reviewed for completion
- **THEN** the prefab must expose explicit role, control, ability, inventory, and equipment ownership boundaries
- **AND** a single host script by itself does not count as proof that the character is composition-complete
- **AND** the review can identify where ability rules live, where inventory ownership lives, and where execution/presentation live
- **AND** a `SerializeReference` controller field or a partial class file split does not by itself satisfy TopDown-style component composition

#### Scenario: TopDown style composition is reference, not identity

- **WHEN** FantasyWord absorbs TopDown character composition ideas
- **THEN** `Character` / `CharacterAbility` / `CharacterInventory` may be used as pattern references
- **AND** TopDown manager singletons, input roots, GUI roots, and lifecycle ownership do not become the formal gameplay truth source

### Requirement: Character Control And Ability Boundaries Must Become Component-Inspectable

`FantasyWord` MUST move controllable-character control and ability execution toward prefab-visible component boundaries instead of treating `Hero / CharacterBase / Movable` plus serialized helper objects as the final composition form.

#### Scenario: Player controller is not only a serialized field

- **WHEN** a player or controllable-character prefab is reviewed against the TopDown `Koala.prefab` reference
- **THEN** the review can identify a formal control boundary on the prefab
- **AND** a hidden serialized controller object does not by itself count as the final control split
- **AND** movement-control and interaction-activation settings should live on prefab-visible components instead of remaining hidden inside the serialized controller object

#### Scenario: Ability runtime is not only a host method collection

- **WHEN** a player or controllable-character prefab is reviewed for ability composition
- **THEN** the review can identify ability composition/execution boundaries without treating `CharacterBase.Abilities.cs` as the only ability owner
- **AND** the project may keep `CharacterBase` as identity/state/rule owner while still splitting control and ability execution into inspectable runtime components
- **AND** external ability query, trigger, cooldown, grant, and revoke flows should enter through the prefab-visible ability boundary rather than silently falling back to host-only ability storage
- **AND** ability roots and prefab-level additional ability configuration should live on the prefab-visible ability boundary instead of duplicated host fields
- **AND** the ability instance runtime container should live behind the prefab-visible ability boundary; missing ability-boundary components are prefab configuration errors, not normal runtime fallback paths
- **AND** an entry component that only delegates back to `CharacterBase` counts as a migration step, not as complete TopDown-style ability lifecycle separation

#### Scenario: TopDown component split is the target form

- **WHEN** implementation work continues after the first migration step
- **THEN** control, ability, inventory, equipment, and presentation responsibilities must move toward prefab-visible components
- **AND** `SerializeReference` controller fields, large host scripts, or partial file splits cannot be used as the final completion proof

### Requirement: Character Ability Composition Must Support Rule Reassignment

`FantasyWord` MUST support character ability composition that can preserve, replace, suppress, or remove only part of a character's abilities when the character transforms, is infected, or changes form.

#### Scenario: Transformation preserves some abilities and replaces others

- **WHEN** a character transforms, becomes infected, or enters a special mutation state
- **THEN** the runtime can preserve some abilities, replace some abilities, suppress some abilities, and remove some abilities according to explicit rule sources
- **AND** the runtime does not require wiping the whole character ability set as the only valid outcome

#### Scenario: Ability sources remain traceable

- **WHEN** an ability is granted or removed by equipment, transformation, infection, or other temporary rule sources
- **THEN** the source of that ability remains traceable and reversible
- **AND** the same ability name can coexist under different source rules without collapsing into an ambiguous one-off special case

### Requirement: Character Inventory Must Be Character-Owned

`FantasyWord` MUST treat player and party inventory ownership as explicit owner-scoped data, and character prefabs must have a clear binding path to their own inventory-related ownership.

#### Scenario: Character inventory is not only a global party bag

- **WHEN** a character picks up, equips, or transfers items
- **THEN** the item ownership is resolved against the explicit owner scope for that character
- **AND** the project does not rely on a hidden global bag as the only formal inventory truth

#### Scenario: Inventory UI resolves an explicit owner

- **WHEN** the inventory UI is opened for a character or transfer context
- **THEN** the UI resolves a display owner and destination owner explicitly
- **AND** the current controlled character may be used only to choose which explicit owner to inspect, not as a hidden replacement for character-owned inventory components

#### Scenario: Multiple inventory owners stay formal

- **WHEN** the runtime handles character, corpse, container, ground pile, shop, or crafting-station inventory owners
- **THEN** each owner kind remains a first-class inventory owner type
- **AND** the player prefab review can prove which owner belongs to which character or container

### Requirement: Character Equipment Must Not Remain Hidden In A Single Hero Host

`FantasyWord` MUST expose character equipment ownership, equipment-granted ability rules, and equipment persistence orchestration through prefab-visible equipment/inventory boundaries or an equivalent formal component boundary, instead of treating `Hero` as the only inspectable equipment truth.

#### Scenario: Equipment slots are inspectable on the character boundary

- **WHEN** a player or controllable-character prefab is reviewed for composition completion
- **THEN** the review can identify where equipment slots belong to that character
- **AND** equipment slot ownership is not proven solely by opening a large `Hero` host script
- **AND** equipment state can be related back to the explicit character inventory owner

#### Scenario: Equipment-granted abilities are reversible by source

- **WHEN** equipment grants, suppresses, or removes abilities
- **THEN** the affected ability source remains traceable to the equipment source
- **AND** unequipping or restoring saved equipment can revoke or restore the related abilities without collapsing into an ambiguous character-level special case

### Requirement: Change Completion Must Match The Original Scope

`FantasyWord` MUST NOT archive or report `refactor-character-ability-inventory-composition` as complete while any in-scope control, ability, inventory, equipment, implementation-log, prefab-audit, or validation task remains incomplete.

#### Scenario: Documentation completion is not implementation completion

- **WHEN** proposal, design, rationale, spec delta, or OpenSpec artifact validation is complete
- **THEN** that result counts only for the documentation and specification tasks
- **AND** it does not imply that player prefab componentization, character inventory, equipment slots, ability-rule boundary work, or control-boundary decomposition is complete

#### Scenario: Deferred work remains in scope

- **WHEN** a task is described as "later", "deferred", or "after this phase"
- **THEN** it remains in the current change unless the user explicitly confirms a scope split
- **AND** the change must keep the task visible as incomplete until implemented, explicitly split with user approval, or proven out of scope by source evidence
