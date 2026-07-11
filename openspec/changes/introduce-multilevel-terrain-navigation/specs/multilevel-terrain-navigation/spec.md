## ADDED Requirements

### Requirement: Overlapping Walkable Surfaces MUST Have Distinct Node Identity

`FantasyWord` MUST identify a walkable terrain surface by both its Tilemap cell and its logical terrain layer.

#### Scenario: A bridge deck overlaps a tunnel floor

- **WHEN** the bridge deck and tunnel floor occupy the same planar cell
- **THEN** they produce different `TerrainNodeKey` values
- **AND** navigation, runtime surface state and debugging can address each surface independently

### Requirement: Multilevel Terrain MUST Keep One Authoring System

`FantasyWord` MUST author multilevel terrain through one `TerrainNavigationMap` that explicitly owns multiple rule Tilemap layer sources.

#### Scenario: A map contains ground and bridge layers

- **WHEN** the map author adds a bridge deck above walkable ground
- **THEN** both rule Tilemaps are registered as layer sources of the same terrain navigation owner
- **AND** visual Tilemaps, object names, sprite names and Unity Layer numbers do not become hidden terrain-node identity
- **AND** no separate custom map editor becomes a second terrain truth

### Requirement: Cross-Layer Movement MUST Use Explicit Transition Links

`FantasyWord` MUST connect different terrain layers only through explicit transition links.

#### Scenario: A unit walks up a ramp

- **WHEN** a valid bidirectional ramp link connects a ground node to a bridge node
- **THEN** the navigation graph can traverse that link in both directions
- **AND** movement follows the link's authored continuous world waypoints
- **AND** the entity changes logical layer at the link's commit point

#### Scenario: Two nodes overlap without a transition

- **WHEN** two terrain nodes share the same planar cell but have no transition link
- **THEN** they are not automatically connected
- **AND** a unit cannot change layer merely by entering the shared cell

### Requirement: Formal Pathfinding MUST Support Multiple Nodes Per Cell

`FantasyWord` MUST calculate multilevel routes on a graph that can contain multiple terrain nodes for one planar cell and explicit cross-layer edges.

#### Scenario: A ground unit routes to the bridge deck

- **WHEN** the destination is on the bridge layer
- **THEN** path calculation returns same-layer ground edges, a legal transition edge and bridge-layer edges
- **AND** the route does not pass directly from the tunnel floor to the bridge deck
- **AND** the existing continuous movement owner executes the resulting world path

### Requirement: Entity Terrain Layer MUST Drive Terrain Collision

`FantasyWord` MUST keep an entity's logical terrain layer as formal state and use it to select a reusable terrain collision band.

#### Scenario: A unit walks through the bridge tunnel

- **WHEN** the unit is on the ground layer
- **THEN** bridge-deck rail and bridge-layer terrain collision do not block it
- **AND** ground-layer obstacles still collide normally

#### Scenario: The unit reaches a transition commit point

- **WHEN** the unit crosses the authored layer-switch point
- **THEN** logical layer and movement collision band update in one transition commit
- **AND** Hitbox, Interaction and unrelated gameplay layers are not overwritten

### Requirement: Entity Presentation MUST Consume Logical Terrain Layer

`FantasyWord` MUST derive an entity's terrain presentation band from its logical terrain layer while preserving same-layer Y sorting.

#### Scenario: A unit passes under the bridge

- **WHEN** the unit is on the tunnel floor
- **THEN** bridge foreground artwork can occlude it correctly
- **AND** the unit is not rendered as if standing on the bridge deck

#### Scenario: A unit walks on the bridge

- **WHEN** the unit transitions to the bridge layer
- **THEN** its presentation band changes with the same formal layer transition
- **AND** render order does not become the source of navigation or collision truth

### Requirement: Overlapping Destination Candidates MUST Be Resolved Explicitly

`FantasyWord` MUST treat a clicked planar position as a set of terrain-node candidates when more than one logical layer exists there.

#### Scenario: A destination mask identifies the visible surface

- **WHEN** the click hits one layer's authored destination mask
- **THEN** that layer's terrain node is selected as the destination candidate

#### Scenario: Multiple candidates remain ambiguous

- **WHEN** multiple nodes are reachable and no authored visibility or current-layer rule selects one uniquely
- **THEN** the movement command fails explicitly
- **AND** editor debugging shows the unresolved candidates
- **AND** the resolver does not silently choose the highest or lowest layer

### Requirement: Terrain Runtime State MUST Be Stored Per Terrain Node

`FantasyWord` MUST store runtime terrain state against `TerrainNodeKey` rather than only planar cell coordinates.

#### Scenario: Fire burns on the bridge deck

- **WHEN** Fire applies Burning to a bridge-deck node
- **THEN** the bridge-deck runtime state changes
- **AND** the overlapping tunnel-floor node remains unchanged
- **AND** path cost updates only for the affected bridge node

### Requirement: Existing Single-Layer Maps MUST Migrate Without Repainting

`FantasyWord` MUST preserve current single-layer rule Tilemaps through a default terrain layer compatibility path.

#### Scenario: The current movement test map is loaded before bridge content is added

- **WHEN** a map contains only the current single rule Tilemap
- **THEN** it is treated as one default layer source
- **AND** existing rule Tile assets retain their walkability, elevation, ramp direction, surface and traversal-cost meaning
- **AND** the map author is not required to repaint every existing rule cell

