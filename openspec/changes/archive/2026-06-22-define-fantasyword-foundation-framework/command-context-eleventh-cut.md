# Command Context Eleventh Cut

## Scope

本次第十一刀把剩余 `ICommand` 运行时命令类全部收进 `IContextualCommand` 协议。目标是让命令系统本身只有一条正式执行口：旧无参 `Execute()` 继续兼容资产和历史调用，但内部统一转到带 `GameCommandContext` 的入口。

## Implemented Shape

- `Assets/Scripts/GameCore/Runtime/Commands` 下现有命令类已全部实现 `IContextualCommand`。
- 旧无参 `Execute()` 统一委托到 `Execute(GameCommandContext.Script())`，表达“没有显式 actor 的旧调用是脚本/生命周期来源”，而不是假装成本地玩家。
- 仍保持业务语义不变的命令：
  - 金钱、任务、游戏标记、检查点、菜单、商店、制作、音频、对话、等待、相机和重生命令继续执行原有系统动作。
  - 这些命令现在可以被组合命令、交互命令或触发器带着同一份上下文调用。
- 补了两个旧薄壳的空引用安全边界：
  - `DestroyEntity` 缺目标时安全跳过。
  - `MoveCamera` 缺相机移动策略时安全完成。
  - `PlayDialogueSequence` 缺对话资产时安全完成。

## Current Evidence

- `rg -n "class .*: ICommand|class .*: IContextualCommand" Assets/Scripts/GameCore/Runtime/Commands -g "*.cs"` 当前显示所有命令实现类都是 `IContextualCommand`。
- `rg -n "\.Execute\(\)" Assets/Scripts/GameCore/Runtime/... -g "*.cs"` 当前只剩 `ICommand.cs` 扩展方法内部的兼容回退调用。

## Preserved Compatibility

- 没有修改 `[SerializeReference]` 字段形状，不要求命令资产重建。
- 没有删除 `ICommand.Execute()`，旧资产和旧序列化类型仍能通过接口加载。
- 没有新增网络框架、RPC、NetworkObject、网络目录或网络抽象。
- 没有把本地玩家、AI、远程访客控制权提前写死；控制权验证仍是后续正式命令入口的职责。

## Remaining Required Cuts

1. 把 `InputSystem -> IPlayerInputTarget -> PlayerController` 的直接调用，逐步收口成正式玩家命令入口。
2. 为移动、拾取、交互、装备、转移、使用物品和施法定义统一请求/结果形状。
3. 让 AI 和未来远程访客也能走同一条命令入口，而不是复制玩家输入路径。
4. 在真实模型存在后，补控制权、距离、容量、重量、锁、阵营、偷窃和状态限制。
