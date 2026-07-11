## ADDED Requirements

### Requirement: Water Surfaces MUST Remain The Visual Authoring Source

`FantasyWord` MUST keep animated water Tilemaps as the primary visual authoring source for water surfaces.

#### Scenario: The current animated lake tile renders water

- **WHEN** the water reflection feature is enabled
- **THEN** the existing animated water Tilemap remains responsible for the base water appearance
- **AND** the implementation does not require a duplicated visual water Tilemap
- **AND** sprite names or mixed grass-shore alpha are not used as hidden gameplay water truth

### Requirement: Water Areas MUST Default To Swimmable

`FantasyWord` MUST treat normal open-world water areas as swimmable by default.

#### Scenario: The player enters a lake

- **WHEN** the player's water detection point enters a normal water area
- **THEN** the player is considered inside water
- **AND** swimming behavior may start through the formal character presentation and movement systems
- **AND** the water surface itself is not treated as a solid blocking wall

#### Scenario: A shoreline blocks movement

- **WHEN** a rock, cliff, map boundary or authored shoreline obstacle blocks movement near water
- **THEN** that obstacle owns the blocking behavior
- **AND** the water area remains conceptually swimmable unless explicitly configured otherwise

### Requirement: Reflection MUST Use Shared Capture

`FantasyWord` MUST use shared reflection capture for water reflections rather than one reflection camera per water body.

#### Scenario: Multiple water bodies are visible

- **WHEN** a river and a lake are visible in the same camera view
- **THEN** the reflection system reuses a shared low-resolution reflection texture or equivalent shared capture
- **AND** it does not instantiate separate reflection cameras per river, lake or Tilemap

### Requirement: Reflection Capture MUST Filter Reflectable Objects

`FantasyWord` MUST capture only explicitly reflectable scene objects into the water reflection texture.

#### Scenario: Reflection texture is updated

- **WHEN** the reflection capture runs
- **THEN** shore characters, trees, buildings and configured objects may be captured
- **AND** UI, base terrain, water Tilemaps and unrelated effects are excluded by default
- **AND** object filtering is controlled by explicit layer/configuration rather than by screen contents alone

### Requirement: Swimming Characters MUST Not Use Full Standing Reflection

`FantasyWord` MUST not render a normal full standing reflection for a character that is currently swimming.

#### Scenario: The player is swimming

- **WHEN** the player is in swimming state
- **THEN** the player is excluded from the normal full-body reflection capture
- **AND** the existing swimming animation remains responsible for showing only the visible upper body
- **AND** any optional swimming reflection is limited to a weak upper-body shadow or wave-distorted hint

### Requirement: Reflections MUST Have Distance And Quality Tiers

`FantasyWord` MUST scale water reflection quality by distance and platform quality level.

#### Scenario: A water surface is near the player

- **WHEN** the water surface is near the player or camera focus
- **THEN** it may show a readable pixel-style dynamic reflection
- **AND** the reflection is clipped to valid water pixels

#### Scenario: A water surface is far from the player

- **WHEN** the water surface is distant or not visually important
- **THEN** the dynamic reflection is weakened or disabled
- **AND** the animated water remains visible

#### Scenario: The device uses a low quality profile

- **WHEN** the active quality profile disables dynamic water reflections
- **THEN** the water surface uses animation-only or static shading
- **AND** gameplay water detection and swimming behavior remain unaffected

### Requirement: Reflection MUST Be Clipped To Water Pixels

`FantasyWord` MUST clip water reflections to a water mask that represents actual water pixels.

#### Scenario: A tile contains both shore grass and water

- **WHEN** the tile's sprite includes non-water shore pixels
- **THEN** reflection appears only on the water pixels
- **AND** grass, dirt or shoreline pixels do not receive water reflection

### Requirement: Reflection Rendering MUST Avoid Duplicate Pixel Upscaling

`FantasyWord` MUST keep reflection render targets compatible with the project's pixel presentation pipeline.

#### Scenario: The project xBRZ renderer feature is enabled

- **WHEN** the reflection texture is rendered
- **THEN** it is not accidentally processed as a final camera output by xBRZ
- **AND** the reflection remains stable under pixel-art sampling and camera movement
- **AND** any required renderer isolation or skip rule is treated as part of the feature setup

### Requirement: Camera Sorting Layer Texture MUST Not Become The Sole Reflection Owner

`FantasyWord` MAY use URP 2D Camera Sorting Layer Texture as an auxiliary sampling source, but MUST NOT rely on it as the sole formal owner of water reflection capture.

#### Scenario: Sorting layer capture is available

- **WHEN** a water material samples Camera Sorting Layer Texture
- **THEN** the feature still has explicit rules for reflectable objects, swimming-character exclusion and quality tiers
- **AND** screen-layer capture does not replace the formal reflection object configuration

