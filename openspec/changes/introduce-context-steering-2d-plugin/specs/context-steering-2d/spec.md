# context-steering-2d Specification Delta

## ADDED Requirements

### Requirement: Best Practices MUST Be Integrated When No Single Plugin Wins

FantasyWord MUST integrate best practices from suitable free/open-source Unity steering and local avoidance projects when no single plugin fully satisfies the project requirements.

#### Scenario: No single mature plugin fully fits

- **GIVEN** UnitySteer covers traditional steering behaviours but lacks FantasyWord's shared detection and editor requirements
- **AND** ORCA/RVO libraries cover local avoidance but not complete steering behaviour authoring
- **WHEN** FantasyWord proposes replacing `FantasyWordSteering` or building `ContextSteering2D`
- **THEN** `ContextSteering2D` MUST become the single formal owner
- **AND** the design MUST record which best practice each reference contributes
- **AND** the implementation MUST NOT preserve multiple authoring or runtime owners for the same responsibility

### Requirement: UnitySteer MUST Be The Minimum Traditional Steering Baseline

UnitySteer MUST be treated as the minimum comparison baseline for traditional steering behaviours, not as a minor reference.

#### Scenario: Steering behaviour scope is planned

- **GIVEN** UnitySteer provides 2D behaviours such as point/seek, path following, wander, pursuit/evasion, separation, cohesion, alignment, neighbour handling and obstacle avoidance
- **WHEN** FantasyWord defines first-phase steering behaviour scope
- **THEN** the scope MUST use UnitySteer as a minimum behaviour baseline
- **AND** a smaller custom implementation MUST be labelled as a limited vertical slice rather than a complete steering plugin

### Requirement: GameCore MUST Not Own Steering Algorithms

FantasyWord GameCore MUST provide game semantics to `ContextSteering2D`, but MUST NOT own sampling directions, steering behaviour composition, local avoidance solver internals or third-party steering plugin internals.

#### Scenario: NPC movement is computed

- **GIVEN** an NPC needs a movement direction
- **WHEN** GameCore has selected target, obstacle, neighbour, body and movement inputs
- **THEN** GameCore passes those inputs through a formal adapter to `ContextSteering2D`
- **AND** GameCore receives a movement result or steering intent
- **AND** GameCore does not directly compute interest arrays, danger arrays, UnitySteer force blending, ORCA simulation internals or duplicate obstacle avoidance algorithms

### Requirement: Detection Results MUST Be Reusable Within A Tick

`ContextSteering2D` or its FantasyWord adapter MUST support reusable detection data so target, obstacle and neighbour queries can be shared by steering behaviours, local avoidance and combat pre-checks within the same tick where practical.

#### Scenario: Multiple systems need nearby objects

- **GIVEN** steering, local avoidance and combat range checks need nearby target, obstacle or neighbour data
- **WHEN** they execute in the same simulation tick
- **THEN** they SHOULD read from one `SteeringDetectionFrame2D` or equivalent shared snapshot
- **AND** they SHOULD NOT each perform duplicate broadphase queries for the same agent and filters
- **AND** if a backend cannot natively use the snapshot, the adapter MUST document the remaining duplicate query cost

### Requirement: One Profile MUST Be The Authoring Truth

`ContextSteering2D` MUST expose one profile asset as the formal steering authoring truth for an agent archetype.

#### Scenario: A designer configures steering behaviours

- **GIVEN** an agent archetype uses `ContextSteering2D`
- **WHEN** its steering is configured
- **THEN** one `ContextSteeringProfile2D` owns sampling, one or more named behaviour sets, behaviour-specific parameters, context combination, direction selection and per-agent local-avoidance participation parameters
- **AND** each named behaviour set has a stable ID and an ordered behaviour stack
- **AND** GameCore MAY select the active set for chase, orbit, sprint or other game states without the steering plugin owning those game-state meanings
- **AND** the designer does not need to maintain a parallel list of behaviour MonoBehaviours or duplicate per-behaviour assets
- **AND** the runtime solver MUST NOT hardcode the active behaviour array
- **AND** the profile MUST NOT select a world-level local-avoidance backend or simulation clock

### Requirement: Steering Output MUST Preserve Preferred Speed

The steering result MUST preserve direction strength or preferred speed rather than reducing every result to a normalized direction.

#### Scenario: Arrive or ORCA consumes a steering result

- **GIVEN** Arrive needs to slow an agent or a local avoidance backend needs preferred velocity
- **WHEN** the context map is resolved
- **THEN** the result includes preferred velocity or an equivalent direction plus speed scale
- **AND** Arrive MUST be implemented as target-speed/deceleration behaviour rather than by marking the target direction as danger

### Requirement: Local Avoidance Backend MUST Stay Replaceable

The steering implementation MUST use a replaceable world-level local-avoidance backend and MUST NOT conflate ordinary separation with RVO2 or contact resolution.

#### Scenario: Dense local avoidance is simulated

- **GIVEN** registered agents have authoritative positions, current velocities and preferred velocities
- **WHEN** the world simulation executes a fixed step
- **THEN** the formal RVO2 backend receives the complete agent batch
- **AND** the backend MUST accept preferred velocities for a batch or registry of agents and return collision-free velocities
- **AND** one world-level simulation owner MUST select the backend and own its fixed-step scheduling and completion
- **AND** the backend MUST NOT directly move agent Transforms, Rigidbodies, or authoritative positions
- **AND** UnitySteer-style separation remains a steering behaviour
- **AND** contact resolution remains a separate final stage

### Requirement: Dense Contact MUST Use Position-Based Batch Resolution

Overlapping registered agents MUST be resolved by one deterministic world-level contact stage.

#### Scenario: Large and small units overlap in a crowd

- **GIVEN** RVO2 safe velocities predict overlapping agent positions
- **WHEN** the contact stage builds constraints
- **THEN** it MUST use one world-level spatial index to generate unique contact pairs
- **AND** it MUST accumulate corrections with Jacobi iterations before publishing them
- **AND** correction responsibility MUST use inverse resistance derived from mass and priority
- **AND** a higher-resistance unit MUST move less than a lower-resistance unit
- **AND** changing registration order MUST NOT change the result associated with each stable agent ID
- **AND** the contact stage MUST return correction displacement without directly moving Unity objects

### Requirement: Behaviour Group Names MUST Remain Domain-Neutral

The plugin MUST expose named behaviour groups without owning project AI-state meanings.

#### Scenario: GameCore maps route and pursuit states

- **GIVEN** a profile contains domain-neutral groups such as `transit` and `predictive-target`
- **WHEN** GameCore configures an AI controller
- **THEN** GameCore MUST explicitly map its route and pursuit states to profile group IDs
- **AND** the plugin MUST NOT publish `path-follow`, `pursuit`, `chase` or other FantasyWord business constants
- **AND** a missing or unknown mapping MUST fail during AI initialization instead of falling back to the default group

### Requirement: Editor Visualization MUST Explain Steering Decisions

`ContextSteering2D` MUST provide editor-visible debugging that explains why a direction was chosen.

#### Scenario: Selected NPC shows steering context

- **GIVEN** an NPC using `ContextSteering2D` is selected in the Unity Editor
- **WHEN** steering debug drawing is enabled
- **THEN** the SceneView or Inspector shows target direction, behaviour contributions, obstacles, neighbours, final output direction, and local avoidance correction when available
- **AND** the debug view is provided by the steering plugin or adapter/editor layer rather than hardcoded GameCore gizmo logic
- **AND** each enabled behaviour's contribution remains individually inspectable after combination
- **AND** one editor drawing owner renders the snapshot so Gizmos and SceneView Handles do not duplicate the same visualization
- **AND** a static or isolated preview executes the same behaviour, combinator and selector path as runtime rather than only drawing probe radii
