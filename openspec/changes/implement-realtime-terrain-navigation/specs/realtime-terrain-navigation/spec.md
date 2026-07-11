## ADDED Requirements

### Requirement: Click Movement MUST Remain Real-Time And Continuous

`FantasyWord` MUST execute click movement as real-time continuous world-space movement rather than turn-based or visible cell-by-cell movement.

#### Scenario: A reachable click produces a continuous route

- **WHEN** the player clicks a reachable world position
- **THEN** the formal player command chain requests a route to that position
- **AND** the controlled character follows continuous world-space waypoints through the existing Rigidbody2D movement owner
- **AND** Tilemap cells remain an internal authoring and path-sampling unit rather than an action-point or turn unit

### Requirement: Raised Terrain MUST Use Explicit Walkable Connections

`FantasyWord` MUST represent outdoor RTS-style low ground, high ground, ramps, and cliffs through formal terrain navigation rules.

#### Scenario: A high-ground target is reachable through a ramp

- **WHEN** the player clicks a high-ground target connected by a legal ramp corridor
- **THEN** path calculation returns a route through that ramp
- **AND** the route follows the ramp's authored low-to-high direction
- **AND** the orthogonal Tilemap cells are converted into one continuous ramp center line
- **AND** the character does not attempt to cross the cliff face directly

#### Scenario: A ramp faces the wrong direction

- **WHEN** a height-changing step approaches a ramp from a direction that does not match its authored low-to-high direction
- **THEN** that step is rejected as an illegal height transition
- **AND** the character does not use the ramp as an unrestricted elevation bypass

#### Scenario: A cliff-separated target has no legal route

- **WHEN** the player clicks terrain separated by cliffs without a legal ramp connection
- **THEN** the click movement command fails explicitly
- **AND** the character does not continue pushing against the cliff collider

### Requirement: Terrain Rules MUST Have One Authoring Truth

`FantasyWord` MUST keep terrain navigation rules in one explicit Tilemap-based authoring surface.

#### Scenario: Visual terrain and gameplay terrain stay separated

- **WHEN** a map author paints grass, water, cliffs, ramps, shadows, or decoration
- **THEN** visual Tilemaps continue to own appearance and static presentation
- **AND** the rule Tilemap owns walkability, gameplay elevation, traversal cost, ramp classification, and base surface type
- **AND** sprite sorting, object names, sprite names, or colors do not become hidden gameplay truth

### Requirement: Path Calculation MUST Not Replace The Existing Movement Owner

`FantasyWord` MUST use path calculation only to produce routes while keeping movement execution in the existing `Movable` runtime.

#### Scenario: AStar returns a path

- **WHEN** the terrain navigation owner receives a valid start and destination
- **THEN** the existing AStar dependency may calculate a two-dimensional route
- **AND** project code converts the result into world-space waypoints
- **AND** the third-party example controllers, example scenes, and movement scripts do not enter the formal runtime

### Requirement: Terrain Surface State MUST Be Queryable In Real Time

`FantasyWord` MUST provide one terrain surface query that combines authored base terrain with runtime surface overrides.

#### Scenario: A character queries the surface underfoot

- **WHEN** gameplay queries a world position
- **THEN** it can obtain the terrain elevation, base surface type, traversal cost, and current runtime surface state
- **AND** runtime changes do not mutate the shared authored Tile asset
- **AND** later elemental reactions consume this same query instead of maintaining skill-private surface state
