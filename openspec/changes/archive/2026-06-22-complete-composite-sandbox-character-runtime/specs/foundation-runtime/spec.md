## ADDED Requirements

### Requirement: Advanced Control Groups Must Be A Formal Runtime Owner

`FantasyWord` MUST treat advanced control groups as a formal runtime owner boundary instead of a temporary UI convenience layer.

#### Scenario: Control group owns explicit membership and focus

- **WHEN** the player controls more than one character through a control group
- **THEN** the runtime stores explicit group membership, primary focus, and controllability through the formal player/control owner
- **AND** UI panels consume snapshots or query methods instead of mutating group membership directly

#### Scenario: Control group survives owner-state changes

- **WHEN** a grouped character dies, revives, transforms, loses player control, or is force-swapped to AI
- **THEN** the formal control-group owner reconciles membership and focus through one runtime path
- **AND** the project does not leave parallel fallback logic in UI, input callbacks, or scene helpers

#### Scenario: Control group command classes are explicit

- **WHEN** a command is issued from a control group
- **THEN** the runtime can distinguish commands that target only the primary member from commands that fan out to all approved members
- **AND** that distinction is encoded in the formal command/runtime contract rather than guessed by each caller

### Requirement: RTS Orders Must Use A Formal Order Runtime

`FantasyWord` MUST provide a formal RTS-style order runtime for group selection and batch orders instead of relying on ad-hoc direct command callbacks.

#### Scenario: Orders support replace, append, and stop semantics

- **WHEN** the player or AI issues a formal order through the runtime
- **THEN** the order runtime can express replace-current, append-to-queue, and stop semantics explicitly, independent of the concrete order kind
- **AND** callers do not encode those semantics through hidden booleans or local side effects
- **AND** future order families continue extending the same formal order contract instead of reintroducing ad-hoc direct callbacks

#### Scenario: Batch orders keep per-member adjudication

- **WHEN** a control group receives a batch order
- **THEN** each member still resolves ownership, action locks, target legality, and execution permission through the formal owner chain
- **AND** batch dispatch does not collapse those checks into a single shared shortcut

#### Scenario: Formation or distributed target semantics are formal

- **WHEN** a batch move or equivalent spatial order is issued
- **THEN** the runtime owns the formation or distributed target semantics through a formal order contract
- **AND** UI code does not hardcode per-button offset logic as world truth

### Requirement: GAS Runtime Must Complete The Formal Truth Replacement

`FantasyWord` MUST complete the formal GAS replacement boundary for attributes, ability rules, and temporal effect rules without keeping a long-term dual-truth runtime.

#### Scenario: Legacy runtime data no longer acts as a peer truth source

- **WHEN** the formal runtime reads or writes health, mana, attack, defense, speed, cooldown, cost, or effect state
- **THEN** the formal GAS-backed owner chain is the only runtime truth source
- **AND** legacy `Stats/currentStats`, bootstrap mirrors, or old effect runtime shells remain only as strictly bounded migration or bootstrap compatibility surfaces

#### Scenario: Ability rules are unique while execution remains outside GAS

- **WHEN** a character gains, loses, suppresses, replaces, cools down, or is blocked from using an ability
- **THEN** those rule decisions are resolved through the formal GAS-backed rule layer
- **AND** movement, weapon execution, summon execution, hit windows, and feedback remain owned by the GameCore execution layer
- **AND** the same rule is not evaluated independently by both layers

#### Scenario: Formal temporal effect recovery owns save and lifecycle recovery

- **WHEN** a character is saved, loaded, disabled, pooled, or restored with temporal ability/effect state
- **THEN** the formal GAS recovery/runtime owner completes restoration, cleanup, and detached-runtime tracking through one formal lifecycle
- **AND** the runtime does not keep a second long-term effect lifecycle alive in legacy execution-shell state
