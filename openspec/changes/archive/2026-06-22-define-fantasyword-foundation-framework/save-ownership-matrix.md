# 存档真相专项矩阵

> 本文件处理 `SaveSystem/PersistenceSystem` 与 Yoki `SaveKit` 的职责边界。
> 当前不新增第二套存档模型，也不重写具体存档 UI。

## 当前结论

| 项 | 结论 |
| --- | --- |
| 世界语义真相 | `GameCore SaveDataBlock` |
| 对象持久化真相 | `PersistenceSystem + Persistable + PersistableReference` |
| 地图真相 | `MapSystem/MapDataBlock` |
| 文件层工具 | Yoki `SaveKit` |
| 当前动作 | 保持正式融合：GameCore 组装语义，SaveKit 负责文件、槽位、版本和元数据；`2026-06-18` 已把 `CharacterBase` 上由持续效果派生出来的 `legacyLockedActions/legacySpeedModifiers` 从独立写盘中撤回；`2026-06-21` 又进一步删除了 `legacyTemporalEffects` 兼容层，读档时动作锁与速度修饰现在只允许由 `temporalEffectRuntimeStates` 这条正式持续效果恢复链重建 |

## 取舍

| 维度 | `GameCore SaveSystem/PersistenceSystem` | Yoki `SaveKit` | 当前判断 |
| --- | --- | --- | --- |
| 设计模式 | 知道世界、角色、地图、背包、任务和持久化对象语义 | 不应知道 FantasyWord 世界语义 | GameCore 是存档语义所有者 |
| 软件工程 | 便于按领域数据块迁移和诊断 | 文件格式、槽位、版本、迁移器和异步能力更完整 | SaveKit 只做文件层工具 |
| 易用 | 内容系统能按数据块扩展 | 开发工具和调试存档文件更方便 | 正式融合，不建第二存档系统 |

## 职责拆分

| 职责 | 所有者 | 说明 |
| --- | --- | --- |
| 存档文件路径、文件名、扩展名 | SaveKit，由 `SaveSystem.ConfigureSaveKit` 配置 | 项目侧只能通过 `SaveSystem` 设置 FantasyWord 专用格式 |
| 存档槽位 | SaveKit 文件层，GameCore 提供旧存档名到槽位的稳定映射 | `SAVEFILE_A/B/C` 继续映射到固定槽位 |
| 存档头部元数据 | SaveKit | 只描述文件层元数据，不承载世界规则 |
| 世界聚合数据 | `SaveDataBlock` | 包含地图、角色、背包、任务、持久化对象等领域数据块 |
| 运行时对象恢复 | `PersistenceSystem` | SaveKit 不实例化世界对象 |
| 地图/检查点恢复 | `MapSystem` | SaveKit 不决定玩家出生点或地图流 |
| 持续效果派生句柄 | 持续效果恢复流程 | 例如动作锁、速度修饰这类派生状态不能再单独写成第二份角色存档真相 |
| 版本迁移 | 文件层迁移可由 SaveKit，语义迁移必须回到 GameCore 数据块 | 不能让 SaveKit 直接改领域规则 |

## 禁止项

| 禁止项 | 理由 |
| --- | --- |
| 直接从业务系统调用 `SaveKit.Save/Load` 写领域数据 | 会绕过 `SaveSystem` 聚合语义 |
| 在 SaveKit 模块里拆散背包、任务、角色等世界数据块 | 会让 SaveKit 变成第二世界存档真相 |
| 让 UI 菜单直接管理 SaveKit 槽位和数据块 | UI 只能发起请求，不拥有存档规则 |
| 为卡牌模式单独建第二套文件存档 | 卡牌长期数据应进入玩家档案或卡牌收藏数据块 |
| 为 Mod 先建空存档扩展系统 | 当前只要求稳定 ID 和可迁移边界，不做空框架 |

## 后续动作

| 顺序 | 动作 |
| --- | --- |
| 1 | 保持当前融合：`SaveSystem` 是唯一存档入口，SaveKit 不被业务代码直接调用 |
| 2 | 补真实场景存档 smoke：保存、加载、地图、角色、背包、任务、持久化对象最小链路 |
| 3 | 后续新增领域数据时，先定义 GameCore 数据块，再由 `SaveSystem` 聚合 |
| 4 | 如果启用 SaveKit 迁移器，必须区分文件格式迁移和领域语义迁移 |

## 当前验收证据

| 证据 | 含义 |
| --- | --- |
| `SaveSystem.cs` 注释和实现 | 明确 SaveKit 只作为文件槽位、版本和元数据承载层 |
| `Invoke-FoundationStaticGate.ps1` | 保护 `SaveSystem/PersistenceSystem/MapSystem` 正式闭包存在 |
| `truth-ownership-implementation-matrix.md` | 明确 SaveKit 不能拥有世界语义 |
