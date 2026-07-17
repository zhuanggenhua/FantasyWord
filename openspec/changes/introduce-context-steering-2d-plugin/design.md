# Design: introduce-context-steering-2d-plugin

## Locked Premises

- 问题对象：当前 `Assets/Plugins/FantasyWordSteering`、已迁入自有插件目录的 `Assets/ProjectPlugins/ContextSteering2D` 草稿，以及 `AIController.BehaviourRuntime` 中仍待迁移的项目侧移动求解逻辑。
- 真相来源：当前项目代码；UnitySteer 与 unity-movement-ai 行为源码；friedforfun、SunnyValley、AkiSteer context steering 核心源码；N:ORCA、N:Beacon.ORCA、pk1234 ORCA、RVO2-CS simulation 核心源码；用户给定 duolafashi 的 tsbuild 模块清单、source map 路径和可读编译 JS 业务实现。
- 目标入口/环境：Unity 6000.3.10f1，URP 2D，单机优先，GameCore 作为游戏语义接入方，`ContextSteering2D` 作为通用 steering/local avoidance 插件 owner。
- 验收口径：已确认没有单一现成免费插件完整胜出；正式进入“整合最佳实践”的通用 `ContextSteering2D` 设计与实现。不能在未对齐 UnitySteer 行为基线、context steering 调试结构和 ORCA/RVO 后端边界的情况下继续扩展劣化自研草稿。

## Decision Principle

本 change 的原则是：**无单一现成插件胜出时，整合最佳实践，但每个职责只能有一个正式 owner**。

已完成同职责比较，当前结论如下：

1. UnitySteer 是行为库基线，但不适合作唯一最终 owner。
2. N:ORCA/RVO 是局部避让后端候选，不是完整 steering 行为系统。
3. friedforfun ContextSteering 提供架构参考，但许可证不允许复制实现。
4. SunnyValley/AkiSteer 提供 2D context steering 和可视化参考，但不是插件质量上限。
5. duolafashi 使用了与 SunnyValley 高度一致的 `SteeringBehavior + eightDirections + danger/interest + ContextSolver` 骨架，并把它扩展为真实业务：追击、游走、冲刺三组行为，追击拦截点，绕目标半径与左右侧，前方友军侧让，以及一次检测结果分类障碍/友军。

源码复核后的补充裁决：

1. friedforfun 在同一职责上比当前竖切更完整：它明确拆分 behaviour map、mask map、context combinator 和 direction selector，并保留输出强度。当前 `interest-danger` 后立即归一化的结构不能作为最终设计。
2. UnitySteer / unity-movement-ai 证明传统 steering 输出需要速度或加速度语义；正确 Arrive 会产生目标速度和减速度，不是把目标方向写成 danger。
3. N:ORCA / pk1234 ORCA / RVO2-CS 都以 agent registry + preferred velocity + batch step + safe velocity 为核心。当前逐 agent `ILocalAvoidanceSolver2D.Resolve(frame, profile)` 无法直接承接这类后端。
4. SunnyValley 的优势是行为结果与 Gizmos 紧密对应，不是固定 8 方向数组或 `AIData` 结构。应吸收逐行为可解释性，不复制教程运行架构。
5. AkiSteer 的 NonAlloc 检测和 Inspector 可见数组有参考价值，但 Odin 依赖、固定数组和 MonoBehaviour 组合不进入正式设计。
6. duolafashi 证明行为组合必须随 AI 状态切换，因此 Profile 不能只有一条固定行为栈；但其固定八方向、每次分配数组、原地排序目标、随机选边、始终归一化输出和 Around 中的近似 VO 代码都不能直接移植。
7. N:ORCA、pk1234 ORCA 与 RVO2-CS 都使用统一 simulation step；后端选择和时钟必须属于世界级 simulation 配置，不能属于单个角色 Profile。角色 Profile 只能提供半径、邻居范围、时间视野、避让责任或优先级等参与参数。
8. N:ORCA 与 RVO2-CS 的参考实现会在模拟内部积分位置，pk1234 示例也可直接改刚体速度；FantasyWord 的正式 adapter 必须只消费 collision-free velocity，由 GameCore 移动执行层统一移动角色，避免 steering 后端成为第二个移动 owner。
9. 标准 RVO2 对双方采用固定一半责任；大型单位与小型单位的非对称压力传播由独立 PBD 接触阶段按质量与优先级解析，不伪装成 RVO2 原生能力。

## UnitySteer Verdict

UnitySteer 是当前最强的免费传统 steering 行为库候选。

已确认事实：

- MIT 许可证。
- UnitySteer 3.1，README 明确 Unity 5.x 起支持 2D。
- 仓库包含 2D、3D、Attributes、Editor、TickedPriorityQueue。
- 本地源码统计：81 个 C# 文件，其中 2D 35 个、3D 36 个、Editor 5 个。
- 2D 示例覆盖 point、path following、wander、pursuit/evasion、neighbor alignment/cohesion/separation、obstacle avoidance。
- 运行模型以 `Vehicle2D`、`Steering2D`、`Radar2D`、`TickedVehicle2D` 为核心。
- `Vehicle2D` 通过 `GetComponents<Steering2D>()` 收集挂在同一对象上的行为组件。
- `Radar2D` 使用 `TickedPriorityQueue` 做分频检测更新。
- 编辑器能力主要是 Gizmos 和少量 PropertyDrawer。

UnitySteer 不作为 FantasyWord 第一阶段唯一正式 owner，原因如下：

- 旧 Unity 时代代码，没有现代 asmdef/package 边界。
- 组件式作者入口较重，可能和 FantasyWord 的配置资产、稳定入口、可审计数据流冲突。
- 缺共享检测帧合同，不能直接服务 steering、攻击预检和局部避让复用。
- 缺 ORCA/RVO 后端抽象。
- 缺我们需要的编辑器调试面板和 profile 预览。

UnitySteer 的正式角色：

- 行为目录最低基线。
- 传统 steering 行为和数学实现参考。
- 可选 isolated compile 原型，用于验证风险和行为对照。
- 若直接移植代码，必须保留 MIT attribution。

## Target Architecture

目标架构采用“游戏语义 adapter、集中式 simulation、共享检测、Profile 行为栈、context 合成与方向选择、局部避让后端、调试快照”七层。

源码复核后的实现顺序必须是：提交意图 -> 建立单位空间索引/检测快照 -> Context preferred velocity -> RVO safe velocity -> PBD 接触约束 -> 发布结果 -> GameCore 移动。RVO 处理提前避让，PBD 处理密集接触和压力传播；任何一个阶段都不得直接成为第二移动 owner。

### GameCore Adapter

FantasyWord 只负责游戏语义：

- 目标选择。
- 阵营/仇恨过滤。
- 攻击距离和技能触发。
- 当前移动执行。
- 角色身体半径、移动优先级、可移动状态、动画/朝向参数。

GameCore 不直接持有采样方向数组、interest/danger 合成、局部避让求解、UnitySteer 组件细节或 ORCA 模拟细节。

GameCore 也不直接 `new ContextSteeringSolver2D()` 或 `new SteeringDetectionScheduler2D()`。它通过正式 adapter 注册/注销 agent，按 tick 提交目标与身体数据，并读取最终移动结果。

### Steering Simulation

插件必须有场景/世界级 simulation owner，负责：

- agent 注册、稳定句柄与生命周期。
- tick 顺序和分频策略。
- 共享检测帧构建与缓存。
- 对所有 active agent 计算 preferred velocity。
- 将 preferred velocity 批量交给当前局部避让后端。
- 发布最终结果和不可变 debug snapshot。

第一阶段实现可以仍用 Physics2D 非分配查询，但公开合同必须允许未来改成空间哈希、集中式 broadphase 或 ORCA 自有邻居结构，而不改 GameCore 调用方。

注册单位之间的邻居查询不得继续使用每个 Agent 一次 Physics2D 扫描或全量两两遍历。世界 simulation 每个固定步至少建立一次统一空间索引，Context 邻居行为、RVO/PBD 接触和调试快照从该批次数据读取。Physics2D 查询只保留给不在 Agent registry 内的场景障碍和项目语义 Collider。

### Steering Behaviour Layer

行为层优先以 UnitySteer 能力为最低基线：

- Seek / point target。
- Arrive。
- Path following。
- Wander。
- Pursuit / evasion。
- Separation。
- Cohesion。
- Alignment。
- Obstacle avoidance。
- Follow / matching velocity。

第一期不必一次实现全部行为，但不得把“只做 seek + avoid + separation”描述成完整插件完成态；只能称为第一阶段竖切。

作者入口不是场景组件列表，而是一个 `ContextSteeringProfile2D` 内的命名行为组集合。每个行为组拥有稳定 ID 和一组行为层；每个行为条目拥有自己的启用状态、权重和专属参数。Profile 还可提供该角色的局部避让参与参数，但不选择世界级后端。插件内置组只使用 `default`、`transit`、`predictive-target` 这类通用能力名；GameCore 在 AI 配置中显式把路线中段、追击等业务状态映射到组 ID，插件不发布 `path-follow`、`pursuit` 或 `chase` 业务常量。行为实现读取共享检测帧，写入独立 contribution，不直接覆盖全局数组。

Seek/Pursuit/Orbit 等行为负责方向兴趣；Arrival 只提供速度约束，不得再次写入与 Seek 相同的目标兴趣。行为列表在加权/最大值合成模式下只是稳定数据顺序和调试顺序，不得提供暗示优先级生效的上下排序 UI；只有新增正式 priority combinator 后，顺序才能成为运行语义。

行为输出必须能表达方向以外的强度/速度约束。`Arrive`、`Velocity Match`、预测 Collision Avoidance 等行为不得被压缩成单位方向。

### Context And Direction Selection

Context 层吸收 context steering 最佳实践：

- 用采样方向表达候选移动方向。
- 每个行为拥有独立 contribution map；危险/不可行方向使用独立 constraint/mask map。
- context combinator 负责合成行为和约束，不能把合成策略写死在数组 setter 中。
- direction selector 负责从合成图选方向并保留强度。
- 最终生成 preferred velocity 或等价的方向 + speed scale，作为局部避让输入。
- debug value 必须保留所有启用行为的贡献，而不是只保留每个方向的最大来源。

### Shared Detection Frame

共享检测帧是 FantasyWord 特有刚需，UnitySteer 不能直接覆盖。

要求：

- 同一 tick 内目标、邻居、障碍、身体参数只采集一次。
- steering 行为、推挤/局部避让、攻击预检可以读取同一份快照。
- 快照必须能输出调试信息：命中过滤、最近点、距离、半径、贡献向量。
- 障碍与邻居必须使用不同语义过滤；不能在接入层把同一个 collision filter 同时当成 obstacle filter 和 neighbour filter。
- 目标搜索、视线、攻击距离若无法复用同一物理查询，也必须通过 adapter 明确记录剩余重复成本，不能直接标成已复用。

### Local Avoidance Backend

第一期竖切曾使用轻量后端，但正式完成态不得继续把逐 Agent 近似避让保留为默认实现。正式后端采用 Apache-2.0 RVO2 算法合同：世界级 Agent registry、每 Agent preferred velocity/max speed/radius/time horizon、KD-Tree 邻居查询和批量 step。内部位置只能作为求解副本，每个固定步由 authoritative Rigidbody 状态覆盖，最终只消费 safe velocity。

后端接口必须以批量 simulation 为最终合同，至少支持：

- 输入 authoritative position、current velocity、preferred velocity、radius、邻居范围、时间视野、避让责任/优先级和邻居/障碍语义。
- 输出 collision-free velocity。
- 后端选择、固定步长、调度和完成同步由世界级 simulation 统一拥有；单个 Profile 不得选择另一套后端或时钟。
- 后端不得直接写 Transform、Rigidbody 或最终角色位置；GameCore movement adapter 是唯一移动执行 owner。
- RVO2 后端和后续 Job/Burst 后端使用同一上层结果合同。
- Separation 继续属于 steering behaviour，不塞进 ORCA 名义后端。
- overlap/push resolve 作为独立最终穿透修正阶段，可使用质量/优先级，但不冒充预测局部避让。
- 后续集中式 crowd solver 不需要修改 GameCore adapter。
- 静态障碍与动态障碍必须显式注册并具有不同更新策略；不得让每个 agent 私自重复转换 Collider。

### Position-Based Contact

密集单位接触使用独立世界级阶段，参考 Position-Based Real-Time Simulation of Large Crowds：

- 由 safe velocity 计算预测位置。
- 使用统一网格/空间索引生成唯一接触对，禁止每个单位分别解析同一对。
- 使用 Jacobi 方式累计每轮修正，轮末统一应用，避免注册顺序改变结果。
- 修正责任按逆阻力分配；阻力由质量和移动优先级组成，大单位可承担更少修正，小单位承担更多。
- 输出接触位移修正，由 GameCore 移动层执行；不得在插件内写 Transform/Rigidbody。
- 必须用真实多帧测试验证解除重叠、大小单位非对称位移、拥堵稳定性和注册顺序不变性。

### Editor And Visualization

编辑器层不能只停留在 UnitySteer 的 Gizmos 水平。

最低要求：

- SceneView 显示目标方向、各行为贡献、邻居、障碍、最终方向、推挤/避让修正。
- Inspector 显示当前 profile/adapter、行为权重、当前输出和检测快照摘要。
- 支持静态 profile 预览或 isolated preview，便于不进 Play Mode 调参。
- SceneView 只保留一个正式绘制 owner，避免 `OnDrawGizmos` 与 `SceneView.duringSceneGui` 重复画同一份数据。
- 静态预览必须执行与运行时相同的 behaviour/combinator/selector 链；只画采样圆和探测半径不算求解预览。
- Inspector 和 SceneView 读取不可变 debug snapshot，按行为来源开关 contribution、constraint、preferred velocity、safe velocity 和 push correction。

## Migration Plan

1. 保留已做深搜证据：`deep-search-report.md`、`unitysteer-deep-dive.md`、`extra-deep-candidates.json`。
2. 保留当前方向集、共享帧数据模型和非分配检测缓冲，删除硬编码行为数组、最大来源字符串和逐 agent 固定后端。
3. 将 Profile 重构为多个命名行为组及其有序行为栈，并引入独立 contribution、context combinator、direction selector 和 preferred velocity 输出合同。
4. 将局部避让改成 simulation 级批量后端合同，使轻量后端与未来 N:ORCA/RVO 共用上层 adapter。
5. 可选做 UnitySteer isolated import compile 原型，用作行为对照和风险校验，而不是正式 owner 切换前提。
6. 建立 editor/debug 入口，不能只停留在 Gizmos。
7. 改造 `AIController.BehaviourRuntime`，让其只依赖正式 adapter，不再私有创建 solver/scheduler。
8. 移除旧 `FantasyWordSteering` 引用，旧目录删除或保留为未接入参考必须有明确退出条件。
9. 跑 Unity 编译、行为测试、移动测试场景端到端、SceneView 调试截图。

## Non Goals

- 不再寻找单一“完美插件”拖延实现；当前结论是整合最佳实践。
- 不在未证明收益前继续扩展当前劣化自研草稿。
- 不把 UnitySteer separation 冒充 ORCA/RVO。
- 不把 duolafashi 当算法实现蓝本。
- 不声称已经达到全面战争最终规模；完成口径至少包含 RVO2、PBD 接触压力传播以及 100/500/1000 Agent 的新鲜性能证据，规模上限以实测为准。
