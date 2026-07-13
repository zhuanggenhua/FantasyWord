# Proposal: introduce-context-steering-2d-plugin

## Why

当前 `Assets/Plugins/FantasyWordSteering` 只是把 `AIController` 里的 8 方向 seek/avoid 抽成一个 `SteeringSolver2D`。它不是插件级能力：没有成熟行为库、没有配置资产闭包、没有可复用命名、没有清晰编辑器调试，也没有局部避让后端裁决。

深搜结论已经明确：没有一个免费开源 Unity steering / local avoidance 插件能完整覆盖 FantasyWord 的目标。

- UnitySteer 行为库成熟、MIT、2D/3D 示例完整，但年代较早，作者流程偏 Prefab 组件堆叠，缺共享检测帧、现代 profile 入口和可解释调试面板。
- N:ORCA / RVO 适合局部避让后端，但不是完整 steering 行为系统。
- friedforfun ContextSteering 架构好，但 MPL-2.0 不适合复制实现。
- SunnyValley / AkiSteer 适合 2D context steering 和可视化参考，但不是插件质量上限。
- duolafashi 提供了基于 SunnyValley 骨架扩展出的真实业务 steering 实现，可作为行为编排与业务行为参考，但不能直接作为 Unity 插件架构、ORCA 或推挤算法基线。

因此正式方向收敛为：自研通用 `ContextSteering2D` 插件，但不是从零拍脑袋写，而是按职责整合各参考的最佳实践，并把 UnitySteer 作为传统 steering 行为能力最低基线。

## Scope

本 change 建立 `ContextSteering2D` 插件规格与第一期实现边界：

- 基于已完成深搜裁决：不直接导入任何单一插件作为最终 owner，改为整合最佳实践实现通用 `ContextSteering2D`。
- 重构或替换 `FantasyWordSteering`，最终对外使用通用命名，不继续扩展 `FantasyWord.Steering` 私有插件。
- 以 UnitySteer 作为传统 steering 行为基线，第一阶段实现若覆盖范围小于 UnitySteer，必须明确标注为竖切，不得宣称完整插件完成。
- 建立 FantasyWord GameCore 接入边界：GameCore 负责目标、阵营、攻击触发和移动执行；steering 插件负责移动方向、避障、分离、局部避让和调试解释。
- 建立检测复用策略：同一 tick 的目标、障碍、邻居、身体参数查询应能被 steering、局部避让和战斗预检复用，避免每个系统重复扫场景。
- 建立编辑器可视化：至少能看到目标方向、行为贡献、最终方向、邻居/障碍和局部避让修正。
- 保留 ORCA/RVO 后端接口，不把小规模 separation 冒充大规模 crowd simulation。

## Current Verdict

当前裁决是：**没有单一现成插件胜出，正式 owner 是新的通用 `ContextSteering2D`，实现方式是整合参考最佳实践**。

本裁决已经从“仓库/README 对比”提升到职责核心源码对比：

- UnitySteer / unity-movement-ai：传统行为、速度/加速度输出、Arrive、预测碰撞避让、Radar/分频检测和移动执行。
- friedforfun ContextSteering：行为图、危险遮罩、图合成策略、方向选择策略、输出强度和逐行为可视化。
- SunnyValley / AkiSteer：interest/danger 写入、求解顺序、运行时 Gizmos 和作者理解成本。
- N:ORCA / N:Beacon.ORCA / pk1234 ORCA / RVO2-CS：集中式 agent registry、preferred velocity、collision-free velocity、障碍注册和批量 simulation step。
- duolafashi：原始 `.ts` 不在当前工程目录，但 `tsconfig.tsbuildinfo`、source map 原始模块路径和可读编译 JS 完整暴露了业务层 steering 实现。其结构明显延续 SunnyValley，并增加追击预测、绕目标游走、友军侧让、一次检测分类障碍/友军，以及按 AI 状态选择行为组合。

因此，“整合最佳实践”不再表示拼接多个项目的实现片段，而是按职责裁成一条唯一运行链。当前竖切代码只证明方向采样、基础行为、共享帧雏形和轻量推挤可运行；它不是最终接口设计，也不能标成插件完成态。

第一期 owner 调整为：

- **插件总体入口**：`ContextSteering2D` 是唯一正式 owner，不再保留 `FantasyWordSteering` 作为并行系统。
- **唯一角色作者入口**：一个 `ContextSteeringProfile2D` 资产拥有采样配置、一个或多个命名行为组、图合成策略、方向选择策略和局部避让参与参数；每个行为组内部是有序行为栈。角色不挂一组行为组件，也不建立每个行为一份并行作者真相。世界级局部避让后端不由单个角色 Profile 选择。
- **行为运行层**：行为按 Profile 顺序读取同一份检测帧，并输出各自独立、可追踪的贡献图或约束图；求解器不得硬编码行为数组，也不得只保留每个方向数值最大的来源。
- **方向决策层**：图合成与方向选择是独立策略。输出必须保留方向强度或期望速度，不能只返回单位方向，否则 Arrive、制动、速度匹配和 ORCA preferred velocity 无法正确表达。
- **共享检测层**：每个 simulation tick 生成可复用检测帧，区分目标、障碍、邻居和身体数据；目标选择、攻击预检、行为求解与局部避让在可行时读取同一份快照。
- **局部避让层**：局部避让是世界级集中式或批量 simulation 后端，输入每个 agent 的 authoritative position、current velocity、preferred velocity 和参与参数，输出 collision-free velocity；后端不能直接移动 Transform/Rigidbody。普通 Separation 是行为，重叠 Push Resolve 是最终穿透修正，二者都不能冒充 ORCA。
- **调试层**：生成不可变调试快照，保留逐行为贡献、合成结果、选中方向、preferred velocity、避让后速度和推挤修正；SceneView 只能有一个正式绘制入口。
- **FantasyWord 接入**：GameCore 只提供目标、阵营、攻击、身体参数、当前 steering mode 和移动执行，通过正式 adapter 注册 agent、按稳定 ID 选择 Profile 内的行为组、提交语义输入并读取移动结果，不直接创建插件内部求解器和检测器。
- **全局路线边界**：`TerrainNavigationMap` 继续是坡道、悬崖、桥洞和跨层路线的唯一 owner；GameCore 把当前航点提交给 steering。`ContextSteering2D` 不得绕过全局路线直接把最终目标当作可直达点，也不得反向修改 Tilemap 导航图。
- **航点到达语义**：中间航点使用不含 Arrive 的 path-follow 行为组，并通过安全到达半径切换下一航点；只有最终目标启用 Arrive。不得让角色在每个 Tilemap 转折点完整减速，也不得为消除减速而直接切角穿过不可行走格。

## Final Runtime Flow

1. GameCore 从 `TerrainNavigationMap` 获得全局路线，并由 adapter 为当前 tick 提交 agent 身体数据、当前航点和游戏语义。
2. `ContextSteering2D` 统一建立共享检测帧，复用邻居和障碍查询结果。
3. GameCore 选择 Profile 内当前命名行为组；该组的有序行为栈逐项计算独立贡献图/约束图。
4. Context combinator 合成行为与约束，direction selector 产出方向和强度。
5. 求解结果转换为 preferred velocity，而不是丢失速度信息的单位方向。
6. 世界 simulation 当前启用的唯一局部避让后端按固定模拟步长批量计算 collision-free velocity；不同角色可以有不同参与参数，但不能各自选择互不一致的后端或时钟。
7. 可选 overlap/push resolver 只处理已经发生的穿透和质量/优先级推挤。
8. GameCore adapter 接收最终速度/方向，执行角色移动、朝向和动画。
9. 同一次计算产生不可变 debug snapshot，供 Inspector、SceneView 和测试读取。

## Reference Verdict

本 change 采用“多参考分职责吸收”，但每个职责必须只有一个正式 owner，不能形成多套作者入口或多套运行时真相。

| 职责 | 候选来源 | 正式 owner | 本次吸收什么 | 本次明确不吸收什么 | 验证入口 |
|------|----------|------------|--------------|--------------------|----------|
| 插件总体 owner | UnitySteer、N:ORCA、friedforfun、SunnyValley、AkiSteer、duolafashi、当前 FantasyWordSteering | `ContextSteering2D` | 按职责整合最佳实践，形成单一通用插件入口 | 不直接导入任何单一插件作为最终 owner；不保留多套同职责入口 | Unity 编译、移动测试场景、SceneView 调试 |
| 行为目录和 steering 算法 | UnitySteer、unity-movement-ai | `ContextSteering2D` Profile 有序行为栈 | 传统行为目录、速度/加速度语义、Arrive/预测避让正确合同 | 不照搬 GameObject 行为组件堆；不把所有行为参数继续平铺进一个无限增长的面板 | 行为合同测试、Profile 作者流程 |
| Context 数据和方向决策 | friedforfun ContextSteering、SunnyValley、AkiSteer | `ContextSteering2D` contribution/combinator/selector | 独立行为图、约束图、合成策略、方向选择、强度保留、逐行为调试 | 不复制 MPL-2.0 代码；不使用“只记最大来源”的伪贡献记录 | 求解器合同测试、SceneView 分层调试 |
| 局部避让 / ORCA 后端 | N:ORCA、N:Beacon.ORCA、pk1234 ORCA、RVO2-CS | `ContextSteering2D` 集中式 simulation 后端 | agent registry、preferred velocity、safe velocity、批量 step、静态/动态障碍、后端替换 | 不继续使用每个 AIController 私有实例作为最终后端合同；不把 Separation/Push 称为 ORCA | 后端替换测试、批量场景基准 |
| FantasyWord 行为编排 | duolafashi 业务实现、当前移动/战斗场景 | GameCore mode 选择 + Profile 命名行为组 | Chase=Avoid+Pursuit+Separation、Orbit=Avoid+Around、Sprint=Pursuit 的状态化组合；追击预测；友军侧让；一次检测分类 | 不复制编译 JS；不保留业务类名；不把其近似 VO、随机侧选或固定八方向当算法上限 | 行为组切换合同测试、端到端场景 |
| 编辑器可视化 | UnitySteer Gizmos、AkiSteer、SunnyValley | `ContextSteering2D.Editor` | Gizmos、方向权重、邻居/障碍/最终方向显示 | 不只做临时 `OnDrawGizmos`；不把 GameCore 当调试 owner | SceneView/Inspector 截图 |

## Expected Outcome

完成后，FantasyWord 不再维护项目私有的 `FantasyWordSteering` 算法堆，也不保留当前“AIController 私有求解器 + 私有检测器”的最终结构。最终方案是一个通用 `ContextSteering2D` 插件：一个 Profile 作者入口、一条共享检测与求解链、一个可批量替换的局部避让后端入口、一份可解释调试快照；GameCore 只通过 adapter 提供游戏语义并执行结果。

## Risks

- UnitySteer 免费且成熟，但年代较早；直接导入并不等于最佳实践，当前只作为行为基线和移植参考。
- friedforfun ContextSteering 架构很强，但 MPL-2.0 不适合复制代码，只能参考设计。
- N:ORCA 很适合作 ORCA 后端候选，但依赖 Burst/Collections/Jobs 和 Nebukam 子依赖，不进入第一期默认依赖。
- 如果自研 `ContextSteering2D` 行为覆盖和调试能力低于参考基线，必须称为阶段竖切，不能宣称插件完成。
- 当前轻量后端可以继续作为第一实现，但现有逐 agent `Resolve(frame, profile)` 接口不能承载集中式 ORCA/RVO，必须先重构后端合同再扩展功能。
- Profile 行为栈的编辑器必须保持一个资产入口；实现可采用内嵌序列化条目或子资产，但不能把参考项目的 MonoBehaviour 组件堆重新引入正式作者流程。
