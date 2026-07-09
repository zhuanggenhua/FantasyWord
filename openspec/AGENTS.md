# OpenSpec 工作规范

本目录是 `FantasyWord` Unity 版的正式规格入口。涉及 spec、proposal、change、架构边界、阶段拆分、验收标准时，优先读取本文件和对应 `openspec/changes/*`。

## 使用规则

- 当前项目没有继承旧 `FantasyWorld` 恢复任务用户故事，也不继承 `dark-corridor` 的横版动作 OpenSpec change。
- 新需求先进入 `openspec/changes/<change-id>/`，再按 proposal、design、tasks、spec delta 收敛。
- spec delta 必须写在 `openspec/changes/<change-id>/specs/<capability>/spec.md`。
- 变更验证使用 `npx openspec validate <change-id> --strict`。
- 归档前不要把 change 里的 delta 手动复制到 `openspec/specs/`，归档由 OpenSpec 流程处理。
- 归档前必须按 proposal/scope/tasks/spec delta 的原始范围逐项审计；不得因为只完成了第一阶段、文档部分或可运行子集，就把未完成实现临时改写成“后续 change”后宣称当前 change 完成。
- `npx openspec status --change <id>` 只能证明 proposal/design/specs/tasks 这些 artifact 文件齐全，不等于 tasks 里的复选框全部完成；归档前必须直接检查 `tasks.md` 是否还有 `- [ ]`，并确认每个未完成项是否仍属于原 proposal/scope。
- 用户说“后面做”“延后做”“先不做实现”只表示排期顺序，不自动表示该能力退出当前提案范围；除非用户明确同意拆分 scope，否则背包、能力、控制、装备等已写入 proposal/scope 的内容必须继续留在当前 change 的未完成项里。
- 若确需拆分 change，必须先在当前 change 里写清“原范围、拆出原因、用户确认、拆出后的归档边界”，并得到用户明确同意；不得为了归档而事后收窄验收口径。
- 任务进度、阶段状态、当前现态、当前完成性、当前验收结果、交接记录和下一步，默认写进对应 `openspec/changes/<change-id>/`；`docs/ai` 长期规范、导航和工具边界文档不得承载这类本轮任务快照。
- 如需在 `docs/ai` 留下关联信息，只允许保留长期规则、导航、职责边界或历史入口；不得继续把本轮进度、当前快照或阶段结论写成 `docs/ai` 规范文档的主入口。
- 若用户当前主任务已锁定为正式实现、替换或重构，change 文档的更新只能记录和约束实现，不得代替实现本身；没有推进 proposal / tasks 对应的正式代码、资产或验证时，不得把“文档已更新”汇报成该主任务完成。
- 若因为参考缺口申请临时并行控制器、并行测试场景或其它临时试做入口，流程理由文档必须写进当前活跃 change 目录，而不是写进 `docs/ai`。默认文件名使用 `parallel-trial-rationale-<topic>.md`。
- 上述流程理由文档至少写清：`参考缺口`、`为什么不能直接复用正式闭包`、`拟新增文件/Prefab/场景清单及其临时边界`、`删除或并回正式闭包的退出条件`。用户未明确同意前，不得实施。

## 参考和复用门禁

- change / proposal / design 里如果写“多方面参考”“各取所需”或语义等价表述，必须先按职责切片，再只比较当前职责直接相关的候选；不得把所有已登记参考一次性并排拉进来充数。
- 多参考分析必须按`职责`展开，不得按`参考项目/插件`逐个巡礼后再模糊下结论。若一段分析仍以“参考 A 有这些点、参考 B 有那些点”作为主体，而没有落到职责 owner，视为未完成裁决。
- 同一职责若存在多个候选，提案里必须明确写出：`当前职责`、`正式 owner`、`其余候选本次为什么不采用`。未写清前，不得把该职责落成混合正式方案。
- 若不同参考分别命中不同职责，可以同时采用；但提案必须把职责边界写清，避免把“多参考”误写成同一职责的双轨或多轨真相。
- “各取所需”不是把同一职责拆成“这个参考出一半数据结构、那个参考出一半运行时、第三个参考补作者流程”。只要它们竞争的是同一职责的作者真相、执行真相或运行时解释权，就必须裁成单一 owner，再谈吸收。
- 在 proposal / design 里写“各取所需”前，必须先判断当前项究竟属于“单一参考整体对齐”还是“多参考分职责吸收”。若某个单一参考已经完整覆盖该职责的作者数据、运行时解释和编辑流程，默认先整体对齐它；不能先决定混合，再回头给“各取所需”找理由。
- “择优吸收”必须按当前职责的 `覆盖完整度`、`闭包完整度`、`与项目硬约束的贴合度`、`可直接落地性`、`维护成本` 比较，不得只写“参考了主流做法”“综合考虑后采用”“这个也有可取处”。
- 只要 proposal / design 宣称“多方面参考”“各取所需”“择优吸收”或语义等价表述，就必须附一个 `职责裁决表` 或等价小节；最少列出：`职责`、`候选来源`、`正式 owner`、`本次吸收什么`、`本次明确不吸收什么`、`验证入口`。没有这张表，不得进入实现，也不得把“已参考多个来源”当成完成度证据。
- `职责裁决表` 不允许只写“都参考了”或“综合采用”。如果某一行仍存在两个正式 owner、两个作者入口、两份同职责数据格式或两套并行流程，这一行视为未裁决，不能进入 tasks 完成态，也不能作为实现依据。
- `职责裁决表` 若选择“多参考分职责吸收”，每一行都必须能单独成立，且不能跨行共享同一份正式真相的解释权。出现“这个参考管作者面，但另一个参考也能改同一份正式时间轴数据”这类重叠时，视为未裁决，必须回退到单一 owner 或重新切职责。
- 采用“多参考分职责吸收”时，proposal / design 还必须写清每个职责最终落在哪个`正式入口`上：作者数据、运行时解释、编辑/预览工具三者都必须各自唯一。若吸收后仍保留两个菜单入口、两份同职责资产格式、两套可编辑同一结果的数据来源，视为同职责双轨，不能进入实现。
- change 若以外部/本地参考项目、插件、源码或旧工程为目标基线，必须在 proposal、design 或单独 references 文件中写明参考矩阵：参考文件、证据等级、关键能力、当前 Unity 落点、差距、验证入口和未覆盖风险。
- 未完成参考矩阵和差距闭环前，tasks 不得把对应能力标为完成，也不得在 Verification Notes 中宣称“不低于参考”“正式完成”或“比参考更好”。
- change / proposal / design 若以单一参考为基线，且参考源码已可直接复制、直译或最小闭包改造时，默认执行顺序是“先照搬，再证明哪里必须改”。
- 若单一参考文件已经完整承载当前职责，而我方同职责文件明显更绕、更碎、更补丁化或更不统一，默认动作是直接用参考文件替换我方文件主体，再只补回当前项目确实需要、且能被参考矩阵或当前验收证明有价值的内容。
- 若单一参考已经覆盖当前职责的作者数据、运行时解释和编辑流程，除非能证明项目硬约束阻止直接对齐，否则不得把该职责再拆去吸收别的参考；“感觉更先进”“以后可能有用”“局部更顺手”都不构成拆源理由。
- 仍可直接对齐的项不得凭猜测、未核实差异或“先写一个项目特化版本再看”改写成“项目特化”或“更优方案”。
- 不是项目硬约束直接推出的偏离必须标为待决并等待用户决断；AI 只能提交证据、风险和候选方案，不能代替用户拍板。

## 当前活跃变更

- `define-fantasyword-foundation-framework` 已于 `2026-06-22` 归档到 `openspec/changes/archive/2026-06-22-define-fantasyword-foundation-framework/`，对应正式 capability spec 为 `openspec/specs/foundation-runtime/spec.md`。
- `formalize-equipment-visual-workbench` 已于 `2026-06-22` 归档到 `openspec/changes/archive/2026-06-22-formalize-equipment-visual-workbench/`，对应正式 capability spec 为 `openspec/specs/equipment-visual-workbench/spec.md`。
- `complete-composite-sandbox-character-runtime` 已于 `2026-06-22` 归档到 `openspec/changes/archive/2026-06-22-complete-composite-sandbox-character-runtime/`，其 delta 已并入 `openspec/specs/foundation-runtime/spec.md`。
- `define-skill-authoring-workbench` 已于 `2026-06-27` 归档到 `openspec/changes/archive/2026-06-27-define-skill-authoring-workbench/`，但当前正式 capability 已收口重命名为 `openspec/specs/ability-authoring-foundation/spec.md`；活跃规范不再把 `workbench` 作为技能主线正式术语。
- 当前活跃 change：`plan-core-framework-roadmap`。
- 当前活跃 change 只制定核心框架阶段路线，不实现具体技能、战斗、AI、世界交互、任务或建造系统。
