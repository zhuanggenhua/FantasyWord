## ADDED Requirements

### Requirement: Player Terrain Mutations MUST Persist In World State

`FantasyWord` MUST save player-caused terrain mutations as part of the world instance rather than only showing them as transient presentation overlays.

#### Scenario: Burned grass cover remains removed after reload

- **WHEN** a player burns a grass cover layer and the reaction removes that cover to expose the underlying soil
- **THEN** the world records a cover-layer mutation for that terrain node
- **AND** loading the same world restores the grass cover as removed or regrowing
- **AND** the underlying soil remains visible until the cover regrows
- **AND** the authored template Tilemap is not directly modified by PlayMode

### Requirement: Authored Terrain Template And Player Mutation Layer MUST Be Separate

`FantasyWord` MUST treat authored Tilemaps as initial ground/cover templates and player terrain mutations as world-instance data.

#### Scenario: A terrain cell is queried

- **WHEN** a system queries the current terrain cell state
- **THEN** the result is composed from authored ground, authored cover and any saved player mutation
- **AND** element reactions, navigation and presentation consume that same effective result

### Requirement: Presentation Layers MUST Not Own Persistent Terrain Truth

`TerrainSurfacePresentation` MUST display current terrain state but MUST NOT be the owner of terrain save data.

#### Scenario: A saved removed-grass cell is displayed

- **WHEN** the world loads a saved grass-cover removal mutation
- **THEN** the presentation layer hides the grass cover and lets the authored underlying soil show
- **AND** clearing or rebuilding presentation Tilemaps does not erase the saved mutation
