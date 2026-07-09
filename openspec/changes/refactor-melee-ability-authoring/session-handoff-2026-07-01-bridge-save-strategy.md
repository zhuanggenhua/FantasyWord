# Session Handoff: 2026-07-01 Bridge Save Strategy

## 本轮锁定事实

### 1. `Editor Auto Save` 当前已启用，且不是“必须聚焦 Unity 窗口才会保存”

代码证据：

- `Assets/Editor/IntenseNation/Editor Auto Save/Editor/EditorAutoSave.cs`
  - 通过 `[InitializeOnLoadMethod] Initialize()` 启动
  - 用 `EditorCoroutineUtility.StartCoroutineOwnerless(AutoSaveWait())` 挂后台计时协程
  - `AutoSaveWait()` 每秒 `WaitForSecondsRealtime(1)` 轮询
  - 到时后直接调用 `Save()`
  - `Save()` 不检查窗口是否聚焦，只检查 `EditorApplication.isPlaying`

当前 EditorPrefs 取证：

- `Autosave = true`
- `SaveScenes = true`
- `SaveProject = true`
- `SaveTime = 10`
- `CountDown = true`
- `CountDownTime = 3`
- `SavePrompt = false`
- `SaveNotification = false`

结论：

- 按当前代码和当前编辑器配置，自动保存已经处于开启状态。
- 从插件实现看，它不依赖 Unity 窗口前台聚焦。
- 因此“Bridge 操作时 Unity 没聚焦就完全不会自动保存”这一点当前可以视为已排除。

注意：

- 这只说明自动保存插件本身已启用，且没有聚焦门槛。
- 它不等于 Bridge 的正式场景持久化策略已经合理。

## 2. 当前已经补上的 Bridge 行为

当前 `.codex/skills/aibridge/bridge.py` 已新增一条窄策略：

- 当 Bridge 执行 `scene-open`
- 且 `loadSceneMode` 是 `Single`（或默认单场景打开）
- 如果当前已打开正式场景是 dirty
- 则先显式保存这些已打开正式场景
- 再继续切场景

这条策略的目标很单一：

- 避免 Unity 在切正式场景时弹“是否保存场景”对话框
- 避免自动化被该弹窗卡死

这不等于：

- 允许所有写命令都自动保存正式场景
- 用自动保存代替正式场景边界判断

## 3. 当前仍未完全解决的问题

还没解决的是：

- Bridge 在“正式场景已被写入但尚未显式落盘”时，
- 后续如果又执行 `scene-open` / reload 类流程，
- 仍可能把只存在内存里的正式场景改动冲掉。

已锁定证据：

- `Temp/UnityBridge/logs/command-audit.jsonl`
- 其中出现过对 `Assets/Scenes/ClickMoveTest.unity` 的多次 `scene-open`
- 当时策略是 `bridgeFormalSceneRecoveryMode = "reload-if-disk-clean"`
- 审计里看到的是正式场景 `isDirty:false`

这说明：

- 以前的问题不只是“没自动保存”
- 而是 Bridge 缺少“正式场景写后，后续 reload / reopen 前必须显式保存或拒绝继续”的硬门禁

## 4. 新会话第一优先级

下一会话不要先回到技能实现，先看下面剩余缺口：

1. 继续审查 `.codex/skills/aibridge/bridge.py` 里除 `scene-open` 之外的正式场景重开路径
2. 给更广义的正式场景持久化门禁补齐剩余范围：
   - `reload`
   - 显式恢复路径
   - 其它可能重开正式场景的流程
3. 保持规则：
   - 不自动保存未知用户场景
   - 不把“全局自动保存插件”当成正式场景保护的唯一保障
   - 不再允许 `reload-if-disk-clean` 这类路径冲掉内存态正式改动

## 5. 本轮结束时的环境状态

- Unity Editor 在线
- `isPlaying = false`
- `isCompiling = false`
- 自动保存插件已启用
- `scene-open` 单场景切换前自动保存 dirty 正式场景的窄修正已落地
- 当前可把“是否需要聚焦才能自动保存”视为非阻塞项

## 6. 恢复近战/GAS主任务前提

只有在 Bridge 正式场景保存策略补稳后，才建议继续回到：

- `refactor-melee-ability-authoring`
- 近战作者流
- GAS 侧技能正式实现

否则后续 Unity 自动化仍有再次把正式场景状态搞乱的风险。
