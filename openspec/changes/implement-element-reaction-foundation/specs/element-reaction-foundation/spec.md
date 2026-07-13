## ADDED Requirements

### Requirement: World Element Applications MUST Use One Formal Entry

`FantasyWord` MUST represent fire, water, electricity, oil and later terrain/world-state elements as formal `ElementApplication` inputs handled by one `ElementReactionSystem`. This world-state entry MUST NOT replace EX-GAS actor GameplayEffects.

#### Scenario: A flamethrower timeline applies fire

- **WHEN** an EX-GAS flamethrower Timeline reaches its world-element task interval
- **THEN** the task submits a Fire `ElementApplication` with intensity, range and source context
- **AND** the task does not directly change Grass, Burning, Dirt, Tile assets or path costs
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

#### Scenario: Fire reaches grass cover

- **WHEN** Fire is applied to a terrain cell whose current cover state contains living grass
- **THEN** a configured reaction can add or refresh Burning
- **AND** the flamethrower task does not contain a Grass-specific branch

#### Scenario: Multiple rules can match

- **WHEN** more than one reaction definition matches the same trigger
- **THEN** the system resolves them using explicit priority and stable rule identity
- **AND** the result does not depend on asset load order or dictionary iteration order

### Requirement: Terrain Runtime State MUST Preserve Authored Terrain Template Truth

`FantasyWord` MUST keep authored rule Tile assets immutable as the initial terrain template while storing rich per-cell runtime state separately. This MUST NOT imply that player-caused world changes are temporary in the final open-world product.

#### Scenario: A grass cover cell begins burning

- **WHEN** a cell with living grass cover enters Burning
- **THEN** its runtime state records Burning intensity, remaining duration and source context
- **AND** the shared `TerrainNavigationTile` asset remains unchanged
- **AND** the runtime state can expose stable ground data separately from the current grass cover state

#### Scenario: Burning grass cover is consumed

- **WHEN** the configured Burning state expires on eligible grass cover
- **THEN** the cell records that the grass cover was removed and may start regrowth
- **AND** the underlying soil remains the ground surface
- **AND** a cell without grass cover no longer matches the grass-cover fire reaction

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

`FantasyWord` MUST visually separate temporary element effects from lasting world terrain/cover mutations.

#### Scenario: Burning grass cover finishes

- **WHEN** Burning ends and the cell removes its grass cover
- **THEN** the temporary fire overlay is cleared
- **AND** the grass cover remains hidden until the world cover state regrows it
- **AND** clearing the temporary layer does not restore grass cover by itself

#### Scenario: A presentation mapping is missing

- **WHEN** a valid runtime state has no configured visual asset
- **THEN** the world-state change remains valid
- **AND** the system reports the missing presentation configuration
- **AND** it does not search for or create a replacement Tile at runtime

#### Scenario: Runtime presentation ownership is migrated

- **WHEN** `TerrainSurfacePresentation` is installed
- **THEN** it owns the temporary-effect Tilemap reference
- **AND** `TerrainNavigationMap` no longer writes, refreshes or clears presentation Tilemaps
- **AND** there is only one runtime presentation owner

### Requirement: Authored Terrain MUST Separate Ground, Cover, Detail And Rules

Terrain scenes that support destructible surface cover MUST keep persistent ground, removable cover, visual details and hidden terrain rules in separate Tilemap responsibilities. Cover behavior MUST be selected from tile data rather than from a dedicated burnable-layer name.

#### Scenario: ClickMoveTest lowland grass is authored as removable cover

- **WHEN** the ClickMoveTest terrain Grid is inspected
- **THEN** its authored layout is compared against `Demo - Forgotten Plains (Rule + Animated Tiles).unity` as the formal source scene
- **THEN** all 617 lowland-grass rule cells contain authored Dirt in `基础地面`
- **AND** the 547 cells that visibly contained grass before migration contain those exact visual Tile references at the same coordinates in the generic `地表覆盖` Tilemap
- **AND** the 70 cells that visibly contained Dirt before migration remain bare Dirt without surface cover
- **AND** the migration does not infer cover from the lowland rule name, replace cells with a uniform generic Grass Tile, or change the authored map layout
- **AND** all 267 occupied source `GroundDecoration` cells remain unchanged in `地表装饰`
- **AND** duplicate or stale YAML records are not counted as occupied map cells
- **AND** both `TerrainNavigationMap` and `TerrainSurfacePresentation` reference `地表覆盖`
- **AND** the hidden `地形规则` Tilemap remains the navigation and elevation truth source

#### Scenario: Composite highland art cannot expose an authored soil layer

- **WHEN** a highland top is still represented by a combined cliff-and-grass Tile
- **THEN** that highland remains permanent structural Grass terrain rather than removable surface cover
- **AND** it does not match reactions that require authored Dirt with living Grass cover
- **AND** no generated or placeholder soil/grass asset may be substituted for the missing formal split assets

### Requirement: Element Surface Acceptance MUST Verify World-State Outcomes

`FantasyWord` MUST treat screenshots as supplemental evidence for element terrain tests. Acceptance MUST be based on runtime world-state, terrain-cover lifecycle, actor damage and navigation-cost observations.

#### Scenario: A burning grass-cover vertical slice is accepted

- **WHEN** ClickMoveTest or an equivalent terrain test validates Fire applied to grass cover
- **THEN** the recorded runtime sample before Fire shows authored Dirt ground with living Grass cover
- **AND** the reaction is applied through `ElementReactionSystem` from a world element input
- **AND** Burning is observed with a temporary fire visual and increased traversal cost
- **AND** a damageable actor standing on the Burning cell takes damage through the formal damage path
- **AND** after Burning expires the current cover is `None`, the cover lifecycle records removal, and the ground remains Dirt
- **AND** no Dirt or scorched-result Tile is written to a result override layer
- **AND** screenshots may be attached only as human-readable visual evidence after these state checks pass

#### Scenario: A screenshot exists but state evidence is missing

- **WHEN** a fire or exposed-soil screenshot exists without runtime state evidence
- **THEN** the implementation MUST NOT claim the element reaction slice passed
- **AND** it must report the missing state, damage, cost, or lifecycle evidence explicitly

### Requirement: GameplayCue MUST Not Own World Reactions

`FantasyWord` MUST use EX-GAS GameplayCue only for animation, audio and feedback, not for element rules or terrain mutation.

#### Scenario: The flamethrower cue plays

- **WHEN** the flamethrower Timeline activates its cue
- **THEN** the cue may play the spray animation, fire stream, audio and feedback
- **AND** per-cell Burning and grass-cover removal remain driven by terrain runtime state
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

### Requirement: The First Terrain Reaction Slice MUST Explicitly Defer Persistence

`FantasyWord` MAY reset the first terrain reaction slice when the map scene reloads only because this change does not yet implement world terrain persistence. The project MUST NOT treat reload reset as the final open-world behavior; player-caused terrain mutations such as burned grass cover removal and regrowth MUST be handled by a separate persistence change.

#### Scenario: A burned grass-cover area is reloaded

- **WHEN** the scene containing removed grass cover is unloaded and loaded again before terrain persistence exists
- **THEN** the current transient terrain runtime state may be cleared
- **AND** the authored template may restore the original grass cover
- **AND** this result is recorded as a missing persistence feature, not as final product behavior

#### Scenario: Persistent terrain mutation is implemented later

- **WHEN** a future world terrain persistence change is active
- **THEN** burned grass cover removal and regrowth progress are saved as player-caused terrain mutations
- **AND** loading the same world restores the removed or regrowing grass cover state
- **AND** presentation layers only display the saved world cell state and do not own the save data
- **AND** the implementation does not claim terrain persistence is complete
