# 第四十五刀：变形感染规则可来源化切到已配置 AI 控制

## 背景

第四十四刀后，主动能力释放已经能区分本地玩家和 AI 来源，但变形、感染、丧尸化这类规则还有一个控制权缺口：

- 玩家角色失控后，第二十七刀只能让它不再接受玩家直接输入。
- 如果同一个角色已经配置了 `AIController`，规则应能临时把当前控制器切到 AI，让角色按现有 AI 行为继续移动、选敌和施法。
- 如果角色没有配置 `AIController`，规则不能伪造第二套 AI，也不能把“不可玩家控制”误判成“AI 正在控制”。
- Kenshi、博德之门和 ToME4 风格的复杂效果会经常出现“保留部分能力、替换部分能力、临时夺走控制权”的状态；控制器切换必须跟能力来源、叠层和读档恢复同源，而不是靠当前场景对象临时猜。

本刀解决“规则生效期间把角色切到已配置 AIController，并在规则撤回后回到主控制器”的闭包。

## 本刀变更

- `Movable` 从单控制器宿主扩展为主控制器加额外控制器宿主：
  - `m_controller` 继续作为默认主控制器，保留旧 prefab/存档语义。
  - `m_additionalControllers` 允许同一个角色额外配置 `AIController` 等控制器。
  - `m_activeControllerOverride` 只表达临时激活覆盖，不改写主控制器。
  - 生命周期、`Update`、`FixedUpdate` 和 Gizmos 都走当前激活控制器。
- `MovableDataBlock` 新增 `controllerRuntimeStates` 保存全部控制器运行态，同时保留旧 `controllerData` 给旧单控制器存档回退。
- `Movable.TryGetController<T>()` 会查主控制器和额外控制器；新增 `IsControllerActive<T>()`、`TryActivateController<T>()` 和 `ClearControllerOverride<T>()`。
- `GameCommandContext.ResolveForActor(...)` 改为只在当前激活控制器是 `AIController` 时返回 `AI(actor)`，不再因为角色“配置了 AIController”就误判为 AI 来源。
- `CharacterAlterationRule` 新增 `forceAIControl`：
  - 生效时同时锁玩家直接控制。
  - 生效时调用 `ApplyAlterationAIControlRule(source)`。
  - 撤回或单层撤回时按同一来源回滚。
- `CharacterBase.StateApi` 按 `CharacterAbilitySourceKey` 维护 AI 控制覆盖计数：
  - 有任意有效来源时尝试 `TryActivateController<AIController>()`。
  - 所有来源撤回后 `ClearControllerOverride<AIController>()` 回到主控制器。
  - 读档恢复和清理激活规则时同步重建或清空 AI 控制覆盖。
- `Invoke-FoundationStaticGate.ps1` 新增 Movable 多控制器宿主、变形 AI 控制规则和 `GameCommandContext` 激活控制器语义门禁。

## 控制语义

- `forceAIControl = true` 的规则生效后：角色不能再作为玩家当前控制对象，并尝试激活该角色已配置的 `AIController`。
- 同一来源多层叠加时：每层都计数，单层撤回只移除一层；归零后才撤回该来源的 AI 控制覆盖。
- 多个来源同时要求 AI 控制时：任意有效来源都保持 AI 控制；最后一个来源撤回后回到主控制器。
- 没有 `AIController` 的角色：规则仍会锁玩家直接控制，但不会生成 AI、不会伪造 `AI(actor)` 命令来源。
- 配置了 `AIController` 但当前未激活的角色：`ResolveForActor(...)` 不会把它识别为 AI，避免未来玩家/脚本命令被错误归类。
- 读旧存档时：旧 `controllerData` 仍能加载主控制器；新存档会分别保存主控制器和额外控制器状态。

## 边界

- 不实现新的 AI 行为树、AI 命令队列、RTS 阵型、控制组、多选或队伍命令。
- 不接入 FishNet、NetworkObject、RPC、网络 ownership 或远程访客控制入口。
- 不改变 GAS 规则层、能力执行、伤害结算、装备视觉隐藏、尸体实体、派系长期仇恨或 AI 日程。
- 不把 `forceAIControl` 等同于“角色属于 AI 阵营”；阵营仍由第二十六刀的来源化阵营覆盖回答。
- 不替代后续 prefab 接线工作：需要 AI 接管的具体角色 prefab 仍必须在 Inspector 中显式配置额外 `AIController`。
