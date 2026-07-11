# equipment-visual-workbench Specification

## Purpose
`equipment-visual-workbench` 定义 FantasyWord 的换装表现测试工作台合同。它是给内容制作、表现验证和独立 smoke 用的正式测试入口，不是玩家背包 UI，也不是玩家控制器接线层。
## Requirements
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

### Requirement: Workbench Tasks Must Not Mutate Authored Equipment Data Without Explicit Scope

Visual workbench implementation and debugging MUST treat existing authored equipment data as read-only unless the user explicitly includes data authoring or regeneration in the current task.

#### Scenario: Visual test work does not rewrite formal data

- **WHEN** the current task is to build, repair, or verify the visual test layer
- **THEN** the workbench may read existing `EquipmentRenderData`, `CharacterFrameData`, animation controllers, UV maps, and imported sprites
- **AND** it MUST NOT add or replace equipment animation sequences
- **AND** it MUST NOT rewrite frame matrices, anchors, UV references, generated UV textures, texture import settings, animation controllers, or generator/synchronization tools
- **AND** validation scripts and preview UI MUST NOT save derived test state back into formal assets

#### Scenario: Missing authored data blocks the preview instead of expanding scope

- **WHEN** a preview is missing because the formal equipment asset has no matching sequence, frame data, UV map, or icon source
- **THEN** the task reports the missing authored data as the blocking fact
- **AND** it stops before modifying configuration or running batch generation
- **AND** data authoring proceeds only after the user explicitly expands the task scope

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

#### Scenario: Left panel contains character, appearance, and pose controls

- **WHEN** the workbench UI is visible
- **THEN** the left panel shows a character grid
- **AND** it exposes an independent appearance grid
- **AND** it exposes animation switching
- **AND** it exposes direction switching
- **AND** the left panel order is `角色 -> 形象 -> 动作 -> 方向`
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
- **AND** appearance options remain visible as dedicated grid entries instead of hiding inside the character selection only
- **AND** plain text alone is not sufficient for the grid button content

#### Scenario: Test workbench keeps information density low

- **WHEN** the workbench is used for repeated switching tests
- **THEN** it prioritizes compact, clickable grids over large explanatory text blocks
- **AND** persistent detail text stays limited to the currently selected state and equipment information
- **AND** the UI does not depend on decorative overlays or layered panels that make the preview harder to inspect

#### Scenario: Test workbench does not expand into player-facing UI redesign

- **WHEN** the current task is only to support visual switching tests
- **THEN** the workbench stays a utility-style verification surface
- **AND** it does not add player-facing inventory flow, narrative copy, or decorative presentation outside the testing scope

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
