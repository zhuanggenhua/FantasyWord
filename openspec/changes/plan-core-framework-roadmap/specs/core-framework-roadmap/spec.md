## ADDED Requirements

### Requirement: Core Framework Roadmap Must Preserve The Player Fantasy

`FantasyWord` MUST sequence future framework work around the confirmed player fantasy: single-player-led party RPG, real-time-with-pause combat, tactical companion command, rule-heavy character builds, emergent world interaction, and a simulated open world.

#### Scenario: Foundational character case is the next framework step

- **WHEN** foundation, control groups, RTS orders, and GAS formal contracts are complete
- **THEN** the next framework phase starts with a foundational character implementation case that includes a formal player character plus skill authoring/character build tooling
- **AND** skill authoring is treated as the production surface for professions, skill trees, abilities, gameplay effects, tags, costs, cooldowns, state rules, and validation
- **AND** the phase is not complete until the player character can consume that production surface through the formal runtime
- **AND** enemy AI does not enter implementation in this phase without a formal behavior-tree or equivalent AI framework

#### Scenario: Combat expands from the existing command and GAS contracts

- **WHEN** real-time-with-pause combat or tactics mode is implemented
- **THEN** pause, resume, slow-time, companion command, queued orders, and combat execution consume the formal order and GAS contracts
- **AND** they do not introduce a parallel combat command owner

#### Scenario: World interaction has formal affordance rules

- **WHEN** objects such as cages, stones, corpses, trees, terrain effects, or materials become interactable
- **THEN** interaction legality is resolved from object affordances, weight, volume, material, state, actor capability, and world context
- **AND** object-specific scripts do not become the only source of interaction truth

#### Scenario: Two-dimensional terrain can carry RTS-style gameplay elevation

- **WHEN** the game presents 2D terrain with raised ground, slopes, cliffs, plateaus, ramps, or high ground in the style of an RTS map
- **THEN** gameplay elevation is represented by formal terrain or navigation data rather than only sprite sorting
- **AND** movement, perception, ranged targeting, area effects, object interaction, AI pathing, and quest routing can all query the same elevation truth
- **AND** the implementation is chosen after reference research and a minimal prototype because no single current reference fully covers the target

#### Scenario: World AI waits for a world-state owner

- **WHEN** NPC personality, background, schedules, needs, factions, GOAP, or Utility AI are introduced
- **THEN** they are attached to an explicit world simulation owner with save, debug, and degradation boundaries
- **AND** GOAP or Utility AI does not enter the project as a second lifecycle host before those boundaries exist

#### Scenario: Experimental systems stay behind feasibility gates

- **WHEN** building destruction, railway systems, or construction systems are considered
- **THEN** they first go through feasibility prototypes and risk notes
- **AND** they do not block the skill authoring, combat, interaction, AI, quest, or dialogue phases from progressing
