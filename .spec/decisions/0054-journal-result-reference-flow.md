# 0054-任务日志结果链必需任务资产参考流程边界

- 日期：2026-07-16
- 状态：已采纳
- 背景：
  - 2DRPGEngine 同职责任务日志流程中，`StartQuest`、`CompleteQuest` 和 `UnlockQuest` 直接使用传入的正式任务资产推进任务状态、通知事件并执行完成命令。
  - FantasyWord 在任务日志上增加了 `GameCommandContext`、可等待完成命令、稳定数据库引用和显式监听释放，这些是当前项目必要适配，但不改变任务结果链对任务资产的要求。
  - 上一版 `JournalSystem.StartQuest` 和 `CompleteQuest` 对缺任务资产只 `Debug.LogError` 后返回。特别是 `ItemStartQuestEffect` 会在 `m_questToStart` 缺失时把使用结果返回为成功，但任务实际没有开始，属于正式结果被吞掉。
- 决策：
  - `JournalSystem.StartQuest`、`CompleteQuest` 和 `UnlockQuest` 必须要求有效任务资产；缺任务资产时抛出可定位异常。
  - 任务交互里“没有可接/可完成任务”仍然是正常查询失败，可以返回 false；这和“已经决定开始/完成/解锁某个任务，但任务资产缺失”不是同一类流程。
  - `CompleteTask` 暂不改动：参考工程同职责命令也是把子任务资产传入每个 active quest progress，若没有匹配任务就无推进结果；本轮不把它升级成必需目标，后续只有发现当前项目有明确配置成功语义时再复核。
  - 该结论不是因为空检查本身违规，而是因为同职责任务结果流程和当前物品效果成功语义都要求“任务资产缺失不能被当成成功执行”。
- 影响：
  - 任务资产漏配会更早暴露，不再出现物品使用成功但任务没有开始、任务完成入口成功返回但没有完成任务的状态。
  - `scripts/Invoke-QuestRuntimeStaticGate.ps1` 增加具体合同检查：`StartQuest`、`CompleteQuest` 和 `UnlockQuest` 必须通过有效任务资产校验，不得回退到 log 后 return。
- 替代关系：
  - 延续 0050 的参考流程优先原则。
  - 补充 0006：0006 解决任务进度监听生命周期和存档引用，本决策解决任务日志结果入口不能吞掉缺任务资产。
