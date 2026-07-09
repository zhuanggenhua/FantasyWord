# 历史归档入口

## 归档目的

这里保存旧 `FantasyWorld` 恢复任务和 MiniFantasy UV 迁移证据。它们不再承载 `FantasyWord` 当前新游戏目标，只作为必要时追溯事实的参考。

## 目录说明

- `legacy-recovery/`：旧恢复任务计划、进度、发现记录、RecoveryNotes、MigrationStaging。
- `mini-fantasy-uv-evidence/`：MiniFantasy UV 迁移证据、GUID 映射和历史构建日志。它们不是框架本体，也不是应删除的垃圾文件。
- `legacy-rpg-assets/`：保留“曾被错误归档”的历史说明；相关业务资产现已恢复到 `Assets/Database` 与 `Assets/Prefabs`。
- `minifantasy-demo-assets/`：保留“曾被错误归档”的历史说明；相关第三方 demo 场景和示例脚本现已恢复到原 `Assets/Art` 目录结构。
- 旧 UnityMCP 安装器和旧 MiniFantasy UV smoke 工具已经删除，不再保留为当前项目归档。

## 使用边界

- 看到旧文档里的 `Next:`、`Phase`、`in_progress`、`待继续`，不得自动当成当前任务。
- 只有需要核实旧资源来源、旧损坏事实、旧插件占用或旧验证证据时，才读取本目录。
- 新游戏当前目标以根目录 `AGENTS.md` 和 `docs/ai/` 为准。
