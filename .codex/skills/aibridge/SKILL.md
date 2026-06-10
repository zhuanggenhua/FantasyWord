---
name: aibridge
description: 通过 Unity AI Bridge 的文件 IPC 自动化 Unity Editor：场景、GameObject、组件、资源、Prefab、脚本执行、Console、Profiler、测试和播放状态。需要与 Unity Editor 交互时使用。
---

# AI Bridge Unity Skill

## 概述

本项目只使用 Unity AI Bridge 作为本地 Unity Editor 自动化入口，不再使用 uloop / Unity CLI Loop。当前 Bridge 来自用户 fork：

`https://github.com/aiseog3121/unity-ai-bridge`

Unity 包通过 UPM 接入 `com.aibridge.unity`，CLI 侧使用本目录的 `bridge.py`，通过 `{ProjectRoot}/Temp/UnityBridge/` 文件 IPC 与当前唯一正常 Unity Editor 通信。

## 前置条件

- Unity Editor 已打开当前项目，并完成包解析 / domain reload。
- `Temp/UnityBridge/heartbeat` 存在且时间戳新鲜。
- Python 可用；Windows 下优先用 `python`，其它平台可用 `python3`。
- 调用工具前必须先读 `params/{tool}.json`，不要凭记忆猜参数。

## 调用方式

从 Unity 项目根目录执行：

```bash
python .codex/skills/aibridge/bridge.py <tool-name> '<json-params>'
```

无参数工具可以省略 JSON：

```bash
python .codex/skills/aibridge/bridge.py editor-application-get-state
python .codex/skills/aibridge/bridge.py console-get-logs '{"maxEntries":20}'
```

关键规则：

- JSON 参数名必须使用 camelCase；PascalCase 参数会被忽略。
- Bridge 包装层额外支持 `bridgeSceneLockToken`、`bridgeSceneLockMode`、`bridgeSceneLockTimeoutSeconds`、`bridgeSceneLockReason`、`bridgeSceneDirtyPolicy` 这几个 camelCase 控制参数；它们不会透传到 Unity 工具参数本体。
- 同一 Editor 会话里 Bridge 调用串行执行。
- `bridge.py` 内建项目级 CLI 锁：同一项目下并发发起多条 Bridge 命令时，后发命令会等待前一条完成；不要把并发 shell 当作正式提高吞吐的手段。
- `bridge.py` 另外内建项目级 scene lock：多步场景端到端流程应先 `scene-lock-acquire`，后续场景受保护命令带上 `bridgeSceneLockToken`；其它 AI 要么等待锁释放，要么显式用 `bridgeSceneLockMode:"fail"` 放弃本次端到端。
- `tests-run` 成功返回前，`bridge.py` 会继续等待 Editor heartbeat 连续推进多个周期后才释放 CLI 锁；不要把“上一条测试命令刚回包”误读成“下一条测试命令可以零间隔立刻贴上去”。
- AIBridge 包内的 `tests-run` 在真正调用 `TestRunnerApi.Execute(...)` 前，也会先等待 Unity Test Runner 当前活跃 run 退场；CLI 锁和包内活跃态检查是两层约束。
- `bridge.py` 现已内建场景 dirty 守卫：受影响命令发到 Unity 前会先检查并按策略清理已知生成场景 dirty，命令返回后还会再次收尾；若命令在发出后超时或异常退出，也会按已声明的 `bridgeSceneDirtyPolicy` 对已知生成场景做一次 best-effort 失败补收尾。`tests-run` + `PlayMode` 默认自动丢弃已知生成场景残留，其它可能改场景状态或触发场景切换的命令不再允许默认静默 `ignore`，必须显式传 `bridgeSceneDirtyPolicy`。
- 涉及脚本新增、删除、修改或 `AssetDatabase.Refresh()` 后，先等待 Unity 编译完成，再继续调用 Bridge。
- 不通过 Bridge 默认新增 Unity 顶部菜单；AI 自动化入口优先复用静态方法、测试、验证器和项目已有正式入口。
- 默认不要为了执行 Bridge 命令而把 Unity Editor 抢到前台、主动聚焦窗口或改变用户当前输入焦点；只有当任务目标本身就是窗口可视取证、Inspector 截图或用户明确要求查看当前 Unity 画面时，才允许把聚焦前台视作流程的一部分。
- 工具选型默认顺序固定为：`tests-run` -> `script-execute` 调项目已有静态方法/验证器 -> `script-update-or-create`。除非任务目标本身就是沉淀或修改长期正式入口，否则不要把一次性探针、取证、排查或临时自动化实现成反复创建/覆盖 Editor 脚本文件。

## 常用工具

- Editor：`editor-application-get-state`、`editor-application-set-state`、`editor-selection-get`、`editor-selection-set`
- Scene：`scene-list-opened`、`scene-get-data`、`scene-open`、`scene-save`
- Bridge Lock：`scene-lock-status`、`scene-lock-acquire`、`scene-lock-release`
- GameObject：`gameobject-find`、`gameobject-create`、`gameobject-modify`、`gameobject-component-get`、`gameobject-component-modify`
- Assets / Prefab：`assets-find`、`assets-get-data`、`assets-refresh`、`assets-prefab-instantiate`
- Script：`script-execute`、`script-read`、`script-update-or-create`
- Console：`console-get-logs`
- Tests：`tests-run`
- Reflection：`reflection-method-find`、`reflection-method-call`

## 项目默认流程

### 查 Editor 状态

```bash
python .codex/skills/aibridge/bridge.py editor-application-get-state
```

### 执行一次性 C# 探针

先读 `params/script-execute.json`，然后传入包含类和静态方法的 C#：

```bash
python .codex/skills/aibridge/bridge.py script-execute '{"csharpCode":"public class Script { public static object Main() { return UnityEngine.Application.unityVersion; } }","bridgeSceneDirtyPolicy":"discard-generated"}'
```

适用边界：

- 临时查询 Editor 状态、读取资产/场景信息、一次性调用现有构建器/验证器/取证入口时，默认用 `script-execute`。
- 只有在本轮任务明确要求“新增或修改长期保留的正式 C# 文件入口”时，才使用 `script-update-or-create`；不要把它当成默认探针工具。
- 当前问题若只需要代码合同、编译状态、EditMode 或定向 PlayMode 证据，不要顺手升级成窗口取证、截图或完整场景端到端；Bridge 应停在最低充分验证层。

### 运行测试

先读 `params/tests-run.json`，再按范围运行：

```bash
python .codex/skills/aibridge/bridge.py tests-run '{"testMode":"EditMode","includePassingTests":false,"includeMessages":true,"includeStacktrace":true}'
python .codex/skills/aibridge/bridge.py tests-run '{"testMode":"PlayMode","testMethod":"FantasyWord.Tests.PlayMode.SomeTests.SomeCase","includeMessages":true,"includeStacktrace":true}'
```

补充：

- `tests-run` 可能先返回 `Processing` 与 `requestID`；CLI 会继续等待 `Temp/UnityBridge/results/<requestID>.json` 的真正结果。
- 做精确测试回归时，默认显式传 `requestId`，便于跟踪延迟结果文件与日志。

### 场景端到端互斥

需要跨多条命令占住场景端到端窗口时，先获取 scene lock：

```bash
python .codex/skills/aibridge/bridge.py scene-lock-acquire '{"owner":"codex-world-e2e","reason":"World smoke PlayMode + 场景取证","mode":"wait","timeoutSeconds":600}'
```

后续场景受保护命令带上返回的 `token`：

```bash
python .codex/skills/aibridge/bridge.py script-execute '{"csharpCode":"public class Script { public static object Main() { return UnityEngine.Application.unityVersion; } }","bridgeSceneLockToken":"<token>","bridgeSceneDirtyPolicy":"discard-generated"}'
python .codex/skills/aibridge/bridge.py tests-run '{"testMode":"PlayMode","testClass":"WorldSmokePlayModeTests","includeMessages":true,"includeStacktrace":true,"bridgeSceneLockToken":"<token>"}'
```

完成后释放：

```bash
python .codex/skills/aibridge/bridge.py scene-lock-release '{"token":"<token>"}'
```

补充：

- `tests-run` 的 `PlayMode`、`scene-open/save/create/unload/set-active`、本项目默认的 `script-execute` / `script-update-or-create`、以及场景对象改动类命令都属于场景受保护命令。
- 如果只是尝试发起一次 PlayMode / 场景命令，不想等待别人当前的端到端流程，可直接传 `bridgeSceneLockMode:"fail"`；bridge.py 会在真正触发 Unity 前立即失败，调用方据此放弃本次端到端。
- `EditMode` 的 `tests-run`、`editor-application-get-state`、`console-get-logs`、`scene-list-opened` 这类只读命令不需要 scene lock。

### 场景 dirty 收尾

任何可能打开、构建、保存、运行或修改场景的 Bridge 调用结束后，都必须确认场景栈状态，不允许把 Unity 的保存确认弹窗留给用户处理。常见触发包括 `scene-open`、`scene-save`、`script-execute` 调用场景构建器、`tests-run`、PlayMode 切换、GameObject/Component 修改和截图取证前的临时注入。

```bash
python .codex/skills/aibridge/bridge.py scene-list-opened
```

处理规则：

- `bridge.py` 当前默认只对 `tests-run` + `PlayMode` 自动执行 `discard-generated`；这是为了清掉运行态残留，避免把测试脏状态留给用户。
- `bridge.py` 在执行受影响命令前会先检查当前打开场景栈；若已有生成场景 dirty，会先按策略保存或丢弃，避免后续 `scene-open` / `scene-create` / `scene-unload` 先弹 Unity 保存确认框。
- 受影响命令一旦已经发到 Unity，就算最终超时或异常退出，`bridge.py` 也会按已声明的 `bridgeSceneDirtyPolicy` 对已知生成场景做一次 best-effort 失败补收尾；这不是成功保证，但必须尽量避免把生成场景保存确认框直接留给用户。
- `script-execute`、`script-update-or-create`、`gameobject-*`、`assets-prefab-instantiate`、`editor-application-set-state`，以及 `scene-open` / `scene-create` / `scene-save` / `scene-unload`，都必须显式传 `bridgeSceneDirtyPolicy`；不再允许默认静默 `ignore`。
- 如果本次意图是持久化生成场景，请显式传 `bridgeSceneDirtyPolicy:"save-generated"`；如果只是临时验证/探针，请显式传 `bridgeSceneDirtyPolicy:"discard-generated"`；只有在你明确要跨多条命令暂存 dirty，并保证稍后同流程内显式保存/丢弃时，才允许传 `bridgeSceneDirtyPolicy:"ignore"`。
- `bridgeSceneDirtyPolicy:"ignore"` 只允许出现在已显式持有 `scene lock` 的多步场景流程里；必须先 `scene-lock-acquire`，后续命令带 `bridgeSceneLockToken`，并在同一流程内再用 `save-generated` 或 `discard-generated` 正式收尾。没有 lock token 的 `ignore` 视为未闭合流程，Bridge 会直接拒绝执行。
- `bridgeSceneDirtyPolicy` 只决定 Bridge 包装层如何处理“已知生成场景 dirty”；它不等于“这次调用已经完成收尾”。凡是本轮 Bridge 流程改动了正式 scene、生成 scene、Build Settings 或会影响场景栈序列化状态，结束前都必须再做一次显式结果确认：要么调用正式 builder / `GeneratedSceneAutomation.SaveOpenGeneratedScenes()` 完成保存，要么确认已通过磁盘重开或 `discard-generated` 丢弃残留；不得把“命令成功返回”误当成“场景一定已经干净”，更不得把保存确认弹窗留给用户。
- 如果本次意图是重建项目生成场景，调用当前项目明确登记的正式构建器，只保存已知生成场景，不保存未知用户场景。
- 如果本次只是验证、PlayMode、探针或截图留下的运行态残留，优先通过 `discard-generated` 或重新打开磁盘版本丢弃生成场景改动。
- 如果 dirty 场景不是项目已知生成场景或自动化临时场景，不得自动保存或丢弃；必须停止自动化并报告场景路径，等待用户决定。
- 当前项目尚未登记已知生成测试场景；登记前不得把任意场景自动保存或丢弃。
- 如果 Unity 弹出“是否保存场景”确认框，默认判定为上一条 Bridge 流程没有完成场景 dirty 收尾；必须立即补收尾或停止并报告。
- 不得通过反射 Unity 非公开 API 清理 dirty 标记；只能保存已知生成结果，或从磁盘重开以丢弃生成场景残留。
- 实际执行时，场景相关 Bridge 流程的收尾判定以“`scene-list-opened` / dirty 检查后不再残留未知脏场景，也不会再触发 Unity 保存确认框”为准，而不是以“调用方觉得这次应该没问题”为准。

### 查看 Console

```bash
python .codex/skills/aibridge/bridge.py console-get-logs '{"maxEntries":50,"includeStackTrace":true}'
```

## 故障处理

- `heartbeat not found`：Unity Editor 未打开、包未加载，或 Unity 还没完成 domain reload。
- `heartbeat stale`：Editor 可能在编译、导入资源或卡住；先等编译结束并观察 Console / Editor 状态。
- `tool not found`：确认 Unity 已解析 `com.aibridge.unity`，并检查工具名是否在本文件或 `params/` 中存在。
- `parameter error`：重新读取 `params/{tool}.json`，确认 camelCase 参数名、类型和必填项。
- `AIBridge 场景锁已被占用`：说明其它 AI 正在做场景端到端或持有 scene lock；决定是等待，还是把本次命令改成 `bridgeSceneLockMode:"fail"` 后直接放弃。
