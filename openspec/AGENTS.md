# OpenSpec 工作规范

本目录是 `FantasyWord` Unity 版的正式规格入口。涉及 spec、proposal、change、架构边界、阶段拆分、验收标准时，优先读取本文件和对应 `openspec/changes/*`。

## 使用规则

- 当前项目没有继承旧 `FantasyWorld` 恢复任务用户故事，也不继承 `dark-corridor` 的横版动作 OpenSpec change。
- 新需求先进入 `openspec/changes/<change-id>/`，再按 proposal、design、tasks、spec delta 收敛。
- spec delta 必须写在 `openspec/changes/<change-id>/specs/<capability>/spec.md`。
- 变更验证使用 `npx openspec validate <change-id> --strict`。
- 归档前不要把 change 里的 delta 手动复制到 `openspec/specs/`，归档由 OpenSpec 流程处理。
- 归档前必须按 proposal/scope/tasks/spec delta 的原始范围逐项审计；不得因为只完成了当前、文档部分或可运行子集，就把未完成实现临时改写成“后续 change”后宣称当前 change 完成。
- `npx openspec status --change <id>` 只能证明 proposal/design/specs/tasks 这些 artifact 文件齐全，不等于 tasks 里的复选框全部完成；归档前必须直接检查 `tasks.md` 是否还有 `- [ ]`，并确认每个未完成项是否仍属于原 proposal/scope。
- 用户说“后面做”“延后做”“先不做实现”只表示排期顺序，不自动表示该能力退出当前提案范围；除非用户明确同意拆分 scope，否则背包、能力、控制、装备等已写入 proposal/scope 的内容必须继续留在当前 change 的未完成项里。
- 若确需拆分 change，必须先在当前 change 里写清“原范围、拆出原因、用户确认、拆出后的归档边界”，并得到用户明确同意；不得为了归档而事后收窄验收口径。
- 任务进度、阶段状态、当前现态、当前完成性、当前验收结果、交接记录和下一步，默认写进对应 `openspec/changes/<change-id>/`；`.spec/knowledge/features/project` 长期规范、导航和工具边界文档不得承载这类本轮任务快照。
- 如需在 `.spec/knowledge/features/project` 留下关联信息，只允许保留长期规则、导航、职责边界或历史入口；不得继续把本轮进度、当前快照或阶段结论写成 `.spec/knowledge/features/project` 规范文档的主入口。
- 若用户当前主任务已锁定为正式实现、替换或重构，change 文档的更新只能记录和约束实现，不得代替实现本身；没有推进 proposal / tasks 对应的正式代码、资产或验证时，不得把“文档已更新”汇报成该主任务完成。
- 若因为参考缺口申请临时并行控制器、并行测试场景或其它临时试做入口，流程理由文档必须写进当前活跃 change 目录，而不是写进 `.spec/knowledge/features/project`。默认文件名使用 `parallel-trial-rationale-<topic>.md`。
- 上述流程理由文档至少写清：`参考缺口`、`为什么不能直接复用正式闭包`、`拟新增文件/Prefab/场景清单及其临时边界`、`删除或并回正式闭包的退出条件`。用户未明确同意前，不得实施。

## 参考和复用门禁

- change / proposal / design 里如果写“多方面参考”“各取所需”或语义等价表述，必须先按职责切片，再只比较当前职责直接相关的候选；不得把所有已登记参考一次性并排拉进来充数。
- 多参考分析必须按`职责`展开，不得按`参考项目/插件`逐个巡礼后再模糊下结论。若一段分析仍以“参考 A 有这些点、参考 B 有那些点”作为主体，而没有落到职责 owner，视为未完成裁决。
- 同一职责若存在多个候选，提案里必须明确写出：`当前职责`、`正式 owner`、`其余候选本次为什么不采用`。未写清前，不得把该职责落成混合正式方案。
- 若不同参考分别命中不同职责，可以同时采用；但提案必须把职责边界写清，避免把“多参考”误写成同一职责的双轨或多轨真相。
- “各取所需”不是把同一职责拆成“这个参考出一半数据结构、那个参考出一半运行时、第三个参考补作者流程”。只要它们竞争的是同一职责的作者真相、执行真相或运行时解释权，就必须裁成单一 owner，再谈吸收。
- 在 proposal / design 里写“各取所需”前，必须先判断当前项究竟属于“单一参考整体候选”还是“多参考分职责吸收”。若某个单一参考完整覆盖该职责，必须把它作为完整候选与当前正式 owner 做同职责比较；完整覆盖不等于天然更优，也不能先决定混合，再回头给“各取所需”找理由。
- “择优吸收”必须把当前正式 owner 作为基线，按当前职责的 `功能与异常闭包`、`正确性与确定性`、`与项目硬约束的贴合度`、`作者/编辑流程`、`调试与测试能力`、`运行时成本`、`集成与迁移成本`、`长期维护成本`、`许可证与升级风险` 比较，不得只写“参考了主流做法”“综合考虑后采用”“这个也有可取处”。
- 只要 proposal / design 宣称“多方面参考”“各取所需”“择优吸收”或语义等价表述，就必须附一个 `职责裁决表` 或等价小节；最少列出：`职责`、`候选来源`、`正式 owner`、`本次吸收什么`、`本次明确不吸收什么`、`验证入口`。没有这张表，不得进入实现，也不得把“已参考多个来源”当成完成度证据。
- `职责裁决表` 不允许只写“都参考了”或“综合采用”。如果某一行仍存在两个正式 owner、两个作者入口、两份同职责数据格式或两套并行流程，这一行视为未裁决，不能进入 tasks 完成态，也不能作为实现依据。
- `职责裁决表` 若选择“多参考分职责吸收”，每一行都必须能单独成立，且不能跨行共享同一份正式真相的解释权。出现“这个参考管作者面，但另一个参考也能改同一份正式时间轴数据”这类重叠时，视为未裁决，必须回退到单一 owner 或重新切职责。
- 采用“多参考分职责吸收”时，proposal / design 还必须写清每个职责最终落在哪个`正式入口`上：作者数据、运行时解释、编辑/预览工具三者都必须各自唯一。若吸收后仍保留两个菜单入口、两份同职责资产格式、两套可编辑同一结果的数据来源，视为同职责双轨，不能进入实现。
- change 若以外部/本地参考项目、插件、源码或旧工程为目标基线，必须在 proposal、design 或单独 references 文件中写明参考矩阵：参考文件、证据等级、关键能力、当前 Unity 落点、差距、验证入口和未覆盖风险。
- 未完成参考矩阵和差距闭环前，tasks 不得把对应能力标为完成，也不得在 Verification Notes 中宣称“不低于参考”“正式完成”或“比参考更好”。
- 当前正式 owner 是比较基线，不是不可修改的圣域；外部参考若在同一职责和同一验收口径下被证明确有更高净价值，可以提出重构、整体替换或正式扩展。
- “更好”必须有可核验证据，至少说明：当前方案的具体缺陷、参考方案如何直接解决、对现有作者数据/运行时/编辑流程的影响、迁移与兼容成本、许可证与后续升级风险，以及回到哪个原始入口验收。仅凭代码更短、架构更新、名气更大、感觉更统一或未来可能有用，不构成重构依据。
- 只有当参考方案的收益明确覆盖迁移成本、回归风险、双轨过渡成本和长期维护成本时，才允许把正式 owner 改为参考方案或基于其重构；否则保留当前 owner，只吸收能独立证明有价值的缺口能力。
- 如果“是否真的更好”仍缺关键证据，先做最小对照原型、基准测试、合同测试或作者流程试验；结论未锁定前不得实施正式替换，也不得在提案中宣称参考方案更优。
- 若单一参考胜出，最终仍必须保持单一正式 owner，不得以迁移为名长期保留两套作者入口、两套运行时解释或两份同职责状态真相。
- 对比后仍存在无法由证据消除的产品取舍时，必须列出收益、代价和不可逆影响，交由用户决断；AI 不得把个人架构偏好包装成“参考方案更好”。

## 当前活跃变更

- `define-fantasyword-foundation-framework` 已于 `2026-06-22` 归档到 `openspec/changes/archive/2026-06-22-define-fantasyword-foundation-framework/`，对应正式 capability spec 为 `openspec/specs/foundation-runtime/spec.md`。
- `formalize-equipment-visual-workbench` 已于 `2026-06-22` 归档到 `openspec/changes/archive/2026-06-22-formalize-equipment-visual-workbench/`，对应正式 capability spec 为 `openspec/specs/equipment-visual-workbench/spec.md`。
- `complete-composite-sandbox-character-runtime` 已于 `2026-06-22` 归档到 `openspec/changes/archive/2026-06-22-complete-composite-sandbox-character-runtime/`，其 delta 已并入 `openspec/specs/foundation-runtime/spec.md`。
- `define-skill-authoring-workbench` 已于 `2026-06-27` 归档到 `openspec/changes/archive/2026-06-27-define-skill-authoring-workbench/`，但当前正式 capability 已收口重命名为 `openspec/specs/ability-authoring-foundation/spec.md`；活跃规范不再把 `workbench` 作为技能主线正式术语。
- 当前活跃 change：
  - `plan-core-framework-roadmap`：只制定核心框架阶段路线，不实现具体技能、战斗、AI、世界交互、任务或建造系统。
  - `implement-element-reaction-foundation`：实现首条世界地表元素反应竖切；角色伤害与角色状态继续由 EX-GAS 承担，不创建第二套角色状态框架。
  - `implement-persistent-world-terrain-mutation`：定义玩家行为持久改变世界地貌的保存/加载闭环；首批承接喷火烧毁草覆盖层后露出底层土壤、草层可再生且重载仍保持进度，不把表现覆盖层当保存真相。
  - `implement-realtime-terrain-navigation`：推进即时制连续点击移动、单层高低地与坡道导航闭环，并作为多层地形实施的前置 change。
  - `introduce-multilevel-terrain-navigation`：定义桥面/桥洞等重叠可行走表面的节点身份、跨层连接、碰撞、渲染、点击解析与地表状态隔离；当前仅完成提案，尚未进入代码和场景实施。
