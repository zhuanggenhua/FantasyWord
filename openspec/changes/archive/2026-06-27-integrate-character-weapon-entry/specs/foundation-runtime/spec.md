## ADDED Requirements

### Requirement: Character Weapon Entry Must Own Its Spawn Truth

`FantasyWord` MUST route character-side weapon attachment and projectile spawn queries through one formal character weapon entry, instead of letting each ability or presentation script keep its own same-duty spawn truth.

#### Scenario: Projectile abilities use the character weapon entry

- **WHEN** a projectile-producing gameplay ability needs a spawn point
- **THEN** it resolves that spawn point from the formal character weapon entry
- **AND** it does not keep a second formal projectile-spawn field as the main runtime truth

#### Scenario: Empty explicit projectile spawn still resolves through the same owner

- **WHEN** the character weapon entry has no explicit projectile spawn transform assigned
- **THEN** that same formal owner provides the fallback resolution path
- **AND** callers do not invent their own parallel fallback spawn truths

### Requirement: Reference Alignment Must Collapse To One Formal Truth Source

`FantasyWord` MUST collapse each absorbed reference responsibility to one formal truth source in project runtime, unless the chosen reference itself is being copied with an explicitly preserved multi-entry design.

#### Scenario: Role component absorbs a reference responsibility

- **WHEN** a TopDown-style role component such as weapon handling, inventory binding, movement, or interaction is adopted as a formal project boundary
- **THEN** the runtime has one formal owner for that responsibility
- **AND** business callers do not keep a second serialized owner for the same responsibility just because the old implementation already had one

#### Scenario: Fallback paths stay inside the formal owner

- **WHEN** fallback resolution is still required for prefab compatibility or optional reference fields
- **THEN** the fallback path stays inside the same formal owner
- **AND** the project does not reintroduce a scattered compatibility layer across unrelated callers
