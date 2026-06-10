# Learnings

## 2026-03-12 - 损坏文件应直接迁移，完好文件再择优
- Category: correction
- Context:
  - 我在 `Chest / Loot` 这一批上采用了“参考职责 + 当前工程裁剪适配”的实现方式
  - 用户指出这不是当前项目想要的恢复策略
  - 正确策略应为：损坏文件直接按同名参考迁移后再改；完好文件先对比旧工程和当前实现，再择优选用
  - 用户进一步明确：一般完好的旧工程代码通常更优
- Learning:
  - 遇到“旧工程脚本恢复”任务时，先判断文件状态，而不是先判断实现难度
  - 对损坏/缺失文件，默认做“参考同名文件直迁 + 薄适配”，不要先产出裁剪版
  - 对完好文件，默认把旧工程实现当作优先候选，而不是把当前临时恢复版当主实现
- Action:
  - 后续每批开始前先做“完好/损坏/缺失”三分判断
  - 若属于损坏/缺失，优先直接沿参考骨架重建
  - 若属于完好，先读旧工程版本并与当前版本对比后再决定是否替换

## 2026-03-12 - 剩余差集搜索必须覆盖 Editor 参考树
- Category: best_practice
- Context:
  - 在评估最后一批剩余脚本时，我最初只按 runtime 参考树判断是否存在同名参考
  - 结果把 `_Editor/DatabaseWindow/DatabaseWindow.cs` 和 `_Editor/Playtest/EditorPlayModeOverride.cs` 误判成“无同名参考”
  - 重新搜索 `Mythril2D/Core/Editor` 后，确认这两个文件都可以直接迁移并薄适配
- Learning:
  - 对旧工程脚本恢复任务，剩余差集里只要包含 `_Editor/*`，就必须把参考源里的 editor 目录也纳入同名搜索
  - 不能只扫 runtime 目录后就下“无参考”结论
- Action:
  - 后续做剩余差集评估时，先按 runtime/editor 分类，再分别搜索对应参考目录
  - 对 editor 参考脚本若依赖旧宿主 API，优先补当前宿主缺失入口，而不是直接放弃该批次

## 2026-03-11 - 恢复标准不能降级为“最小可编译”

- Category: correction
- Context:
  - 用户要求恢复并迁移 `FantasyWorld` 的核心自研系统
  - 在 Combat / Effect 基础层恢复时，我采用了“最小可编译实现”策略
  - 用户明确指出这不符合预期，最低也要达到 `2DRPGEngine/Mythril2D` 的框架水准
- Learning:
  - 对这类“系统恢复 / 框架迁移”任务，`能编译` 只能作为阶段验证标准，不能替代实现目标
  - 当旧项目源码损坏、需要参考框架重建时，默认目标应是“参考框架同层级能力的可用实现”，而不是“接口占位 + 主链可编译”
  - 尤其在 Combat / Ability / Projectile 这类核心系统中，必须优先恢复：
    - 数据层与运行时层的完整连接
    - 效果描述、应用、堆叠、目标过滤、宿主承载
    - AbilitySheet / ActiveAbilitySheet / Projectile / UIEffectList 等上下游接入点
- Action:
  - 将当前 Combat 基础实现标记为“过渡版，需要重做”
  - 后续按 `Mythril2D` 同职责模块做系统级对齐，而不是继续在占位层上叠补丁
