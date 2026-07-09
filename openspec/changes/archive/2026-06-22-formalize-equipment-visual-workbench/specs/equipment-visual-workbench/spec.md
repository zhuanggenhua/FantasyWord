## ADDED Requirements

### Requirement: Equipment Workbench Must Be A Formal Preview Module

`FantasyWord` MUST provide an equipment visual workbench that can preview character appearance, animation, direction, and equipment visuals without depending on the unfinished player controller integration.

#### Scenario: Workbench opens from the formal demo scene

- **WHEN** `Assets/Scenes/EquipmentSystemDemo.unity` is opened
- **THEN** the scene contains the formal equipment workbench controller
- **AND** the controller loads the formal workbench catalog
- **AND** the scene is not implemented through a separate test-only controller path

#### Scenario: Workbench remains independent from player controller implementation

- **WHEN** the player controller is still being implemented
- **THEN** the workbench can still select character, animation, direction, and equipment for preview
- **AND** it does not require a live gameplay player instance to render the preview
- **AND** it does not become a second gameplay equipment truth source

### Requirement: Equipment Data And Visual Data Must Stay Separated

Equipment content MUST separate gameplay/rule data from visual presentation data.

#### Scenario: Equipment rule data has a formal data owner

- **WHEN** an equipment definition stores gameplay-facing information such as type, attributes, stable ID, or future GAS linkage
- **THEN** that information is stored under the formal equipment data boundary
- **AND** it is not stored only as a UI string or generated test label

#### Scenario: Equipment visual resources have a presentation owner

- **WHEN** an equipment entry needs sprites, animation frames, render-layer data, or preview icons
- **THEN** those resources are stored under the equipment visual presentation boundary
- **AND** the workbench references those resources through formal data assets
- **AND** UI code does not synthesize fake equipment visuals from hardcoded strings

### Requirement: Workbench UI Must Match The Required Preview Layout

The workbench UI MUST expose selection controls without blocking the central character preview.

#### Scenario: Left panel contains character and pose controls

- **WHEN** the workbench UI is visible
- **THEN** the left panel shows a character grid
- **AND** it exposes animation switching
- **AND** it exposes direction switching
- **AND** these controls remain within the visible screen bounds

#### Scenario: Center preview remains visible

- **WHEN** the user changes character, animation, direction, or equipment
- **THEN** the central preview updates
- **AND** the preview is not covered by a permanent UI mask or panel

#### Scenario: Right panel contains equipment selection

- **WHEN** the workbench UI is visible
- **THEN** the right panel shows equipment type switching
- **AND** it shows the current type's equipment grid
- **AND** the currently selected equipment is highlighted

#### Scenario: Grid buttons use visual thumbnails

- **WHEN** the workbench shows character or equipment options
- **THEN** character buttons display the character idle first frame
- **AND** equipment buttons display an icon or a representative first frame
- **AND** plain text alone is not sufficient for the grid button content

#### Scenario: Workbench uses the project font

- **WHEN** the workbench UI renders labels or buttons
- **THEN** it uses the `Silver` font family/material configured for the project
- **AND** it does not silently fall back to a default font for the main workbench controls

### Requirement: AIBridge Must Be Reliable Enough For Workbench Smoke Verification

AIBridge MUST support stable editor automation for this change's smoke verification.

#### Scenario: CLI does not leave dead locks after interrupted commands

- **WHEN** a previous AIBridge CLI process exits or is interrupted while holding the project CLI lock
- **THEN** a later Bridge command detects the stale lock by pid or age
- **AND** it can recover without waiting for the full stale timeout

#### Scenario: Result files are not missed at the timeout boundary

- **WHEN** Unity writes a result file near the CLI timeout boundary
- **THEN** the CLI rechecks and retries reading the result file before reporting timeout
- **AND** a valid result file is not silently discarded as a failed command

#### Scenario: scene-open reports the real active scene state

- **WHEN** `scene-open` opens `Assets/Scenes/EquipmentSystemDemo.unity`
- **THEN** the command result does not report failure if Unity has opened and activated the target scene
- **AND** independent scene-state readback confirms `SceneManager.GetActiveScene().path` is `Assets/Scenes/EquipmentSystemDemo.unity`

