# 参考源调查：2DARPGEngine（2026-03-09）

## 路径

- 主要参考工程：`E:\back\gameObject\project\2DARPGEngine`
- 旁边疑似相关工程：`E:\back\gameObject\project\2d rpg`

## `JKFrame` 搜索结论

先前搜索范围只覆盖了恢复目录，后来经用户指出，`JKFrame` 实际位于：

- `C:\Gamedev\Unity\Engine\2DRPGEngine\Assets\JKFrame`

### 已确认存在

- 顶层目录：
  - `Editor`
  - `Plugins`
  - `Prefabs`
  - `Scripts`
  - `Setting`
- 已确认关键框架文件包括：
  - `Scripts/1.Base/Singleton/Singleton.cs`
  - `Scripts/1.Base/Singleton/SingletonMono.cs`
  - `Scripts/2.System/1.Pool/PoolSystem.cs`
  - `Scripts/2.System/2.Event/EventSystem.cs`
  - `Scripts/2.System/9.UI/UISystem.cs`
  - `Scripts/2.System/9.UI/UI_WindowBase.cs`

### 当前判断

- 之前“当前环境没有 `JKFrame`”这个结论是错误的
- 正确结论是：
  1. `JKFrame` **存在**
  2. 只是**不在之前搜索的恢复目录中**
  3. 它位于新的引擎目录 `C:\Gamedev\Unity\Engine\2DRPGEngine`

## `JKFrame` 对当前恢复工作的价值

`JKFrame` 更偏框架底座，当前已确认可作为以下模块的直接参考：

- 单例模式
- 对象池系统
- 事件系统
- UI 系统
- 窗口基类

这与当前 `FantasyWord` 已经先行重建的 `ZFrame` 最小骨架高度相关，尤其适合继续校正：

- `Singleton`
- `PoolMgr`
- 事件中心
- UI 管理器 / 面板基类

## `Mythril2D` 结论

`2DARPGEngine` 中确认存在完整的 `Mythril2D` 目录：

- `E:\back\gameObject\project\2DARPGEngine\Assets\Mythril2D`

它与 `FantasyWorld` / `FantasyWord` 当前要恢复的内容高度重合，已定位到的对应模块包括：

- `Database/AssetMenuIndexer`
- `Database/DatabaseEntry`
- `Database/Items/Item`
- `Database/Items/Equipment`
- `Database/Items/ItemEffects/*`
- `Game/Systems/InventorySystem`
- `Animation/EquipmentSpriteLibraryUpdater`
- `UI/Menus/Inventory/UIInventory*`
- `UI/HUD/ItemDetails/UIItemDetails`
- `Dialogue/DialogueChannel`
- `Dialogue/DialogueNode`
- `Game/Systems/DialogueSystem`
- `Commands/AddOrRemoveItem`
- `Conditional/Conditions/IsItemInInventory`
- `Interactions/IInteraction`
- `Interactions/IInteractionTarget`
- `Combat/Abilities/*`

## 质量情况

- `Mythril2D` 不是完全健康
- 一些关键大文件也有损坏现象，例如：
  - `InventorySystem.cs`
  - `EquipmentSpriteLibraryUpdater.cs`
  - `DatabaseEntry.cs`
  - `AssetMenuIndexer.cs`
- 但也有不少轻量文件仍然可读，可直接作为恢复参考，例如：
  - `INameable.cs`
  - `UIEffectIcon.cs`
  - `UIStat.cs`
  - `PassiveAbilitySheet.cs`
  - `NPCSheet.cs`
  - `Inn.cs`

## 对当前恢复工作的意义

- 现在参考源关系应修正为：
  1. `FantasyWorld`：第一手旧项目源码来源
  2. `JKFrame`：框架底座参考源
  3. `Mythril2D`：2D RPG 业务层参考源
- 后续恢复原则调整为：
  1. 先以 `FantasyWorld` 中仍健康的文件为第一手来源
  2. 若是框架基础层损坏，则优先参考 `JKFrame`
  3. 若是 RPG 业务层损坏，则优先参考 `2DARPGEngine/Mythril2D`
  3. 若两边都损坏，再按上下文和系统设计重建

## 后续动作

- 框架相关模块优先与 `JKFrame` 对照修正
- 背包 / 换装 / 对话 / Ability 系统优先与 `Mythril2D` 对照恢复
