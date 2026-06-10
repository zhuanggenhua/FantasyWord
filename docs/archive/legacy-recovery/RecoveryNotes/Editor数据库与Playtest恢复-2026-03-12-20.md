# Editor 数据库窗口与 Playtest 恢复（2026-03-12）

## 本轮策略

- 按用户确认的恢复策略执行：
  - 损坏或缺失文件优先直接迁移同名参考实现
  - 只做当前工程所需的薄适配
- 本轮纠偏：
  - `_Editor/DatabaseWindow/DatabaseWindow.cs`
  - `_Editor/Playtest/EditorPlayModeOverride.cs`
  - 这两个文件并不是“无同名参考”，而是在 `Mythril2D/Core/Editor` 下有可直接迁移版本

## 本轮完成

### Editor 工具

- 新增：
  - `Assets/Scripts/_Editor/DatabaseWindow/DatabaseWindow.cs`
  - `Assets/Scripts/_Editor/Playtest/EditorPlayModeOverride.cs`

### 宿主适配

- 扩展：
  - `Assets/Scripts/Game/Systems/SaveDataBlocks.cs`
  - `Assets/Scripts/Game/Systems/MapSystem.cs`

## 关键适配点

### DatabaseWindow

- 保留参考版的 ScriptableObject 缓存与数据库浏览窗口结构
- 适配当前工程已有类型：
  - `HeroSheet`
  - `MonsterSheet`
  - `NPCSheet`
  - `AbilitySheet`
  - `Item`
  - `Shop`
  - `Recipe`
  - `CraftingStation`
  - `Inn`
  - `Quest`
  - `QuestTask`
  - `DialogueSequence`
  - `SaveFile`
  - `NavigationCursorStyle`
  - `GameConfig`
  - `DatabaseRegistry`
- 去掉当前工程不存在的标签类型：
  - `AudioClipResolver`
  - `CommandHandler`
- `PrefabReference` 仅在 `ODIN_INSPECTOR` 条件下加入

### EditorPlayModeOverride

- 保留参考版“地图编辑场景直接启动 Playtest”的 editor 工作流
- 薄适配为当前工程可用接口：
  - 启动场景不再依赖 `Constants.M2DEngineSceneName`
  - 改为优先查找 `SampleScene`，找不到再回退到 Build Settings 首个启用场景
  - 不再依赖参考工程的 `SaveFile.content`
  - 改为构造当前工程可用的 `SaveDataBlock`
- 为承接这条 editor 流程，补回：
  - `MapDataBlock.playtest`
  - `MapSystem.LoadDataBlock` 中的 playtest checkpoint 传送逻辑

## 编译验证

- `RecoveryNotes/unity-batch-compile-20260312-26.log`
- 结果：通过

## 差集变化

- `missing-scripts-after-journal-current.txt`
  - 本轮前：`7`
  - 本轮后：`5`

## 当前剩余

1. `Entities/Characters/States/CharacterAnimState.cs`
2. `Entities/Characters/States/CharacterStateBase.cs`
3. `Entities/Characters/States/CharacterTriggerState.cs`
4. `GameSystem/Input/InputSystemGenerator.cs`
5. `MultiTrack.cs`

## 额外结论

- 这 5 个文件在当前工程中没有任何代码引用
- 可访问参考源中也没有同名可读实现
- 因此下一步已经进入“无同名参考的自主设计恢复”分支，不再是简单的同名迁移批次
