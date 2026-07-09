# AIBridge 常用命令

## 适用范围

- 记录 `FantasyWord` 当前仍有效的 Unity Editor 自动化命令。
- 只记录当前真实存在的正式入口，不记录已删除或已归档的旧入口。

## Editor 基线

- 当前项目只连接一个正常 Unity Editor。
- 当前正式自动化包：`com.aibridge.unity`
- 当前技能线自动化前提：
  - AIBridge 心跳正常
  - `assets-refresh` 可用
  - Console 可读
  - 如需追溯最近是哪条 Bridge 命令留下了正式场景 dirty，先看 `Temp/UnityBridge/logs/command-audit.jsonl`
  - 审计文件现在除了命令号，还会带 `resultSummary`，可以直接看到最近一次 `scene-list-opened` / `editor-application-get-state` 的返回摘要

## 命令原则

- 默认先做 `editor-application-get-state`、`assets-refresh`、`console-get-logs`。
- `tests-run` 不是每个需求的默认步骤。
- 不为了自动化新增长期菜单。
- 不把开发审计入口写成策划作者流。
- 只要 `scene-list-opened` 证明当前打开的是正式场景且 `isDirty:true`，自动化立刻降级成只读取证；不要继续切 PlayMode、切场景、改对象或发可能继续改写场景的 `script-execute`。
- 唯一例外：`scene-open` 且目标是 `Single` 切场景时，`bridge.py` 现在会先显式保存当前已打开的 dirty 正式场景，再继续切场景，用来避免 Unity 的保存弹窗把自动化卡住。
- 另一个明确例外：如果当前命令已经显式持有 `scene lock`，并且 dirty 的正是这条自动化流程正在修改的正式场景，`bridge.py` 现在会先自动保存当前正式场景，再继续执行后续受保护命令；不要再把这种情况抛回给用户做人肉确认。
- `bridge.py` 现在会在发出写操作型 Unity 命令前，先用只读的 `scene-list-opened` 做一层正式场景 dirty 拦截；发现正式场景已脏时，直接拒绝后续写命令，不再先靠内部 `script-execute` 探针才发现问题。
- 即使某条多步流程显式传了 `bridgeSceneDirtyPolicy:"ignore"`，它也不能跨过普通脏场景继续写；`ignore` 只允许临时保留“已知生成/恢复残留”的收尾窗口，不是绕过正式场景 dirty 保护的后门。

## 恢复场景弹窗

- Unity 出现 `Recovering Scene Backups` 或类似“恢复未保存场景”弹窗时，默认先点击恢复场景，保留现场继续验证。
- 若本轮的问题对象和目标场景已经锁定，例如当前任务明确就是 `Assets/Scenes/EquipmentSystemDemo.unity`，恢复弹窗命中的也是该场景或同一条当前验证链的临时备份，则直接点击恢复并继续排查；不得把“是否恢复”再当成阻塞点抛回给用户。
- 若用户已经手动点击恢复，后续自动化应以恢复后的当前场景状态继续取证，不再重复要求用户确认同一个恢复动作。
- 不要把删除 `Temp/__Backupscenes` 当默认恢复动作；AIBridge 暂时连不上不等于可以直接清理恢复备份。
- 只有恢复按钮不可用、用户明确同意清理，或确认只是自动化生成且无保留价值的临时恢复残留时，才允许清理项目 `Temp/__Backupscenes`。
- 这条规则只覆盖项目 `Temp/__Backupscenes`；不得自动处理正式场景、用户手工备份目录或未知恢复目录。

## 正式场景保护

- 正式场景 smoke 固定顺序：
  - `scene-lock-acquire`
  - 受保护命令，显式带 `bridgeSceneLockToken`
  - 如果进过 PlayMode，显式退出 PlayMode
  - `scene-list-opened` 复查正式场景是否仍为 `dirty`
  - `scene-lock-release`
- 只要最后复查时正式场景还是 `dirty`，就视为本次自动化未收尾；停止继续写操作，先报告。

## 当前常用命令

```powershell
python .codex/skills/aibridge/bridge.py editor-application-get-state
python .codex/skills/aibridge/bridge.py assets-refresh "{\"options\":\"ForceSynchronousImport\"}"
python .codex/skills/aibridge/bridge.py console-get-logs "{\"maxEntries\":80,\"includeStackTrace\":true}"
python .codex/skills/aibridge/bridge.py scene-list-opened
```

## 当前技能线正式自动化入口

### 1. 技能职责审计

- 正式入口：`Assets/Editor/GameCore/Utils/FormalAbilityAssetValidation.cs` 的 `InspectAllAbilitySheets()`
- 能力边界：
  - 对已迁移 EX-GAS 技能，只检查旧 `AbilitySheet` / 旧执行资产字段是否退回兼容残留
  - 检查 EX-GAS 运行配置、Prefab、Timeline、GameplayEffect 和 Cue 是否形成正式链路
  - 对未迁移旧技能，才继续检查 `AbilitySheet.executionAsset` 引用闭包和执行资产类型
  - 不自动创建、不自动同步、不自动修资产

#### 最小调用示例

```powershell
python .codex/skills/aibridge/bridge.py script-execute "{\"csharpCode\":\"public class Script { public static object Main() { return FantasyWord.GameCore.FormalAbilityAssetValidation.InspectAllAbilitySheets(); } }\",\"bridgeSceneDirtyPolicy\":\"discard-generated\"}"
```

#### 结果解读

- `Success = true`
  - 对已迁移技能，不代表 `AbilitySheet -> AbilityExecutionAsset` 是正式链路；正式链路必须回到 EX-GAS Ability / Timeline / GameplayEffect / Cue
  - 不代表正式命中框作者面、复杂法术作者面或技能系统整体已经完成
- `Success = false`
  - 优先修引用缺口或类型不匹配
  - 不要再回到旧 `FormalGas*` 审计或旧模板脚手架思路

## 视觉取证红线

- 当用户要 Unity 内部画面、场景图、运行结果图时，优先走 Unity 内部出图链路。
- 系统桌面截图不能冒充 Unity 场景预览。
- 当前如果只是检查能力资产、规则资产和审计结果，不升级成截图任务。

## 当前明确已失效的旧命令口径

以下内容已不再是当前正式入口：

- 任何旧 `FormalGas*` 审计或模板脚手架命令

如果文档、脚本或口头流程还在引用这些名字，应视为旧真相残留，不继续沿用。
