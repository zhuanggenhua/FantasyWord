# 地基模板使用指南

## 目标

- 这份指南只说明如何把当前 `FantasyWord` 的地基快速搬到下一个 Unity 项目。
- 它服务的是“少手工迁移、少重新缝合、优先整段复制”的目标，不负责解释具体玩法设计。

## 当前可用入口

- `scripts/Sync-2DRPGFoundation.ps1`
  - 从 `2DRPGEngine/Mythril2D/Core` 重新同步 `GameCore` 代码。
  - 同步时会把 `Assets/Database`、`Assets/Prefabs`、`Assets/Animations`、`Assets/Scenes`、`Assets/GameData` 中命中的旧脚本 GUID 回写到当前项目脚本 GUID。
  - 同步后会自动恢复当前登记过的参考补丁，并重写当前正式 `GameCore` asmdef；旧 `FoundationSupport` 已收敛完成，不再参与同步输出。
  - 可加 `-PruneExtraCopiedFiles`，按参考树清掉多余直拷 C# 和空目录壳。
- `scripts/Test-FoundationReferenceParity.ps1`
  - 检查当前 `Assets/Scripts/GameCore/Runtime` 与 `Assets/Editor/GameCore` 是否还等于参考变换后的结果。
  - 用它判断当前地基有没有又被手工改漂。
- `scripts/Export-FoundationTemplate.ps1`
  - 导出当前地基模板。
  - `core` 导出 AI 规范入口、项目本地 skill、`GameCore` 参考直拷层、当前 `Assets/Editor/GameCore/Tests` 里的 EditMode 测试、门禁、`docs/ai` 与 foundation OpenSpec。
  - `full` 额外导出当前数据库、Prefab、`SampleScene`、`EquipmentSystem` 候选模块与演示场景、输入配置、URP/ProjectSettings、Packages 清单、已迁入插件目录，以及 `ReferenceSources/TopDownEngine` 原始参考镜像。
- `scripts/Invoke-WorkspacePreflight.ps1`
  - 模板灌入后的静态工作区预检入口。
- `scripts/Invoke-PluginFacadeBoundaryGate.ps1`
  - 模板灌入后的插件边界门禁入口。
- `scripts/Invoke-EquipmentSystemStaticGate.ps1`
  - 模板灌入后的 `EquipmentSystem` 候选模块门禁入口。
- `scripts/Sync-TopDownRuntimeSubset.ps1`
  - 把仓库内 `ReferenceSources/TopDownEngine` 的第一批正式导入子集同步到 `Assets/Plugins/TopDownEngine`。
  - 当前会保留 `Common`、`Koala2D`、`MMTools`、`MMInterface`、`InventoryEngine`、`MMFeedbacks` 主闭包，并剔除 `Cinemachine` / `PostProcessing` 等当前未接入可选层。
- `scripts/Invoke-FoundationTemplateSmoke.ps1`
  - 一条命令完成“导出模板 -> 灌入 smoke 目录 -> 运行静态预检与门禁”。
  - `core` 跑 `WorkspacePreflight + FoundationStaticGate`，然后在目标目录里再跑 `Sync-2DRPGFoundation + Test-FoundationReferenceParity + FoundationStaticGate`。
  - `full` 额外跑 `PluginFacadeBoundaryGate + EquipmentSystemStaticGate`。
- `scripts/Bootstrap-FoundationTemplate.ps1`
  - 一条命令把模板灌进新的 Unity 项目目录。
  - 它会先导出模板缓存，再把 manifest 里的内容复制到目标项目。
- `scripts/Invoke-FoundationStaticGate.ps1`
  - 不开 Unity 的静态门禁。
- `scripts/Invoke-FoundationBridgeSmoke.ps1`
  - Unity Editor 已打开且 AIBridge 心跳存在时，做 `Editor 状态 -> Assets Refresh -> FantasyWord.GameCore.EditModeTests` 冒烟验证。
  - 这里只服务地基模板同步/灌入后的导入确认，不代表业务需求默认都要补或重跑同粒度测试。

## 推荐流程

### 1. 当前项目继续与参考对齐

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Sync-2DRPGFoundation.ps1 -PruneExtraCopiedFiles
powershell -ExecutionPolicy Bypass -File scripts\Test-FoundationReferenceParity.ps1
powershell -ExecutionPolicy Bypass -File scripts\Invoke-FoundationStaticGate.ps1
```

目标：

- `Sync` 负责把直拷代码拉回参考基线。
- `Sync` 之后不需要再手工把 `AudioClipResolver`、`BroAudio` 程序集引用补回去；这些状态已经收进脚本。
- `Sync` 之后如果 Unity 已开着，先做一次 `assets-refresh`，让脚本 GUID 回写真正导入进 Editor。
- `Parity` 负责确认没有手工漂移。
- `StaticGate` 负责确认当前正式地基、门禁和文档口径一致。

### 2. 导出模板

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Export-FoundationTemplate.ps1 -OutputRoot Temp\FoundationTemplateFull -Profile full
```

导出结果里会有：

- `foundation-template-manifest.json`
- 根 `AGENTS.md`、`.gitignore`、`.gitattributes`
- 当前本地 skill：`.agents/skills`、`.codex/skills`
- 当前 `docs/ai` 与 foundation OpenSpec
- 当前 `GameCore` 参考直拷层、`GameCore` 测试、门禁脚本
- 当前完整 `scripts/` 目录，包括模板导出/灌入、参考对齐、静态门禁、工作区预检、插件边界门禁和 `EquipmentSystem` 候选门禁
- 当前参考数据库 / Prefab / `SampleScene` / 输入配置 / URP 设置 / ProjectSettings / Packages 清单 / 插件目录（`full`）
- 当前 `EquipmentSystem` 候选代码、数据、运行时合同测试与演示场景（`full`）
- 当前 `ReferenceSources/TopDownEngine` 原始参考镜像，供后续按模块直接搬运或局部吸收（`full`）
- 当前已正式导入的 `Assets/Plugins/TopDownEngine` 子集（`full`）

### 3. 灌进新项目

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Bootstrap-FoundationTemplate.ps1 -TargetProjectRoot C:\Path\To\NewUnityProject -Profile full
```

目标项目会收到：

- 导出的模板文件
- `foundation-install-receipt.json`

注意：

- 这一步只复制模板内容，不替你处理目标项目已有业务资源冲突。
- 如果目标项目已有同路径文件，会被覆盖，所以应在新项目最早期使用。

### 3.5. 一键做模板 smoke

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Invoke-FoundationTemplateSmoke.ps1 -Profile full
```

结果：

- 自动导出模板到 `Temp/FoundationTemplateSmoke/Export/<profile>`
- 自动灌入 smoke 目录 `Temp/FoundationTemplateSmoke/Bootstrap/<profile>`
- 自动运行模板目录里的 `Invoke-WorkspacePreflight.ps1`
- 自动运行 `Invoke-FoundationStaticGate.ps1`
- `full` 还会自动运行 `Invoke-PluginFacadeBoundaryGate.ps1` 与 `Invoke-EquipmentSystemStaticGate.ps1`
- 自动在模板目标目录里再跑一次 `Sync-2DRPGFoundation.ps1 -PruneExtraCopiedFiles`
- 自动在模板目标目录里再跑一次 `Test-FoundationReferenceParity.ps1`
- 自动在模板目标目录里再跑一次 `Invoke-FoundationStaticGate.ps1`，确认“灌入后再 Sync 一次”也不掉当前地基状态

### 4. 在目标项目里做 Unity 验证

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Invoke-FoundationStaticGate.ps1
powershell -ExecutionPolicy Bypass -File scripts\Invoke-FoundationBridgeSmoke.ps1
```

前提：

- Unity Editor 已打开目标项目。
- `Temp/UnityBridge/heartbeat` 已存在。
- 如果刚跑过 `Sync-2DRPGFoundation.ps1`，不要跳过这一步；先让 `Invoke-FoundationBridgeSmoke.ps1` 里的 `assets-refresh` 把脚本 GUID 修复结果重新导入，再看 EditMode 测试。
- 上述 EditMode 冒烟只针对模板/地基同步后的导入风险；普通需求仍按项目总规范执行：先静态证据，再必要端到端 smoke，最后才是少量关键合同测试。

## 当前边界

- 这套模板优先覆盖的是 `2DRPGEngine` 参考地基和当前 `FantasyWord` 已接住的最小项目资产。
- 目录约定上，`Assets/Scripts/GameCore` 与 `Assets/Editor/GameCore` 尽量保持参考直拷主体。用户已允许改正式实现时，优先直接改正式代码或插件/工具本体，不再新造 `FoundationSupport` 这类过渡层。
- `core` 适合只搬可信地基；`full` 适合把当前可复用候选一并灌入新项目，再做项目侧裁剪。
- 它不自动替你做新的业务场景接线、玩法改造或新素材整理。
- 第三方插件本体、第三方素材和你自己的业务资源，仍然应按目标项目情况单独确认。
