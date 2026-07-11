## ADDED Requirements

### Requirement: Foundation Runtime Entry Must Follow The Mature Reference Baseline

`FantasyWord` MUST use a `GameManager + AGameSystem` runtime entry aligned with the local `2DRPGEngine` reference instead of the rejected `Bootstrapper/RuntimeContext/ModuleInstaller/EventBus` chain.

#### Scenario: GameManager discovers and initializes systems

- **WHEN** a scene contains a `GameManager` and one or more `AGameSystem` components
- **THEN** the `GameManager` collects those systems
- **AND** each collected system receives exactly one initialization call during startup
- **AND** gameplay rules remain outside the `GameManager`

#### Scenario: GameManager exposes explicit system lookup

- **WHEN** a caller requests a registered game system by type
- **THEN** the `GameManager` returns the registered system
- **AND** missing required systems fail with a direct error instead of silently creating a fallback

#### Scenario: Existing static system shortcuts remain a fast implementation surface

- **WHEN** project code uses the existing 2DRPG-derived `GameManager.XxxSystem` shortcuts
- **THEN** those shortcuts may remain as the current foundation fast access surface
- **AND** the design does not classify global access as a defect by itself
- **AND** a shortcut becomes a defect only when it expands without ownership, bypasses the formal owner, or keeps a second truth source alive

#### Scenario: Static access does not replace ownership layers

- **WHEN** a new runtime responsibility is proposed
- **THEN** the change identifies whether the responsibility is project-level, world-level, mode-level, or entity-level
- **AND** only project-level unique services may be considered for `GameManager + AGameSystem`
- **AND** world state, card-mode match state, entity-local state, UI host truth, GAS attribute truth, and third-party manager lifecycles are not added to `GameManager` merely for convenient access

#### Scenario: New open-world systems do not expand GameManager static shortcuts

- **WHEN** the foundation static gate inspects `GameManager`
- **THEN** existing 2DRPG-derived system shortcuts may remain for the current RPG baseline
- **AND** new open-world systems such as region, cell, squad, faction, schedule, economy, navigation, or simulation systems are not exposed as additional `GameManager.XxxSystem` static shortcuts
- **AND** those systems must enter through an explicit module interface with an owner, save model, and verification entry

### Requirement: Game Systems Must Use The Reference Lifecycle

`FantasyWord` MUST define game systems through an `AGameSystem` lifecycle compatible with the `2DRPGEngine` reference.

#### Scenario: System lifecycle is driven by the runtime entry

- **WHEN** the `GameManager` is enabled and disabled
- **THEN** collected systems receive start and stop lifecycle calls
- **AND** systems do not require a project-side service registry or module installer to participate in the lifecycle

#### Scenario: Map and save lifecycle events are forwarded to systems

- **WHEN** map loading, map unloading, or save-file-loaded lifecycle notifications are raised through `GameRuntimeEvents`
- **THEN** collected systems receive the corresponding lifecycle callbacks
- **AND** `GameManager` publishes the corresponding GameCore typed event only after system lifecycle callbacks have run
- **AND** `GameManager` does not expose a public project-made `Notify*` notification entry for the same lifecycle

### Requirement: Foundation Configuration Must Expose The Database Registry

`FantasyWord` MUST expose a `DatabaseRegistry` through `GameConfig` and `GameManager.Database` so future game data uses a stable database truth layer instead of a service container or event bus.

#### Scenario: GameConfig references the database registry

- **WHEN** the foundation runtime reads game configuration
- **THEN** it uses `Assets/GameData/GameCore/GameConfig.asset`
- **AND** the asset references `Assets/GameData/GameCore/DatabaseRegistry.asset`
- **AND** callers can read that registry through `GameManager.Database`

### Requirement: Database Registry Must Provide Stable Entry References

`FantasyWord` MUST provide a database registry aligned with the `2DRPGEngine` Database closure.

#### Scenario: Registry creates and resolves a database entry reference

- **WHEN** a registered `DatabaseEntry` is converted to a `DatabaseEntryReference`
- **THEN** the reference stores the registered GUID
- **AND** the registry can resolve that reference back to the same entry

#### Scenario: Unregistered entries fail directly

- **WHEN** a database entry is not registered
- **AND** code asks the registry for its GUID
- **THEN** the registry fails with a direct error instead of returning an empty fallback

#### Scenario: Prefab references are database entries

- **WHEN** a prefab reference is registered in the database
- **THEN** it can be resolved through the same database registry
- **AND** it exposes the configured prefab object

### Requirement: Runtime Data Must Preserve Future Mod Support

`FantasyWord` MUST treat Mod support as a required long-term product goal while avoiding an empty Mod framework in the current foundation.

#### Scenario: New content data preserves stable identity

- **WHEN** new formal game data, resource references, or save-facing fields are added
- **THEN** they use stable IDs, database references, resource keys, or an equivalent auditable identity layer
- **AND** they avoid hardcoding official content paths, scene object names, temporary array indexes, or inspector ordering as runtime truth

#### Scenario: Foundation does not create an empty Mod subsystem

- **WHEN** the foundation runtime is inspected
- **THEN** Mod support is documented as a mandatory future capability
- **AND** no empty `Mods` runtime directory, external script sandbox, workshop integration, or package loader placeholder is introduced before a concrete content pipeline is specified

#### Scenario: Missing external content can fail safely

- **WHEN** a save, database reference, or resource key points to content that is missing, disabled, or version-migrated
- **THEN** the runtime reports a diagnosable error or uses an explicit fallback
- **AND** it does not rely on a null scene reference or hardcoded prefab path as the only recovery path

### Requirement: Command Contract Must Stay Asynchronous

`FantasyWord` MUST provide an `ICommand` contract aligned with the `2DRPGEngine` command baseline.

#### Scenario: Command execution can be awaited

- **WHEN** a command implements `ICommand`
- **THEN** callers can await `Execute()`
- **AND** future interactions, dialogue, map events, and quest scripts do not need to route through the rejected foundation event bus

### Requirement: New Event Dispatch Must Use The Chosen Event Mechanism

`FantasyWord` MUST use Yoki `EventKit.Type` as the formal event dispatch mechanism for GameCore domain events, and the archived `NotificationSystem` MUST NOT remain in formal runtime code, tests, or scenes.

#### Scenario: Archived notification hub is removed from the formal runtime

- **WHEN** the foundation static gate inspects formal runtime code, tests, and scenes
- **THEN** `GameManager` does not expose `GameManager.NotificationSystem`
- **AND** `NotificationSystem.cs` and `NotificationSystemTests.cs` do not exist in the formal tree
- **AND** formal scenes do not contain a `Notification System` object or the deleted script GUID

#### Scenario: Map and save lifecycle leave the NotificationSystem call surface

- **WHEN** `MapSystem` reports map loading or unloading
- **OR** `SaveSystem` reports a loaded save file
- **THEN** they call the corresponding `GameRuntimeEvents.Notify*` lifecycle entry
- **AND** `GameManager` remains the only owner of `AGameSystem` lifecycle fan-out
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.mapLoading`, `NotificationSystem.mapLoaded`, `NotificationSystem.mapUnloading`, `NotificationSystem.mapUnloaded`, or `NotificationSystem.saveFileLoaded` directly

#### Scenario: New domain events use GameCore event types and EventKit

- **WHEN** a new domain event is needed for combat, inventory, quest, map, UI, audio, world simulation, or card mode
- **THEN** the event payload is defined as a GameCore domain event type
- **AND** dispatch uses Yoki `EventKit.Type`
- **AND** the event type is not defined inside the Yoki plugin body

#### Scenario: Local owner notifications are not forced into the project event bus

- **WHEN** a notification only describes an owning object or host's local state change
- **AND** the notification does not need to become a project-wide cross-system event
- **THEN** the owner may keep using a local `UnityEvent`
- **AND** the remediation path is not to force that local notification into `GameRuntimeEvents`
- **AND** the defect only exists when the same fact also remains exposed through a second project-level event path

#### Scenario: Audio playback requests leave the NotificationSystem call surface

- **WHEN** GameCore code requests audio playback
- **THEN** it sends a GameCore `AudioPlaybackRequestedEvent` through Yoki `EventKit.Type`
- **AND** `AudioSystem` consumes that typed event as the formal playback request path
- **AND** project-side code does not call `NotificationSystem.audioPlaybackRequested.Invoke(...)` directly

#### Scenario: Map transition input locking uses typed runtime events

- **WHEN** a map transition starts or completes
- **THEN** `MapSystem` sends a GameCore map-transition event through Yoki `EventKit.Type`
- **AND** `InputSystem` locks or unlocks input by listening to that typed event
- **AND** project-side code does not call or subscribe to `NotificationSystem.mapTransitionStarted` or `NotificationSystem.mapTransitionCompleted` directly

#### Scenario: Map transition delegation uses a typed runtime event

- **WHEN** `MapSystem` delegates map unloading, loading, and completion to the transition presentation system
- **THEN** it sends a GameCore `MapTransitionDelegationRequestedEvent` through Yoki `EventKit.Type`
- **AND** `TransitionSystem` listens to that typed event as the formal delegation path
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.mapTransitionDelegationRequested` directly

#### Scenario: Persistable destruction uses direct persistence collaboration

- **WHEN** a `Persistable` object is destroyed through the formal persistence lifecycle
- **THEN** it hands a narrow `PersistableDestructionSnapshot` directly to `PersistenceSystem`
- **AND** `PersistenceSystem` updates its persistence data from that snapshot instead of receiving a live `Persistable` runtime object through the project event bus
- **AND** project-side code does not call or subscribe to `NotificationSystem.persistableDestroyed` directly

#### Scenario: Player ability failure uses typed runtime events

- **WHEN** the current player input target tries to fire an ability and the ability check fails
- **THEN** `PlayerController` sends a GameCore `PlayerAbilityFireFailedEvent` through Yoki `EventKit.Type`
- **AND** HUD presentation listens to that typed event as the formal ability-failure prompt path
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.playerFireFailed` directly

#### Scenario: AI target detection stays inside the AI owner

- **WHEN** an AI controller detects or is provoked by a target
- **THEN** `AIController` updates its own target-tracking state directly
- **AND** no extra project-level runtime event is introduced for that local AI decision
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.targetDetected` directly

#### Scenario: Monster kill progression uses typed runtime events

- **WHEN** a non-summoned monster dies
- **THEN** `Monster` sends a GameCore `MonsterKilledEvent` through Yoki `EventKit.Type`
- **AND** kill-count quest progress listens to that typed event as the formal monster-kill notification path
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.monsterKilled` directly

#### Scenario: Player death uses direct owner collaboration

- **WHEN** the player `Hero` dies
- **THEN** `Hero` calls back into `PlayerSystem` as the formal player-death handling entry
- **AND** no project-level spawn or hero-death runtime event remains for this one-to-one lifecycle path
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.playerSpawned` or `NotificationSystem.heroKilled` directly

#### Scenario: Hero growth uses typed runtime events

- **WHEN** the player `Hero` gains experience
- **THEN** `Hero` sends a GameCore `HeroExperienceGainedEvent` through Yoki `EventKit.Type`
- **AND** event-log presentation listens to that typed event instead of the old notification field
- **WHEN** the player `Hero` levels up
- **THEN** `Hero` sends a GameCore `HeroLevelUpEvent` through Yoki `EventKit.Type`
- **AND** quest availability and event-log presentation listen to that typed event
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.experienceGained` or `NotificationSystem.levelUp` directly

#### Scenario: Inventory and ability notifications use typed runtime events

- **WHEN** money or items are added to or removed from the long-term inventory truth
- **THEN** `InventorySystem` sends the corresponding GameCore `InventoryMoney*` or `InventoryItem*` event through Yoki `EventKit.Type`
- **AND** conditions, quest progress, and event-log presentation listen to those typed events
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.moneyAdded`, `NotificationSystem.moneyRemoved`, `NotificationSystem.itemAdded`, or `NotificationSystem.itemRemoved` directly
- **WHEN** the player `Hero` equips, unequips, gains, or loses an ability
- **THEN** `Hero` sends the corresponding GameCore `Equipment*` or `HeroAbility*` event through Yoki `EventKit.Type`
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.itemEquipped`, `NotificationSystem.itemUnequipped`, `NotificationSystem.abilityAdded`, or `NotificationSystem.abilityRemoved` directly

#### Scenario: Quest progression and quest state use typed runtime events

- **WHEN** `JournalSystem` unlocks, starts, fulfils, completes, or changes availability for a quest
- **THEN** it sends the corresponding GameCore `Quest*Event` through Yoki `EventKit.Type`
- **AND** NPC quest markers, conditions, and event-log presentation listen to those typed events
- **WHEN** `QuestProgress` advances task progression
- **THEN** it sends a GameCore `QuestProgressionUpdatedEvent` through Yoki `EventKit.Type`
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.questProgressionUpdated`, `NotificationSystem.questStarted`, `NotificationSystem.questUnlocked`, `NotificationSystem.questAvailabilityChanged`, `NotificationSystem.questFullfilled`, or `NotificationSystem.questCompleted` directly

#### Scenario: Removed notification hub cannot re-enter the formal tree

- **WHEN** code, tests, or scenes try to reintroduce `NotificationSystem`
- **THEN** the foundation static gate fails validation
- **AND** the remediation path is to add a GameCore event type and `EventKit.Type` dispatch instead

### Requirement: Runtime Truth Ownership Conflicts Must Be Registered Before Implementation

`FantasyWord` MUST register and resolve framework truth conflicts before implementing new systems that would otherwise keep two same-duty owners alive.

#### Scenario: UI menu runtime conflict is resolved to the UIKit menu runtime

- **WHEN** the formal UI runtime is inspected after the menu runtime replacement
- **THEN** the menu truth is `UIManager + UIKitMenuPanelBase + UIPanel`
- **AND** `AUIMenu/UIMenuManager` do not remain as formal runtime entries for the same menus
- **AND** adapter or wrapper layers are not used to avoid choosing one runtime entry

#### Scenario: Attribute truth is not duplicated with GAS

- **WHEN** GAS `AttributeSet` is introduced into GameCore runtime
- **THEN** the change declares whether GAS replaces the current `Stats/currentStats` truth or stays out of attribute truth
- **AND** health, mana, attack, defense, and similar attributes are not displayed, saved, or calculated from both systems at the same time

#### Scenario: Input truth remains separated from binding tools

- **WHEN** new gameplay input is implemented
- **THEN** gameplay intent remains owned by the GameCore input layer or a formal mode input context
- **AND** Yoki `InputKit` may provide rebinding and tooling
- **AND** TopDown `InputManager` does not become the project input root

#### Scenario: Save truth is separated from file tooling

- **WHEN** Yoki `SaveKit` is used
- **THEN** GameCore remains the owner of world, player, inventory, quest, and card domain save data
- **AND** SaveKit may own file persistence, serializer, versioning, or migration tooling
- **AND** a second save data truth is not introduced

#### Scenario: Map truth does not absorb open-world simulation

- **WHEN** open-world features such as regions, cells, factions, schedules, economy, or local simulation are proposed
- **THEN** `MapSystem` remains responsible for map loading, checkpoints, teleportation, and respawn
- **AND** open-world simulation receives its own world runtime owner or equivalent explicit owner
- **AND** these features are not added as `GameManager.XxxSystem` shortcuts just for convenience

#### Scenario: Inventory remains a framework module with explicit target ownership

- **WHEN** inventory, equipment, container, party, reward, or card collection behavior is implemented
- **THEN** the inventory framework remains reusable
- **AND** the implementation states whether the data belongs to the player profile, party, character, container, card collection, or current mode
- **AND** concrete items, shops, UI menus, or reward tables do not define the inventory system shape

#### Scenario: Runtime collection truth is not exposed as mutable public state

- **WHEN** inventory, quest, quest-progress, equipped-item, or equipped-ability-slot runtime state is exposed to other gameplay code
- **THEN** callers use explicit query methods, read-only traversal surfaces, or explicit snapshots
- **AND** formal runtime systems do not expose their internal mutable `List`, `Dictionary`, or backing array containers as public truth
- **AND** UI, interaction, and command code do not depend on mutating those backing collections directly

#### Scenario: Database registry storage tables are not a public mutable seam

- **WHEN** gameplay or editor code needs to query or mutate database registration state
- **THEN** it uses explicit `DatabaseRegistry` methods for lookup, traversal, registration, cleanup, or GUID conversion
- **AND** the formal runtime does not expose the underlying registration table or GUID-conversion table as public mutable dictionaries
- **AND** editor automation does not rely on directly rewriting those backing tables

#### Scenario: Formal content assets do not expose backing containers as public runtime seams

- **WHEN** gameplay or editor code reads crafting recipes, quest hint overrides, game-flag task conditions, crafting-station recipes, shop items, monster loot tables, or dialogue sequence content
- **THEN** it uses explicit read-only accessors, traversal methods, counts, or snapshots provided by the owning asset type
- **AND** the formal content asset does not expose its backing `Array` or `Dictionary` container as a public mutable interface
- **AND** runtime UI, dialogue construction, loot reward, and editor validation code do not depend on mutating those backing containers directly

#### Scenario: Card auto-battler is a game mode, not a detached mini-project

- **WHEN** the card auto-battler mode is implemented
- **THEN** it may depend on player profile data, card collection, inventory rewards, save data, resources, audio, and UI services
- **AND** single-match board state, turn progression, unit state, and mode input are owned by the card mode runtime
- **AND** the match state does not depend on the open-world current map, current controlled character, or movement input truth

### Requirement: Composite Sandbox Character Foundation Must Keep Roles, Inventory, Ability, And Commands Split

`FantasyWord` MUST support a composite sandbox RPG character foundation where long-term world rules, character inventory, ability rules, RTS-style commands, and future multiplayer ownership boundaries remain split across formal owners instead of collapsing into a single all-purpose controller or a single global inventory.

#### Scenario: Character closure keeps controller, identity, and abilities separate

- **WHEN** a formal playable or controllable character is defined
- **THEN** its controller, identity, model, ability execution, rules, persistence, and presentation responsibilities remain separable
- **AND** the formal character closure does not collapse those responsibilities into one all-purpose runtime object

#### Scenario: Inventory ownership is multi-owner, not global-only

- **WHEN** inventory, equipment, quickbar, container, corpse, shop, or reward behavior is implemented
- **THEN** the implementation states which owner the inventory belongs to
- **AND** the system can distinguish player profile, party wallet, character inventory, container inventory, and world-item ownership
- **AND** a single global bag does not remain the only truth source for a multi-character party game

#### Scenario: Ability rules and ability execution stay split

- **WHEN** a character gains, loses, transforms, or equips a source of abilities
- **THEN** the ability rules layer may grant, revoke, tag, or cool down those abilities
- **AND** the action-execution layer still owns movement, weapon execution, hit windows, summon execution, and feedback
- **AND** the runtime does not duplicate the same ability truth in both layers at once

#### Scenario: RTS-style orders are routed through a formal command entry

- **WHEN** the player or AI issues a move, attack, pickup, interaction, transfer, or work-related order
- **THEN** the order enters through a formal command contract
- **AND** the selected unit, group, or context resolves ownership before the world state changes
- **AND** UI callbacks do not directly mutate world truth

#### Scenario: Future multiplayer keeps compatibility boundaries without runtime networking

- **WHEN** a change touches control, ownership, inventory, command routing, or save writes
- **THEN** the change preserves host-authority-compatible boundaries for input source, ownership, and state writing
- **AND** the runtime still does not introduce networking packages, RPCs, sync fields, network objects, or network SDK abstractions as part of the current foundation

### Requirement: Map Info Must Expose A Playtest Checkpoint

`FantasyWord` MUST provide the first map information closure aligned with `2DRPGEngine` before implementing the full map transition system.

#### Scenario: Simple checkpoint can bind to the current map

- **WHEN** a simple checkpoint has no explicit map
- **AND** the scene has a registered `MapSystem`
- **THEN** current-map resolution uses `GameManager.MapSystem.GetCurrentMapName()`
- **AND** explicit map names keep their configured position

#### Scenario: MapInfo exposes the playtest checkpoint

- **WHEN** a scene contains `MapInfo`
- **THEN** callers can read its playtest checkpoint through the formal map info contract

### Requirement: Map System Must Cover The Reference Map Closure Without Faking Player Dependencies

`FantasyWord` MUST migrate the `2DRPGEngine` `MapSystem` responsibilities as the map truth source, and player-dependent map actions MUST only exist when the formal PlayerSystem/Movable/Controller/Teleporter closure exists.

#### Scenario: GameManager exposes the map system

- **WHEN** a scene contains `GameManager` and `MapSystem`
- **THEN** callers can resolve the map system through `GameManager.MapSystem`

#### Scenario: Map system stores checkpoints

- **WHEN** a valid explicit-map checkpoint is saved
- **THEN** the map system stores it in its checkpoint stack
- **AND** `MapDataBlock` can export the stored checkpoint data

#### Scenario: Player-dependent map restoration is only enabled by the formal player closure

- **WHEN** a map data block requires first-map checkpoint teleportation or playtest teleportation
- **AND** the formal PlayerSystem/Movable/Controller/Teleporter closure exists
- **THEN** `MapSystem` may expose `TeleportTo`, `RespawnPlayer`, and `TeleportToPlaytestStartPosition`
- **AND** those methods use the formal player traversal closure, currently `PlayerSystem.GetPlayerInstance()`, rather than a fake Player, test-only Controller, or temporary Teleporter stand-in
- **AND** `Maps/Teleporter.cs` may remain in the formal GameCore tree only while player movement direction, push interruption, audio event, and MapSystem teleport dependencies are satisfied by formal closures

#### Scenario: TopDown level spawn ideas do not replace the map truth source

- **WHEN** FantasyWord absorbs TopDown `LevelManager/CheckPoint` ideas for level bounds, initial spawn, checkpoint order, respawn delay, camera target, or respawn presentation
- **THEN** `MapSystem/MapInfo/ICheckpoint` remain the formal map and checkpoint truth source
- **AND** the project does not add TopDown `LevelManager`, TopDown `GameManager`, TopDown `GUIManager`, TopDown `Health`, or MoreMountains scene loading as a second formal lifecycle

### Requirement: Persistence Data Contract Must Match The Reference Baseline

`FantasyWord` MUST provide the basic persistence data contracts before implementing the full save and persistence systems.

#### Scenario: Data block can be read as its concrete type

- **WHEN** a concrete data block derives from `DataBlock`
- **THEN** callers can read it through `As<T>()`
- **AND** the result keeps the concrete data

#### Scenario: Data block handler round-trips state

- **WHEN** a system implements `IDataBlockHandler<TDataBlock>`
- **THEN** it can load a data block
- **AND** create a data block representing the loaded state

### Requirement: Persistence System Must Cover Persistable Object Lifecycles

`FantasyWord` MUST migrate the `2DRPGEngine` `Persistable`, `PersistableReference`, and `PersistenceSystem` closure before wiring full save aggregation.

#### Scenario: GameManager exposes the persistence system

- **WHEN** a scene contains `GameManager` and `PersistenceSystem`
- **THEN** callers can resolve the persistence system through `GameManager.PersistenceSystem`

#### Scenario: Persistable exports and loads object state

- **WHEN** a persistable object creates a data block
- **THEN** the block stores its persistence information
- **AND** the block records active, inactive, or destroyed state using the reference enum

#### Scenario: Persistence system resolves stable object references

- **WHEN** a custom-instanced persistable is registered with an identifier
- **THEN** `PersistableReference<T>` resolves the object through `GameManager.PersistenceSystem`

### Requirement: Game Flags Must Use The Reference Lightweight State System

`FantasyWord` MUST migrate the `2DRPGEngine` `GameFlagSystem` closure as the lightweight boolean world-state system before wiring full save aggregation.

#### Scenario: GameManager exposes the game flag system

- **WHEN** a scene contains `GameManager` and `GameFlagSystem`
- **THEN** callers can resolve the flag system through `GameManager.GameFlagSystem`

#### Scenario: Game flag changes raise the typed runtime event

- **WHEN** a flag is set or cleared
- **THEN** `GameRuntimeEvents.NotifyGameFlagChanged(...)` sends a GameCore `GameFlagChangedEvent` through Yoki `EventKit.Type`
- **AND** project-side code does not call, subscribe to, or unsubscribe from `NotificationSystem.gameFlagChanged` directly
- **AND** the removed archived notification hub is not recreated just to carry game-flag events

#### Scenario: Game flags round-trip save data

- **WHEN** a GameFlagSystem creates and loads `GameFlagsDataBlock`
- **THEN** the string flag set is preserved without adding quest, inventory, or player dependencies

#### Scenario: Full save aggregation is not faked

- **WHEN** SaveSystem would require Inventory, Journal, or Player data blocks
- **THEN** those systems remain unmigrated until their reference closures exist
- **AND** no empty placeholder save blocks are created to claim SaveSystem completion
- **AND** `Game/Systems/InventorySystem.cs`, `Game/Systems/SaveSystem.cs`, `Game/Systems/JournalSystem.cs`, `Database/Items/Item.cs`, `Database/Items/Equipment.cs`, `Database/Items/ItemEffects/*.cs`, and `Database/Save/SaveFile.cs` do not enter the formal GameCore tree before the full inventory/item/save dependencies are migrated

### Requirement: Entity Baseline Must Cover Transform Persistence Without Pulling Gameplay Closures

`FantasyWord` MUST migrate the `2DRPGEngine` `EntityDataBlock` transform persistence baseline before pulling interaction, dialogue, UI floating icon, movable, controller, or player closures.

#### Scenario: Entity exports transform state

- **WHEN** an entity creates its persistence data block
- **THEN** the block records position, rotation, and scale

#### Scenario: Entity restores transform state

- **WHEN** an entity loads an `EntityDataBlock`
- **THEN** its transform position, rotation, and scale match the block

#### Scenario: Gameplay-heavy entity dependencies are not faked

- **WHEN** the reference `Entity` baseline is extended toward `Movable`, `PlayerController`, `Teleporter`, or `PlayerSystem`
- **THEN** no placeholder interaction, dialogue, movable, controller, hero, or player system is created
- **AND** `Controllers/IController.cs`, `Controllers/AController.cs`, `Controllers/PlayerController.cs`, `Entities/Movable.cs`, `Maps/Teleporter.cs`, and `Game/Systems/PlayerSystem.cs` MAY enter the formal GameCore tree only as the reference-aligned closure, not as test-only stand-ins or partial shells
- **AND** once that formal closure exists, further validation MUST continue on that closure instead of introducing a parallel controller path under test scripts or test scenes

#### Scenario: Interaction dependencies are not faked

- **WHEN** the reference interaction contract would require `CharacterBase`, `DialogueSequence`, or `DialogueMessageFeed`
- **THEN** the interaction closure remains unmigrated until those reference dependencies exist
- **AND** `Interactions/IInteraction.cs`, `Interactions/IInteractionTarget.cs`, `Interactions/CommandInteraction.cs`, and `Entities/Characters/CharacterBase.cs` do not enter the formal GameCore tree as empty placeholders

#### Scenario: Player instance uses the formal pre-placed scene Hero

- **WHEN** a formal runtime scene contains the player closure
- **THEN** the player `Hero` is pre-placed in the scene rather than runtime-created by `PlayerSystem`
- **AND** `PlayerSystem.m_playerInstance` is serialized to the scene `Hero` as the primary scene wiring path
- **AND** any runtime lookup of a unique `Hero` is only a missing-reference fallback, not the formal scene organization model
- **AND** validation continues on the formal `Movable / PlayerController / PlayerSystem` closure rather than a test-only player controller

#### Scenario: Direct-play validation scenes use their own scene organization

- **WHEN** a formal direct-play validation scene such as `ClickMoveTest` enters PlayMode
- **THEN** validation continues on that scene's own `Game Manager + scene systems + pre-placed Hero` organization
- **AND** entering PlayMode does not redirect startup through the `M2DEngine + GameConfig` playtest snapshot path
- **AND** the scene does not rely on a root marker or editor playtest override to bypass a second startup chain

#### Scenario: Direct-play movement validation scenes start from a usable runtime state

- **WHEN** a formal direct-play movement validation scene such as `ClickMoveTest` enters PlayMode
- **THEN** the active scene camera organization and the pre-placed player prefab together expose exactly one active `AudioListener`
- **AND** the pre-placed `Hero` starts at a position that does not overlap blocking 2D colliders
- **AND** the scene does not depend on repeated startup recovery from "player stuck inside a collider" just to become playable

### Requirement: Checkpoint Variants Must Match The Reference Map Closure

`FantasyWord` MUST provide the `2DRPGEngine` checkpoint variants that are supported by the current persistence and map closures.

#### Scenario: Persistable checkpoint resolves position by stable reference

- **WHEN** a checkpoint component is registered as a persistable object
- **THEN** `PersistableCheckpoint` resolves its position through `PersistableReference<Checkpoint>`

### Requirement: Ability Permission Must Absorb TopDown Blocking Without Importing TopDown Lifecycle

`FantasyWord` MUST evaluate active ability permission through the formal GameCore ability closure while absorbing the useful TopDown `CharacterAbility` permission pattern.

#### Scenario: Active ability permission uses one GameCore truth source

- **WHEN** a character attempts to trigger an active ability
- **THEN** cooldown and mana are checked by `ActiveAbilityBase`
- **AND** action permission, character condition blocking, movement blocking, and other-ability weapon-state blocking are checked through `AbilityPermissionSettings`
- **AND** failed permission maps to the existing ability fire failure path instead of silently starting the ability

#### Scenario: TopDown state ideas do not become a second character runtime

- **WHEN** FantasyWord absorbs TopDown ability permission, process, or animator-update ideas
- **THEN** the formal implementation remains in `AbilityPermissionSettings`, `ActiveAbilityBase`, `AbilityBase`, and `CharacterBase`
- **AND** the project does not add TopDown `Character`, `CharacterAbility`, `Health`, `InputManager`, `GameManager`, or MoreMountains state machines as gameplay truth sources

#### Scenario: Ability animation state has a formal update touchpoint

- **WHEN** `CharacterBase` updates its abilities
- **THEN** each ability may update cooldowns
- **AND** each ability receives a formal animation-state update touchpoint
- **AND** this touchpoint does not require a second Animator parameter registry or TopDown animator system

### Requirement: Rejected Self-Made Foundation Must Not Remain In The Formal Startup Chain

`FantasyWord` MUST reject the old self-made foundation chain from formal startup wiring and completion evidence.

#### Scenario: Static gate rejects old startup wiring

- **WHEN** the foundation static gate runs
- **THEN** `Assets/Scenes/SampleScene.unity` does not contain the old `FantasyWordBootstrapper`
- **AND** it does not contain the old `FantasyWordModuleInstaller`
- **AND** it does not reference the old default module assets as the formal startup chain

#### Scenario: Completion evidence uses the reference-aligned closure

- **WHEN** this change is assessed for completion
- **THEN** tests or notes that only prove `RuntimeContext`, `ServiceRegistry`, `EventBus`, or `ModuleInstaller` behavior do not count as foundation completion evidence
- **AND** completion must be supported by the `GameManager + AGameSystem` closure and later by Database, Map, Persistence, Command/Interaction, and Entity/Controller reference matrices

#### Scenario: Compatibility layers do not re-enter the formal codebase

- **WHEN** the plugin facade boundary gate inspects project-side runtime and editor C# under `Assets/Scripts` and `Assets/Editor`
- **THEN** gameplay code does not introduce `Compatibility`, `Compat`, `FoundationSupport`, `Adapter`, `Wrapper`, or `Facade` path segments or type names to keep multiple same-duty implementations alive
- **AND** AIBridge editor recovery code may remain under the explicit editor automation bridge path because it is not a gameplay compatibility layer

#### Scenario: Third-party lifecycle systems do not become gameplay truth sources

- **WHEN** the plugin facade boundary gate inspects project-side runtime and editor C# under `Assets/Scripts` and `Assets/Editor`
- **THEN** gameplay code does not directly depend on MoreMountains lifecycle types, TopDown manager events, TopDown GUI/Input/Level manager singletons, or YokiFrame Architecture/SingletonKit lifecycle APIs
- **AND** TopDown ideas may only appear as absorbed GameCore implementation patterns or comments explaining source boundaries
- **AND** YokiFrame may be used as a tool layer for pools, save files, input binding, generated keys, localization, scene keys, and UI utilities without becoming the game lifecycle owner

#### Scenario: MoreMountains feedbacks stay behind the GameCore presentation boundary

- **WHEN** FantasyWord uses `MMFeedbacks` from the imported TopDown/MoreMountains feedback package
- **THEN** direct `MMFeedbacks` fields and `PlayFeedbacks` calls are allowed only in the registered `GameCore` presentation feedback boundary
- **AND** gameplay ability, weapon, health, input, map, UI, or manager code does not scatter `MMFeedbacks` dependencies
- **AND** feedback playback does not make MoreMountains `Health`, `Weapon`, `CharacterAbility`, `InputManager`, `GUIManager`, `LevelManager`, or scene lifecycle systems the formal gameplay truth source

### Requirement: Movement And Scene Organization Gaps Must Stay As Registered Reference Gaps

`FantasyWord` MUST treat the remaining 2D movement and scene-organization gaps as reference gaps until a direct single-player/local reference closure exists, instead of filling them with project-made placeholders.

#### Scenario: uMMORPG remains a local evidence source, not a replacement runtime

- **WHEN** FantasyWord cites `uMMORPG Remastered - MMORPG Engine [2.41]`
- **THEN** it may absorb only the source-proven movement and scene-organization contracts already registered in the change documentation
- **AND** it does not treat `uMMORPG` as the formal replacement runtime for current single-player `GameCore`
- **AND** Mirror lifecycle, MMORPG product flow, 3D NavMesh/CharacterController movement, and instance business code do not enter the formal runtime merely because they exist in that reference

#### Scenario: First-level movement and scene gaps are not implemented without a direct reference

- **WHEN** the project still lacks a direct single-player/local reference closure
- **THEN** the following first-level framework gaps remain recorded instead of being implemented as project-side placeholders:
  - single-player/local 2D navigation provider
  - 2D click-to-move execution closure
  - single-player/local scene instance host
  - single-player/local spawn-routing host
- **AND** the project does not add `NavigationProvider`, `ClickMoveController`, `InstanceHost`, `SpawnRoutingHost`, or equivalent placeholder gameplay types just to occupy those responsibilities
- **AND** those first-level gaps are treated only as 2D movement and scene-organization reference gaps, not as a claim that open-world simulation gaps are already covered

### Requirement: Networking Is A Boundary, Not A Current Foundation Implementation Target

`FantasyWord` MUST treat networking as a future candidate and preserve host-authority-compatible boundaries in the foundation, while still refusing to create network framework placeholders merely for future optionality.

#### Scenario: Single-player foundation remains the formal baseline

- **WHEN** foundation code, docs, directories, or specs define current runtime boundaries
- **THEN** they describe a single-player open-world baseline
- **AND** they do not introduce `Networking` directories, network SDK abstractions, network module assets, multiplayer context containers, Mirror/NGO lifecycle hooks, or equivalent placeholders as current architecture
- **AND** separation of input, command, world state, ownership, and presentation is documented as single-player maintainability, not as multiplayer preparation

#### Scenario: Future multiplayer compatibility lives in the rules, not in runtime placeholders

- **WHEN** the change introduces or rewires player input, ownership, item transfer, combat, status effects, or save writes
- **THEN** it preserves a clear boundary between input source and world裁决
- **AND** it keeps the path ready for future host-authority multiplayer without adding runtime networking abstractions
- **AND** it does not imply that networking is already implemented or partially implemented

#### Scenario: Second-level movement and scene features do not bypass the first-level gaps

- **WHEN** a proposed feature depends on the unresolved movement and scene gaps
- **THEN** that feature stays recorded as a derived framework gap rather than being forced into the runtime
- **AND** this includes current-controlled-target world traversal unification, move-closer-then-act behavior for skills or interactions, and teleporter entry-condition routing
- **AND** those features are not hardcoded into `Movable`, `PlayerController`, `MapSystem`, `MapInfo`, `Teleporter`, or `PlayerSystem` before the needed first-level references exist

### Requirement: Third-Party And Candidate Assets Must Be Protected During Foundation Cleanup

`FantasyWord` MUST not delete or rewrite third-party plugins, MiniFantasy demo assets, scenes, prefabs, or candidate EquipmentSystem assets merely because they are outside the current foundation closure.

#### Scenario: Foundation cleanup encounters non-foundation assets

- **WHEN** cleanup finds a plugin,素材包 demo, scene, prefab, script, or candidate equipment asset outside the current formal foundation
- **THEN** it records the asset as third-party, reference, archive, or candidate material
- **AND** it does not delete, move, or rewrite that asset unless a separate reference matrix and user decision authorize the change
