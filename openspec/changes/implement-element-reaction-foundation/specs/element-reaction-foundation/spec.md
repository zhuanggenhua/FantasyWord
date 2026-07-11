## ADDED Requirements

### Requirement: World Element Applications MUST Use One Formal Entry

`FantasyWord` MUST represent fire, water, electricity, oil and later terrain/world-state elements as formal `ElementApplication` inputs handled by one `ElementReactionSystem`. This world-state entry MUST NOT replace EX-GAS actor GameplayEffects.

#### Scenario: A flamethrower timeline applies fire

- **WHEN** an EX-GAS flamethrower Timeline reaches its world-element task interval
- **THEN** the task submits a Fire `ElementApplication` with intensity, range and source context
- **AND** the task does not directly change Grass, Burning, ScorchedDirt, Tile assets or path costs
- **AND** `ElementReactionSystem` is the only formal owner that resolves the world reaction

#### Scenario: A non-skill source applies an element

- **WHEN** a future trap, weather source or world object creates the same elemental input
- **THEN** it can use the same `ElementApplication` contract without depending on EX-GAS
- **AND** the reaction rules remain outside the source-specific script

### Requirement: Actor Element Effects MUST Remain In EX-GAS

`FantasyWord` MUST continue using EX-GAS Timeline tasks, target catchers, GameplayEffects, GameplayTags and Attributes for actor damage and actor element states. The terrain element foundation MUST NOT create a parallel actor status framework.

#### Scenario: A flamethrower hits an actor and grass

- **WHEN** the same flamethrower Timeline can hit an actor and terrain
- **THEN** actor targeting, damage and actor Burning are applied through the existing `TaskApplyEffects` and GameplayEffect pipeline
- **AND** terrain Fire is submitted through `TaskApplyWorldElement`
- **AND** `TerrainCellRuntimeState` does not store or mirror the actor's GAS state

#### Scenario: Burning terrain later damages an actor

- **WHEN** a future terrain-contact adapter applies a consequence to an actor standing on Burning terrain
- **THEN** the adapter requests a configured GameplayEffect through the formal GAS entry
- **AND** `ElementReactionSystem` does not own actor damage ticks, actor Attributes or actor status duration

### Requirement: Element Reactions MUST Be Data Driven

`FantasyWord` MUST store element reaction conditions and outcomes in auditable `ElementReactionDefinition` data rather than hardcoding terrain transformations inside abilities, cues or presentation scripts.

#### Scenario: Fire reaches grass

- **WHEN** Fire is applied to a terrain cell whose effective surface matches Grass
- **THEN** a configured reaction can add or refresh Burning
- **AND** the flamethrower task does not contain a Grass-specific branch

#### Scenario: Multiple rules can match

- **WHEN** more than one reaction definition matches the same trigger
- **THEN** the system resolves them using explicit priority and stable rule identity
- **AND** the result does not depend on asset load order or dictionary iteration order

### Requirement: Terrain Runtime State MUST Preserve Authored Terrain Truth

`FantasyWord` MUST keep authored rule Tile assets immutable while storing rich per-cell runtime state separately.

#### Scenario: A grass cell begins burning

- **WHEN** a Grass rule cell enters Burning
- **THEN** its runtime state records Burning intensity, remaining duration and source context
- **AND** the shared `TerrainNavigationTile` asset remains unchanged
- **AND** the runtime state can expose both BaseSurface = Grass and EffectiveSurface = Grass

#### Scenario: Burning grass becomes scorched

- **WHEN** the configured Burning state expires on eligible Grass
- **THEN** the cell runtime state sets EffectiveSurface = ScorchedDirt
- **AND** BaseSurface remains Grass as the authored truth
- **AND** ScorchedDirt no longer matches the Grass fire reaction

### Requirement: Terrain Runtime State MUST Use Layer-Aware Node Identity

`FantasyWord` MUST identify terrain runtime state by a stable `TerrainNodeKey` containing both layer identity and cell coordinates. A flat `Vector3Int` MAY remain as a compatibility input for the current single-layer map, but MUST NOT remain the long-term authoritative key.

#### Scenario: Legacy single-layer callers query a cell

- **WHEN** an existing caller queries runtime terrain state using `Vector3Int`
- **THEN** the map resolves it to the same `TerrainNodeKey` on the default layer
- **AND** both query forms observe the same authoritative runtime state

#### Scenario: The same cell coordinates exist on different layers

- **WHEN** two terrain nodes share cell coordinates but have different layer IDs
- **THEN** their node keys are not equal
- **AND** their runtime state, traversal cost and presentation identity cannot overwrite each other

#### Scenario: A non-default layer is used before multilevel terrain is implemented

- **WHEN** the current single-layer `TerrainNavigationMap` receives a non-default `TerrainNodeKey`
- **THEN** it rejects the unsupported node explicitly
- **AND** it does not silently map the node to the default layer or claim multilevel support

### Requirement: Runtime Surface Flags MUST Not Remain The Only State Truth

`FantasyWord` MUST represent Wet, Burning, Oiled and Electrified as runtime state instances with lifecycle data rather than only as bit flags.

#### Scenario: The same state is applied repeatedly

- **WHEN** Burning is applied to a cell that is already Burning
- **THEN** the configured merge policy refreshes or combines duration and intensity
- **AND** the cell still contains one authoritative Burning state instance

#### Scenario: Compatibility flags are queried

- **WHEN** existing terrain consumers request runtime surface flags during migration
- **THEN** flags may be derived from the rich runtime state
- **AND** direct flag writes do not remain an independent state source

### Requirement: Terrain Element Reach MUST Respect Gameplay Elevation

`FantasyWord` MUST use the rule Tilemap's elevation, ramp and blocking semantics when converting a world element area into affected terrain cells.

#### Scenario: Fire points across a cliff

- **WHEN** a fire cone geometrically overlaps Grass on a higher platform across an illegal cliff edge
- **THEN** that high-platform cell is not affected
- **AND** visual overlap alone does not bypass the terrain connection rule

#### Scenario: Fire reaches terrain through a ramp

- **WHEN** cells inside the fire cone are connected through legal same-level or ramp edges
- **THEN** those cells can receive the Fire application
- **AND** no separate skill-private elevation test is used

### Requirement: Element State Lifecycle MUST Be Deterministic

`FantasyWord` MUST advance terrain element states using a fixed simulation step and deterministic reaction ordering.

#### Scenario: Burning reaches its duration

- **WHEN** Burning remaining duration reaches zero
- **THEN** the system evaluates configured expiration reactions before removing the state
- **AND** the cell transition and state removal are committed atomically
- **AND** observers receive one coherent cell-state change

#### Scenario: Gameplay is paused

- **WHEN** gameplay time is paused
- **THEN** the first terrain element implementation does not continue consuming state duration

#### Scenario: Only a few cells contain timed states

- **WHEN** a large rule Tilemap contains only a small number of Burning or Wet cells
- **THEN** the fixed simulation step advances only the derived active-cell set
- **AND** it does not scan every authored terrain cell
- **AND** the active index can be rebuilt from authoritative runtime state

#### Scenario: The active map begins unloading

- **WHEN** `OnMapUnloading` is received
- **THEN** element timing stops before map references are released
- **AND** subscriptions and the derived active-cell index are cleared

### Requirement: Temporary Effects And Terrain Results MUST Use Separate Presentation Layers

`FantasyWord` MUST visually separate temporary element effects from lasting runtime terrain-result overrides.

#### Scenario: Burning grass finishes

- **WHEN** Burning ends and the cell becomes ScorchedDirt
- **THEN** the temporary fire overlay is cleared
- **AND** the scorched terrain-result overlay remains
- **AND** clearing the temporary layer does not restore the visual Grass result

#### Scenario: A presentation mapping is missing

- **WHEN** a valid runtime state has no configured visual asset
- **THEN** the world-state change remains valid
- **AND** the system reports the missing presentation configuration
- **AND** it does not search for or create a replacement Tile at runtime

#### Scenario: Runtime presentation ownership is migrated

- **WHEN** `TerrainSurfacePresentation` is installed
- **THEN** it owns the temporary-effect and result-overlay Tilemap references
- **AND** `TerrainNavigationMap` no longer writes, refreshes or clears presentation Tilemaps
- **AND** there is only one runtime presentation owner

### Requirement: GameplayCue MUST Not Own World Reactions

`FantasyWord` MUST use EX-GAS GameplayCue only for animation, audio and feedback, not for element rules or terrain mutation.

#### Scenario: The flamethrower cue plays

- **WHEN** the flamethrower Timeline activates its cue
- **THEN** the cue may play the spray animation, fire stream, audio and feedback
- **AND** per-cell Burning and ScorchedDirt remain driven by terrain runtime state
- **AND** the cue does not call terrain state or Tile mutation APIs

#### Scenario: The flamethrower audio cue is consumed

- **WHEN** the formal flamethrower Ability activates its configured audio cue
- **THEN** the Timeline cue has a non-zero authored lifetime long enough for the presentation pipeline to consume it
- **AND** `CuePlayGameCoreAudio` resolves the configured `AudioClipResolver` through the formal database and audio-system entry
- **AND** the source Timeline data is regenerated through Luban rather than patching generated JSON

#### Scenario: Continuous flamethrower input stops

- **WHEN** continuous flamethrower input is released and the formal stop entry is invoked
- **THEN** no new flamethrower audio playback request is created by a restarted Ability
- **AND** an already playing one-shot clip may finish according to the audio-system policy
- **AND** any repeated request observed before stop is classified using Ability activation and playback-request evidence rather than time sampling alone

### Requirement: EX-GAS World Element Tasks MUST Use The Formal Generation Pipeline

`FantasyWord` MUST add `TaskApplyWorldElement` through project-side EX-GAS Task/XParam types and the existing Bean, Luban and registration generators.

#### Scenario: The new task is authored

- **WHEN** `TaskApplyWorldElement` is added to the project
- **THEN** BeanUpdater discovers its Task and parameter type
- **AND** Luban generates the corresponding config data and runtime types
- **AND** EX-GAS code generation registers the task
- **AND** generated C#, generated JSON and generated registration files are not edited manually
- **AND** the task remains terrain/world-state specific while actor effects continue using existing GAS tasks

### Requirement: Burning Terrain MUST Affect New Path Cost

`FantasyWord` MUST allow active terrain states to change the traversal cost consumed by new path calculations without transferring movement ownership to the element system.

#### Scenario: A route can avoid burning cells

- **WHEN** Burning increases the effective traversal cost of cells
- **THEN** a new path request reads the updated cost map
- **AND** the pathfinder may prefer a safer valid route
- **AND** `Movable` remains the owner of continuous movement execution
- **AND** the first implementation is not required to recalculate a route already in progress

#### Scenario: Burning is refreshed repeatedly

- **WHEN** the same Burning state is refreshed multiple times
- **THEN** effective traversal cost is recalculated from the authored base cost and current state definitions
- **AND** the cost multiplier is not repeatedly accumulated onto the previous cached value

#### Scenario: Burning is removed

- **WHEN** Burning is extinguished or expires
- **THEN** its traversal multiplier is no longer present in the derived cost
- **AND** the cell cost returns exactly to the value implied by the remaining states and authored base Tile

### Requirement: The First Terrain Reaction Slice MUST Be Transient

`FantasyWord` MUST reset the first terrain reaction slice when the map scene reloads until a separate persistence change defines save semantics.

#### Scenario: A scorched area is reloaded

- **WHEN** the scene containing runtime ScorchedDirt is unloaded and loaded again
- **THEN** transient terrain runtime state is cleared
- **AND** the rule Tilemap restores the authored Grass result
- **AND** the implementation does not claim terrain persistence is complete
