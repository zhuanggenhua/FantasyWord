# Reference Matrix: introduce-context-steering-2d-plugin

## Audit Boundary

- 下表只列参与最终架构裁决的参考；这些参考已经覆盖其检测/输入、行为或约束计算、组合/求解、调度、移动接入和调试入口中的适用核心链。
- “源码级复核”不表示逐行读取仓库内所有示例、历史兼容代码、第三方依赖和非相关 3D/编辑器文件。
- `candidate-list.json`、`extra-deep-candidates.json` 中未进入下表的搜索候选只完成仓库级筛选，不得称为源码深读，也不得用于支撑正式架构结论。

## Evidence Files

- `test-results/context-steering-research/deep-search-report.md`
- `test-results/context-steering-research/unitysteer-deep-dive.md`
- `test-results/context-steering-research/focused-summary.txt`
- `test-results/context-steering-research/extra-deep-candidates.json`
- `test-results/context-steering-research/repos/ricardojmendez__UnitySteer/UnitySteer-master`
- `test-results/context-steering-research/repos/ricardojmendez__UnitySteerExamples`
- `test-results/context-steering-research/repos/Nebukam__com.nebukam.orca`
- `test-results/context-steering-research/repos/Nebukam__com.nebukam.beacon-orca`
- `test-results/context-steering-research/repos/pk1234dva__orca_local_avoidance`
- `test-results/context-steering-research/repos/snape__RVO2-CS`
- `test-results/context-steering-research/repos/friedforfun__ContextSteering`
- `test-results/context-steering-research/repos/AkiKurisu__AkiSteer`
- `test-results/context-steering-research/repos/sturdyspoon__unity-movement-ai`
- `test-results/context-steering-research/repos/SunnyValleyStudio__Unity-2D-Context-steering-AI`
- `test-results/context-steering-research/repos/warmtrue__RVO2-Unity`
- `test-results/context-steering-research/repos/unitycoder__Unity-DOTS-RTS-Collision-System`
- `test-results/context-steering-research/repos/wayne-wu__webgpu-crowd-simulation`
- `test-results/context-steering-research/repos/mrdav30__LockstepRTSEngine`

## Best-Practice Integration Matrix

| 来源 | 证据等级 | 关键能力 | 当前 Unity 落点 | 差距 | 风险 |
|------|----------|----------|----------------|------|------|
| UnitySteer | 已下载源码、README、License、CHANGELOG、示例仓库并做深读 | MIT；2D/3D steering toolkit；Vehicle/Steering/Radar；seek、path、wander、pursuit/evasion、separation、cohesion、alignment、obstacle avoidance；TickedPriorityQueue | 行为库和传统 steering 最低基线 | 旧 Unity 5 时代结构；无 asmdef/package；组件式作者入口；无共享检测帧；调试主要是 Gizmos | 大量参考和按需移植；不直接作为最终 owner |
| UnitySteerExamples | 已下载示例仓库 | 2D/3D point、path、wander、neighbor、obstacle avoidance 示例场景和 prefab | 行为验收对照和作者流程评估 | 示例包含额外 GoKit 等历史依赖；不能直接整体导入项目 | 只读参考和最小复现实验，不能污染正式项目 |
| N:ORCA | 已读取 ORCABundle、Agent/AgentGroup、AgentProvider/KDTree、ORCALines/Apply Jobs 和 Setup 调度源码 | ORCA/RVO local avoidance；Job/Burst；agent registry；preferred/safe velocity；XY/XZ；layer；静态/动态障碍 | 集中式后端候选 | 每 agent job 使用临时 NativeList；示例 Update 调度、LateUpdate 非阻塞完成；算法内部会积分位置；依赖 Nebukam 子包 | 参考批量合同，正式 adapter 只消费安全速度，不照搬位置 owner 和示例时序 |
| N:Beacon.ORCA | 已读取 ORCABeacon、Processor、ObstacleConverter、Circle/Edge/Polygon 转换和示例源码 | N:ORCA 组件层；preferred velocity adapter；Collider 到静态/动态障碍转换；Scene Gizmo | ORCA 作者流程与 obstacle adapter 参考 | 自管理默认 Bundle、自动 GetComponent 和组件级生命周期不符合显式世界入口 | 吸收 Collider 转换与调试思路，不直接采用自管理作者入口 |
| pk1234dva/orca_local_avoidance | 已读取 Simulator/Worker、AgentBase 求解、OrcaManager、Settings、刚体样例和 Editor 源码 | Apache-2.0；集中式 Simulator；KdTree；常驻线程；固定更新频率；3D ORCA 平面；非对称避让责任；结果可转刚体加速度 | 大小单位让行参数和 ORCA 后端合同参考 | Resources 单例自动创建；手写线程同步；只处理 agent；3D 求解成本；编辑器仅基础字段 | 吸收避让责任权重，后端和移动执行保持分离 |
| RVO2 / RVO2-CS | 已读取 Simulator DoStep、Agent 邻居/障碍约束与线性规划、KdTree 构建/查询核心源码 | ORCA/RVO2 基准算法；统一 step；preferred velocity；安全速度；静态障碍预处理；双方固定各承担一半避让责任 | 算法和批量 simulation 合同基准 | 内部直接积分位置；静态障碍需显式 ProcessObstacles；不是 Unity 作者体验插件 | 作为算法基准，不直接作为项目插件或移动 owner |
| friedforfun/ContextSteering | 已读取 controller、behaviour、mask、combinator、direction selector、visualiser 和测试源码 | 独立 behaviour/mask maps；可替换 combinator/selector；输出保留强度；逐图可视化 | Context/selector/debug 架构基线 | MPL-2.0，不复制代码；部分实现有 LINQ 分配和未完成 selector | 吸收职责分层和合同，不复制实现 |
| SunnyValleyStudio/Unity-2D-Context-steering-AI | 已逐文件读取 AIData、Detector、Seek、ObstacleAvoidance、ContextSolver、EnemyAI 和 AgentMover | 固定 8 方向 interest/danger；行为自产 Gizmos；检测、求解、移动闭环 | 2D 调试表达和最小闭环参考 | 行为少；每次求解分配数组；非插件级；目标 Raycast mask 存在配置风险 | 吸收逐行为直观调试，不采用其运行架构 |
| AkiSteer | 已读取 Detector、DirectionSolver、SteerBehavior、SteerController、Seek、ObstacleAvoidance 和移动接入源码 | NonAlloc 检测；interest/danger；Inspector 数组；行为组合 | 调试和检测实现参考 | 依赖 Odin；固定数组；3D/PathCreator 风格明显 | 不直接导入，不采用固定数组和组件作者入口 |
| unity-movement-ai | 已读取 SteeringBasics、Arrive、CollisionAvoidance、Separation、WallAvoidance 和 Rigidbody adapter 源码 | 正确速度/加速度语义；Arrive 减速；预测碰撞；whisker 避障；2D/3D movement adapter | 行为输出合同和行为目录参考 | 项目较旧，组件/示例型；部分热路径会分配 | 吸收数学和输出语义，不照搬组件组织 |
| duolafashi 业务实现 | 已读取 tsbuild 原始模块路径、source map 和编译 JS 中的 SteeringBehavior、Around、ObstacleAvoidance、Seek、Separation、ContextSolver、Detector、EnemyAI 及行为树调用 | SunnyValley 式八方向 context steering；追击预测；绕目标游走；前方友军侧让；单次检测分类；Chase/Orbit/Sprint 行为组 | 业务行为编排、Pursuit/Orbit/Side-step 和行为组切换参考 | 原始 TS 未随工程提供；固定八方向；热路径分配；随机选边；Around 近似 VO 有明显可疑逻辑；输出丢失速度强度 | 吸收业务需求和模式切换，不复制编译实现，不作为 ORCA/推挤基线 |
| 当前 FantasyWordSteering | 已读取项目源码 | 8 方向 seek/avoid 草稿 | 待替换对象 | 功能少、无编辑器、无最佳实践整合 | 不继续扩展为正式插件 |
| warmtrue/RVO2-Unity | 已读取 Unity 接入、动态 Agent、障碍转换和 RVO2 核心源码 | Apache-2.0；动态增删 Agent；KD-Tree；preferred velocity；统一 `doStep` | 正式 ORCA/RVO 后端实现参考 | Unity 2017；全局单例；手写 ThreadPool/WaitHandle；模拟内部积分位置 | 吸收 RVO2 算法和动态 Agent 生命周期；不复制单例、线程调度和位置 owner |
| Unity DOTS RTS Collision | 已读取固定网格、碰撞对生成和解析 Job | 3-5 万单位固定网格 broadphase；质量字段；批量碰撞对 | 大规模邻居索引参考 | 固定巨型网格浪费内存；解析阶段计算的新速度未写回，位置仍等分修正 | 只吸收集中网格和唯一碰撞对，不复制解析公式与固定容量实现 |
| Position-Based Crowd Simulation (WebGPU) | 已读取 README、compute pipeline、hash grid、短程接触、长程约束、速度回算和迭代调度 | BSD-3-Clause；基于 MIG 2017 PBD Crowd；预测位置；hash grid；Jacobi 约束；逆质量；短程接触和摩擦 | 密集接触、压力传播和推挤解析基线 | WebGPU/GPU 数据布局、硬编码世界尺寸和渲染管线不适合直接移植 | 吸收阶段顺序、逆质量分配、Jacobi 迭代和空间网格；在 Unity C# 中重写 |
| LockstepRTSEngine | 已读取确定性物理管理、空间分区和唯一碰撞对入口 | 固定步长；分区网格；碰撞对去重；模拟与表现分离 | 固定帧和碰撞对生命周期参考 | 老旧自定义定点物理体系过重 | 只吸收显式阶段和碰撞对去重，不导入整套物理/锁步框架 |

## Final Integration Verdict

没有单一免费插件完整胜出，因此 `ContextSteering2D` 是正式 owner。参考职责分配如下：

- UnitySteer：传统 steering 行为目录、Vehicle/Steering/Radar 分层、邻居/障碍行为的最低能力基线。
- friedforfun ContextSteering：controller/behaviour/mask/direction-picker/context combinator 架构参考，只吸收设计。
- SunnyValley/AkiSteer：2D interest/danger 可视化、Gizmos 和调试体验参考。
- N:ORCA / pk1234 ORCA / RVO2：局部避让后端候选，不进入第一期默认依赖。
- duolafashi：真实业务行为和状态化行为组参考；其骨架来自 SunnyValley，但业务扩展证明 Pursuit、Orbit、友军侧让和 mode 切换是正式需求；不作为 ORCA 或插件架构 owner。
- 当前 FantasyWordSteering：待替换对象，只能迁移输入经验，不能延续命名和结构。
- warmtrue/RVO2-Unity：补强 RVO2 的 Unity 动态 Agent 接入证据；正式实现不得保留其静态单例和内部位置 owner。
- Position-Based Crowd Simulation：密集接触与推挤的正式算法基线；它和 ORCA 分工，不互相冒充。
- Unity DOTS RTS Collision：证明均匀网格适合大规模单位 broadphase，但其碰撞解析存在明显实现缺口，只参考索引结构。

源码级职责裁决后的最终结构：

- 作者真相：一个 `ContextSteeringProfile2D` 内的多个命名行为组，每组一条有序行为栈。
- 行为输出：独立 contribution/constraint maps，并保留速度强度。
- 决策真相：独立 context combinator + direction selector。
- simulation 真相：场景/世界级 agent registry 和 tick owner。
- 局部避让真相：批量 preferred velocity -> collision-free velocity 后端。
- 穿透修正：独立 overlap/push 阶段，不冒充 ORCA。
- 密集接触：批量预测位置进入统一空间索引，按唯一单位对执行多轮 Jacobi 位置约束；修正责任按逆阻力（质量与优先级）分配。
- 调试真相：一份不可变 snapshot 和一个 Editor 绘制入口。

## Post-Audit Decision

参考复核后，正式运行链采用两个互补阶段：

1. Context Steering 生成 preferred velocity；ORCA/RVO 负责碰撞发生前的互惠速度避让。
2. Position-Based Contact 以 RVO 结果生成预测位置，使用统一空间索引和多轮 Jacobi 约束处理已经发生或不可避免的密集接触，再输出接触位移修正。

两阶段都不能直接移动 Unity Transform/Rigidbody。GameCore 仍是唯一移动执行方。质量和优先级只决定双方承担多少接触修正；不得把普通 Separation、单单位 `OverlapCircle` 或逐 Agent 穿透修正称为大规模推挤解析。

## Guidance From UnitySteer

- 行为库不能只做 seek/avoid/separation；至少要按 UnitySteer 行为目录规划阶段。
- `Vehicle` 与 `Steering` 的职责切分合理，可作为 adapter 和 behaviour 分层参考。
- 邻居行为应至少覆盖 separation、cohesion、alignment 三类，而不是只做“推开”。
- Radar/检测更新可分频，但 FantasyWord 需要更明确的共享检测帧合同。
- Gizmos 是调试基础，但不是最终编辑器体验上限。

## Guidance From N:ORCA / RVO

- ORCA/RVO 是局部避让后端，不是完整 AI 行为系统。
- 后端接口需要从第一期就保留，否则未来会重做 detection 和 movement adapter。
- ORCA 可解决平滑错身，不等于物理推挤或大型单位权重挤压。

## Guidance From Context Steering References

- interest/danger 对调试解释很好，适合 profile 预览和 SceneView 显示。
- friedforfun 的 controller/behaviour/mask/direction-picker 分层值得参考，但不能复制 MPL-2.0 代码。
- SunnyValley 和 AkiSteer 适合解释 2D context steering 与 Gizmos，不适合作插件质量上限。

## Guidance From duolafashi

- duolafashi 的运行骨架明显参考 SunnyValley，但它已是实际业务实现，不只是需求描述。
- `chaseBehaviours`、`wanterBehaviours`、`sprintBehaviours` 证明同一个 NPC 需要按业务状态切换行为组。
- Seek 中的拦截点计算应在正式插件中表达为 Pursuit，而不是污染普通 Seek。
- Around 中的目标半径、左右侧和友军绕让可转化为 Orbit/Strafe 行为参数，但不能照搬其中随机选边和近似 VO 实现。
- ObstacleDetector 一次查询后分类障碍与友军，强化共享检测帧设计。
- duolafashi 不证明它的 separation 就是最佳推挤解析。
- 不能复制打包 JS 或绑定 MetaWorld API。
