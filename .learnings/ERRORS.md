## [ERR-20260313-003] corrupted-minifantasy-candidates-are-not-readable-logic-sources

**Logged**: 2026-03-13T10:40:00+08:00
**Priority**: high
**Status**: pending
**Area**: assets

### Summary
从损坏备份迁入的 `MiniFantasy` 候选场景/脚本，不能仅因为路径和名字对上，就当成可直接恢复的逻辑源。当前拿到的候选 `.cs` 与 `.unity` 文件都呈现明显非文本特征。

### Error
```text
Binary-readability check:
- Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scripts/TH_DemoManager.cs
  size=3616 nulls=10 printable_ratio=0.368
- Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scenes/Demo - True Heroes Animations.unity
  size=486746 nulls=15 printable_ratio=0.378
- E:/back/gameObject/project/2DARPGEngine/Assets/KrishnaPalacio/MINIFANTASY - Dungeon/Scripts/DUN_AnimatedCharacterSelection.cs
  size=1770 nulls=6 printable_ratio=0.379
```

### Context
- Command/operation attempted: locating the real `MiniFantasy + UV dressing` test environment after user correction
- Environment: current project `C:\Gamedev\Unity\Project\FantasyWord` plus accessible backups under `E:\back\gameObject\project\*`

### Suggested Fix
先区分“素材源”和“逻辑源”。如果 `.cs` 不是正常文本源码，就不要继续按同名迁移脚本的路线推进；如果 `.unity` 只能当黑盒资产，就把它留给真实 Unity Editor 打开验证，或直接基于已迁入素材重建一个新的最小测试场景宿主。

### Metadata
- Reproducible: yes
- Related Files: Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scripts/TH_DemoManager.cs, Assets/ArtRes/KrishnaPalacio/MINIFANTASY - Crafting and Professions I/Scenes/Demo - True Heroes Animations.unity, E:/back/gameObject/project/2DARPGEngine/Assets/KrishnaPalacio/MINIFANTASY - Dungeon/Scripts/DUN_AnimatedCharacterSelection.cs
- See Also: ERR-20260313-002

---

## [ERR-20260313-002] dressing-scene-misread-as-visible-armor

**Logged**: 2026-03-13T09:10:00+08:00
**Priority**: high
**Status**: pending
**Area**: scope

### Summary
把 `SampleScene` 里的铁甲三件套误当成“可见换装素材”会导致主线判断失真。当前仓里这 3 个装备资源只验证装备功能，不验证可见换装。
### Error
```text
Assumption error:
- ITEM_Iron_Helmet / ITEM_Iron_Plate / ITEM_Iron_Boots were treated as visible dressing assets.
- In both current project and Mythril2D reference, these assets have no equippedSprite and no visualOverride.
- The visible equipment example in reference project is weapon sprite-library switching, not armor dressing.
```

### Context
- Command/operation attempted: dressing-scene gap assessment around `SampleScene`, `Devon.prefab`, and test gear assets
- Environment: `C:\Gamedev\Unity\Project\FantasyWord`

### Suggested Fix
先区分“装备功能验证”和“装备显示验证”。如果目标是可见换装，先确认仓里是否存在完整资源链：装备 asset、sprite libraries、显示宿主 prefab、对应能力或显示节点。若这些都不存在，不要把占位装备当成可见换装素材继续推进。
### Metadata
- Reproducible: yes
- Related Files: Assets/Scenes/SampleScene.unity, Assets/Database/Items/Gear/ITEM_Iron_Helmet.asset, Assets/Database/Items/Gear/ITEM_Iron_Plate.asset, Assets/Database/Items/Gear/ITEM_Iron_Boots.asset, Assets/Scripts/Animation/EquipmentSpriteLibraryUpdater.cs
- See Also: ERR-20260313-001

---

## [ERR-20260311-001] unity-batch-compile-log-missing

**Logged**: 2026-03-11T20:56:18.2248490+08:00
**Priority**: medium
**Status**: pending
**Area**: tests

### Summary
在 Codex shell 里直接执行 Unity 批处理时，命令返回 `0`，但指定 `-logFile` 没有生成。

### Error
```text
rg: RecoveryNotes/unity-batch-compile-20260311-7.log: IO error for operation on RecoveryNotes/unity-batch-compile-20260311-7.log: 系统找不到指定的文件。 (os error 2)
Get-Content : 找不到路径“C:\Gamedev\Unity\Project\FantasyWord\RecoveryNotes\unity-batch-compile-20260311-7.log”，因为该路径不存在。
```

### Context
- Command/operation attempted: `& 'C:\Gamedev\Unity\Editor\6000.3.10f1\Editor\Unity.exe' -batchmode -quit -projectPath 'C:\Gamedev\Unity\Project\FantasyWord' -logFile 'C:\Gamedev\Unity\Project\FantasyWord\RecoveryNotes\unity-batch-compile-20260311-7.log'`
- Environment: Codex workspace shell on Windows, project root `C:\Gamedev\Unity\Project\FantasyWord`

### Suggested Fix
对 Unity 批处理编译优先使用提权执行，并在完成后立即校验日志文件是否实际生成。

### Metadata
- Reproducible: unknown
- Related Files: RecoveryNotes/unity-batch-compile-20260311-7.log

---

## [ERR-20260312-009] wrong-agamesystem-path

**Logged**: 2026-03-12T23:45:00+08:00
**Priority**: low
**Status**: pending
**Area**: docs

### Summary
误把 `AGameSystem.cs` 当成仍然位于 `Assets/Plugins/ZFrame/...` 下的插件宿主文件；当前项目真实路径在 `Assets/Scripts/Game/Systems/AGameSystem.cs`。
### Error
```text
Get-Content : Cannot find path 'Assets/Plugins/ZFrame/RunTime/Manager/AGameSystem.cs' because it does not exist.
```

### Context
- Command/operation attempted: reading `AGameSystem.cs` during host compatibility audit
- Environment: `C:\Gamedev\Unity\Project\FantasyWord`

### Suggested Fix
在这个仓里查运行时宿主基类时，优先从 `Assets/Scripts/Game/Systems` 或更窄目录搜索，不要先假设它还保留在 `ZFrame` 插件层。
### Metadata
- Reproducible: yes
- Related Files: Assets/Scripts/Game/Systems/AGameSystem.cs
- See Also: ERR-20260312-010

---

## [ERR-20260312-010] broad-rg-timeout-on-known-target

**Logged**: 2026-03-12T23:48:00+08:00
**Priority**: medium
**Status**: pending
**Area**: tooling

### Summary
在当前 PowerShell 环境下，对已知小目标仍使用宽范围枚举命令会明显超时，例如先列全量文件再二次 `rg` 过滤 `AGameSystem.cs`。
### Error
```text
rg --files Assets\Scripts Assets\Plugins | rg 'AGameSystem\.cs$'
command timed out after 376000+ ms
```

### Context
- Command/operation attempted: locating `AGameSystem.cs`
- Environment: `C:\Gamedev\Unity\Project\FantasyWord`

### Suggested Fix
已知目标优先直接读确定路径；不确定时先缩小 root 再用 `rg` 或 `Get-ChildItem`，避免先做整树枚举。
### Metadata
- Reproducible: yes
- Related Files: Assets/Scripts/Game/Systems/AGameSystem.cs
- See Also: ERR-20260312-009

---

## [ERR-20260312-011] reference-guid-full-scan-timeout

**Logged**: 2026-03-12T23:56:00+08:00
**Priority**: medium
**Status**: pending
**Area**: tooling

### Summary
直接为整棵 reference 资源树建立 `.meta -> guid` 全量索引，在 20-30 秒时间窗内容易超时；这样做不适合当前仓的 UI 资源闭包排查。
### Error
```text
command timed out after 20209 ms
command timed out after 20198 ms
command timed out after 30725 ms
```

### Context
- Command/operation attempted: building full GUID index for `2DRPGEngine` / old `FantasyWorld` reference trees
- Environment: `C:\Gamedev\Unity\Project\FantasyWord`

### Suggested Fix
先扫描当前工程 + 当前 `Library/PackageCache` 得到真实缺失 GUID，再只对差集做定点反查；不要先做整个 reference 树的全量索引。
### Metadata
- Reproducible: yes
- Related Files: Assets/Prefabs/UI/User Interface.prefab, Assets/Prefabs/UI/Overlay/Dialogue.prefab
- See Also: ERR-20260312-010

---

## [ERR-20260312-007] unity-batch-compile-upm-sandbox-blocked

**Logged**: 2026-03-12T16:58:24.5857476+08:00
**Priority**: medium
**Status**: pending
**Area**: infra

### Summary
在当前 Codex 沙箱里运行 Unity `-batchmode -quit`，可能会先被 `LocalLow/Unity` 目录权限和 Unity Package Manager IPC 连接问题卡死，不能直接把这类失败当成脚本编译失败。

### Error
```text
CreateDirectory 'C:/Users/CodexSandboxOnline/AppData/LocalLow/Unity' failed: 拒绝访问。
[Package Manager] Could not establish a connection with the Unity Package Manager local server process.
Exiting without the bug reporter. Application will terminate with return code 1
```

### Context
- Command/operation attempted: Unity batch compile to `RecoveryNotes/unity-batch-compile-20260312-29.log` and `RecoveryNotes/unity-batch-compile-20260312-30.log`
- Environment: `C:\Gamedev\Unity\Project\FantasyWord`

### Suggested Fix
先检查日志里是否真的出现 `error CS`、`Scripts have compiler errors` 等脚本错误；如果没有，而失败集中在 `LocalLow/Unity` 权限或 `Upm-*` IPC 连接，则改用 Unity 自带 Roslyn 重放 `Library/Bee/.../Assembly-CSharp.rsp`，并用显式退出码确认结果。

### Metadata
- Reproducible: yes
- Related Files: RecoveryNotes/unity-batch-compile-20260312-29.log, RecoveryNotes/unity-batch-compile-20260312-30.log, Library/Bee/artifacts/1900b0aEDbg.dag/Assembly-CSharp.codex-validate.rsp
- See Also: ERR-20260312-006

---

## [ERR-20260311-002] powershell-rg-quote-escaping

**Logged**: 2026-03-11T23:45:00+08:00
**Priority**: low
**Status**: pending
**Area**: docs

### Summary
PowerShell 下把带双引号的 `rg` 模式串直接塞进命令字符串时，容易因为引号转义失败而提前中断。

### Error
```text
字符串缺少终止符: "。
FullyQualifiedErrorId : TerminatorExpectedAtEndOfString
```

### Context
- Command/operation attempted: `rg -n "...\"..." Assets/Scripts`
- Environment: Windows PowerShell, Codex workspace shell

### Suggested Fix
优先对 `rg` 的 pattern 使用单引号包裹；如果 pattern 本身包含单引号，再改为分步转义或拆分查询。

### Metadata
- Reproducible: yes
- Related Files: task_plan.md, progress.md

---

## [ERR-20260311-003] zframe-assembly-project-dependency

**Logged**: 2026-03-11T23:47:00+08:00
**Priority**: medium
**Status**: pending
**Area**: config

### Summary
`Assets/Plugins/ZFrame` 下的插件程序集不能直接引用项目层 `GameManager` 或 `UnityEngine.InputSystem`，否则会在 `ZFrame.dll` 编译阶段失败。

### Error
```text
Assets\Plugins\ZFrame\RunTime\Manager\UI\UIMgr.cs(...): error CS0103: 当前上下文中不存在名称“GameManager”
Assets\Plugins\ZFrame\RunTime\Manager\UI\UIMgr.cs(...): error CS0234: 命名空间“UnityEngine”中不存在类型或命名空间名“InputSystem”
```

### Context
- Command/operation attempted: Unity batch compile to `RecoveryNotes/unity-batch-compile-20260311-13.log`
- Environment: `ZFrame.dll` plugin assembly compiled before `Assembly-CSharp`

### Suggested Fix
插件程序集只保留不依赖项目层的通用逻辑；凡是需要 `GameManager`、当前工程事件或 InputSystem 的输入分发，统一放回 `Assets/Scripts` 下的系统脚本。

### Metadata
- Reproducible: yes
- Related Files: Assets/Plugins/ZFrame/RunTime/Manager/UI/UIMgr.cs, Assets/Scripts/Game/Systems/UISystem.cs

---

## [ERR-20260311-004] missing-serializable-dictionary-dependency

**Logged**: 2026-03-11T23:59:00+08:00
**Priority**: medium
**Status**: pending
**Area**: config

### Summary
从 `Mythril2D` 直接迁入 `PolydirectionalAnimationStrategy` 时，参考实现依赖的 `SerializableDictionary` 在当前工程并不存在。

### Error
```text
Assets\Scripts\Animation\Strategies\PolydirectionalAnimationStrategy.cs(...): error CS0246: 未能找到类型或命名空间名“SerializableDictionary<,>”
```

### Context
- Command/operation attempted: Unity batch compile to `RecoveryNotes/unity-batch-compile-20260311-15.log`
- Environment: `C:\Gamedev\Unity\Project\FantasyWord`

### Suggested Fix
对参考脚本先检查第三方序列化/字典依赖；如果当前工程没有同依赖，优先改为 Unity 原生可序列化数组或列表绑定，而不是为单个脚本额外引入库。

### Metadata
- Reproducible: yes
- Related Files: Assets/Scripts/Animation/Strategies/PolydirectionalAnimationStrategy.cs, RecoveryNotes/unity-batch-compile-20260311-15.log
- See Also: ERR-20260311-003

---

## [ERR-20260312-005] missing-list-path-normalization

**Logged**: 2026-03-12T07:50:00+08:00
**Priority**: low
**Status**: pending
**Area**: docs

### Summary
重算 `RecoveryNotes/missing-scripts-after-journal-current.txt` 时，如果不先统一参考清单与本地枚举结果的路径分隔符和转义形式，差集数量会失真。

### Error
```text
第一次比较后仍然显示 28 条旧缺口；
第二次只统一了部分反斜杠，结果误报为 153 条全部缺失。
```

### Context
- Command/operation attempted: PowerShell compare between `RecoveryNotes/missing-scripts-after-journal.txt` and current `Assets/Scripts` tree
- Environment: `C:\Gamedev\Unity\Project\FantasyWord`

### Suggested Fix
比较前统一把两侧路径归一化到同一种分隔符，优先使用 `/`，并先把参考清单里的转义 `\\` 还原，再做 membership/Compare-Object。

### Metadata
- Reproducible: yes
- Related Files: RecoveryNotes/missing-scripts-after-journal.txt, RecoveryNotes/missing-scripts-after-journal-current.txt
- See Also: ERR-20260311-002

---

## [ERR-20260312-006] apply-patch-context-mismatch

**Logged**: 2026-03-12T15:20:00+08:00
**Priority**: low
**Status**: pending
**Area**: docs

### Summary
在大块补丁同时改多文件时，如果没有先抓取精确上下文，`apply_patch` 会因为上下文失配直接拒绝整批写入。

### Error
```text
apply_patch verification failed: Failed to find expected lines in
C:\Gamedev\Unity\Project\FantasyWord\Assets\Scripts\Entities\Movable.cs:
    public virtual void StopMoving()
```

### Context
- Command/operation attempted: one large `apply_patch` covering `Movable.cs`、`CharacterBase.cs`、`MapSystem.cs` 和新增文件
- Environment: `C:\Gamedev\Unity\Project\FantasyWord`

### Suggested Fix
先用 `Get-Content` 抓取将要修改的精确片段，再按“小块、逐文件”方式下补丁；大文件重写优先使用 `Delete File + Add File` 或拆分补丁，避免整批失败。

### Metadata
- Reproducible: yes
- Related Files: Assets/Scripts/Entities/Movable.cs
- See Also: ERR-20260312-005

---

## [ERR-20260312-007] zframe-savefile-cross-assembly-dependency

**Logged**: 2026-03-12T23:30:00+08:00
**Priority**: high
**Status**: pending
**Area**: config

### Summary
`Assets/Plugins/ZFrame/ZFrame.asmdef` 内的 `SaveFile.cs` 不能直接依赖 `Assembly-CSharp` 中定义的 `SaveDataBlock`；否则真实 `ZFrame.rsp` 校验会直接失败。

### Error
```text
Assets\Plugins\ZFrame\RunTime\Manager\Save\Data\SaveFile.cs(12,12): error CS0246: 未能找到类型或命名空间名“SaveDataBlock”
Assets\Plugins\ZFrame\RunTime\Manager\Save\Data\SaveFile.cs(9,30): error CS0246: 未能找到类型或命名空间名“SaveDataBlock”
```

### Context
- Command/operation attempted: `csc.dll @Library\Bee\artifacts\1900b0aEDbg.dag\ZFrame.rsp`
- Environment: `SaveFile.cs` 位于 `Assets/Plugins/ZFrame`，由 `ZFrame.asmdef` 单独编译

### Suggested Fix
跨程序集默认模板数据不要直接共享 `Assembly-CSharp` DTO；优先改成 `string` / `TextAsset` JSON 桥接，或把共享数据类型下沉到双方都可见的公共程序集。

### Metadata
- Reproducible: yes
- Related Files: Assets/Plugins/ZFrame/RunTime/Manager/Save/Data/SaveFile.cs, Assets/Scripts/Game/Systems/SaveSystem.cs
- See Also: ERR-20260311-003

---

## [ERR-20260312-008] codex-validate-rsp-missing-new-sources

**Logged**: 2026-03-12T23:35:00+08:00
**Priority**: medium
**Status**: pending
**Area**: tests

### Summary
`Assembly-CSharp.codex-validate.rsp` 在当前会话里不会自动补上新建的 `Assets/Scripts` 源文件；若直接拿它复编，会把“缺少新类型”误判成代码错误。

### Error
```text
Assets\Scripts\UI\Menus\AUIMenu.cs(7,56): error CS0246: 未能找到类型或命名空间名“IUIMenu”
Assets\Scripts\Game\GameManager.cs(33,19): error CS0246: 未能找到类型或命名空间名“GameStateSystem”
Assets\Scripts\Game\GameManager.cs(35,19): error CS0246: 未能找到类型或命名空间名“NotificationSystem”
Assets\Scripts\Game\GameManager.cs(36,19): error CS0246: 未能找到类型或命名空间名“PersistenceSystem”
Assets\Scripts\Game\Systems\AudioSystem.cs(30,48): error CS0246: 未能找到类型或命名空间名“AudioChannel”
Assets\Scripts\Database\Game\GameConfig.cs(118,30): error CS0246: 未能找到类型或命名空间名“AudioClipResolver”
```

### Context
- Command/operation attempted: `csc.dll @Library\Bee\artifacts\1900b0aEDbg.dag\Assembly-CSharp.codex-validate.rsp`
- Environment: Unity Roslyn validate rsp was generated before this round's new `Assets/Scripts` files were added

### Suggested Fix
校验 `Assembly-CSharp` 时，先确认新增源码是否已经出现在 rsp 里；如果没有，显式追加这些新文件路径，再把编译结果当成可信结论。

### Metadata
- Reproducible: yes
- Related Files: Library/Bee/artifacts/1900b0aEDbg.dag/Assembly-CSharp.codex-validate.rsp, Assets/Scripts/Game/GameManager.cs
- See Also: ERR-20260312-007

---
## [ERR-20260312-009] prefab-variant-needs-base-prefab-closure

**Logged**: 2026-03-12T23:58:00+08:00
**Priority**: medium
**Status**: pending
**Area**: assets

### Summary
只扫描迁入后的 prefab 文件本身不够；像 `Devon.prefab` 这种 prefab variant 可能看起来已经进仓，但实际仍然依赖缺失的 base prefab。

### Error
```text
Assets/Prefabs/Entities/Characters/Heroes/Devon.prefab
  -> missing guid 5865f29bb760d4342b20bf32a1e06ca8
  -> source prefab 0_Hero_Base.prefab not present in current project
```

### Context
- Command/operation attempted: 对当前仓的 `Devon.prefab` 做 GUID 闭包扫描
- Environment: `Devon.prefab` 已迁入，但 `0_Hero_Base.prefab` / `0_Character_Base.prefab` / `0_Entity_Base.prefab` 还未同步

### Suggested Fix
当迁入 prefab variant 时，必须递归检查 `m_SourcePrefab` 链；至少把 base prefab 闭包扫到“只剩 Unity 内置 GUID”后，才能把该 prefab 视为可用宿主。

### Metadata
- Reproducible: yes
- Related Files: Assets/Prefabs/Entities/Characters/Heroes/Devon.prefab, Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab
- See Also: ERR-20260312-008

---
## [ERR-20260313-001] unity-batch-execute-method-blocked-before-validator

**Logged**: 2026-03-13T08:15:00+08:00
**Priority**: high
**Status**: pending
**Area**: tests

### Summary
在当前 Codex 沙箱里，尝试用 `Unity.exe -batchmode -executeMethod DressUpSceneValidator.RunBatchValidation` 做 `SampleScene` 运行时验证时，Unity 会在进入项目与执行验证器之前就被 `LocalLow/Unity` 权限和 `UPM IPC` 阻断。

### Error
```text
CreateDirectory 'C:/Users/CodexSandboxOnline/AppData/LocalLow/Unity' failed: 拒绝访问。
[Package Manager] Could not connect to IPC stream "Upm-13940" after 30.0 seconds.
[Package Manager] Could not establish a connection with the Unity Package Manager local server process.
Exiting without the bug reporter. Application will terminate with return code 1
```

### Context
- Command/operation attempted: Unity batch executeMethod for `DressUpSceneValidator.RunBatchValidation`
- Environment: `C:\Gamedev\Unity\Project\FantasyWord`, logs `RecoveryNotes/dress-up-scene-validator-20260313-2.log` and `RecoveryNotes/dress-up-scene-validator-20260313-3.log`

### Suggested Fix
不要把这类失败当成场景运行时失败；先用 Unity Roslyn 复编确认新增 Editor 脚本可编译，再把运行时验证转移到真实 Unity Editor 会话或非沙箱环境执行。若继续尝试 batchmode，先假设阻塞点仍是环境而不是场景逻辑。

### Metadata
- Reproducible: yes
- Related Files: Assets/Scripts/_Editor/Playtest/DressUpSceneValidator.cs, RecoveryNotes/dress-up-scene-validator-20260313-2.log, RecoveryNotes/dress-up-scene-validator-20260313-3.log
- See Also: ERR-20260312-008

---
