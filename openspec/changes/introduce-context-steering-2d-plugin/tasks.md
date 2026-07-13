# Tasks: introduce-context-steering-2d-plugin

## 1. Proposal And Reference Lock

- [x] 锁定问题对象、真相来源、目标入口/环境和验收口径。
- [x] 读取 SunnyValley Context Steering 源码并裁决其职责。
- [x] 读取 duolafashi 转向行为编译产物并裁决其职责。
- [x] 深搜 Unity steering / local avoidance 免费开源候选。
- [x] 深读 UnitySteer 源码、README、License、CHANGELOG 和示例仓库。
- [x] 裁决没有单一免费插件完整胜出，正式 owner 为 `ContextSteering2D`。
- [x] 将 proposal、design、references 改为“整合最佳实践，每个职责单一 owner”。
- [x] 运行 `npx openspec validate introduce-context-steering-2d-plugin --strict`。

## 2. Best-Practice Architecture Gate

- [x] 建立 UnitySteer 行为基线清单：point/seek、arrive、path、wander、pursuit/evasion、separation、cohesion、alignment、obstacle avoidance。
- [x] 建立 context steering 结构基线：interest/danger、direction picker、context combinator、debug value。
- [x] 建立 ORCA/RVO 后端边界，并裁决 Apache-2.0 RVO2 为正式默认后端。
- [x] 源码级复核 friedforfun 的 behaviour/mask/combinator/selector 分层，并确认当前单数组最大值结构不足。
- [x] 源码级复核 unity-movement-ai 的 Arrive、CollisionAvoidance、Separation、WallAvoidance 和速度/加速度合同。
- [x] 源码级复核 N:ORCA、N:Beacon.ORCA、pk1234 ORCA、RVO2-CS 的 agent registry、preferred velocity 和 batch simulation 合同。
- [x] 源码级复核 warmtrue/RVO2-Unity 的动态 Agent、Unity 接入与旧单例/线程风险。
- [x] 源码级复核 Position-Based Crowd Simulation 的 hash grid、短程/长程约束、逆质量和 Jacobi 迭代。
- [x] 源码级复核 Unity DOTS RTS Collision 与 LockstepRTSEngine 的空间分区和碰撞对；只吸收有效结构，不复制有缺口解析。
- [x] 复核 ORCA/RVO 调度、位置积分、障碍注册和非对称避让责任，裁决后端与时钟归世界 simulation，角色 Profile 只保留参与参数。
- [x] 从用户给定 duolafashi 的 tsbuild/source map 定位原始模块，并读取编译 JS 中的 SteeringBehavior、四类行为、ContextSolver、Detector、EnemyAI 和行为树调用。
- [ ] 可选做 UnitySteer isolated import compile 原型，用于风险验证和行为对照，不作为正式 owner 切换前提。

## 3. Existing Vertical Slice

- [x] 建立 `Assets/Plugins/ContextSteering2D` 可运行竖切，验证方向采样、基础行为、共享检测帧雏形和轻量 push resolve。
- [x] 保留 MIT attribution 记录：凡直接移植 UnitySteer 代码必须保留许可证说明；只吸收设计时也要在 references 标明来源。
- [x] 实现 `SteeringDetectionFrame2D` 数据模型和非分配 Physics2D 查询缓冲。
- [x] 实现轻量 push resolve 竖切，并明确不是 ORCA/RVO。
- [x] 删除轻量逐 Agent 避让/推挤竖切，替换为正式 RVO2 批量后端和 PBD 接触阶段。
- [x] 注册单位邻居查询改为世界级空间索引；Physics2D 只查询外部障碍和语义 Collider。
- [x] Arrival 改为纯速度约束，默认组不得重复叠加目标兴趣。
- [x] 删除无运行语义的行为 Up/Down UI；如果未来实现 priority combinator 再恢复顺序编辑。
- [x] 每固定步提交真实角色最高速度，RVO 预测速度单位必须与 GameCore 实际移动一致。
- [x] 第一阶段明确标注行为覆盖范围，不能把 seek + avoid + separation 冒充完整 steering 插件完成态。

## 4. Required Runtime Refactor

- [x] 新增场景/世界级 simulation owner，统一 agent 注册、tick、检测、行为求解、局部避让和结果发布。
- [x] 新增正式 GameCore adapter；`AIController.BehaviourRuntime` 不再私有创建 solver/scheduler。
- [x] 将 `ContextSteeringProfile2D` 重构为单一作者入口下的多个命名行为组；每组拥有稳定 ID 和有序行为栈，行为拥有专属参数；删除求解器硬编码行为数组。
- [x] 将全局 interest/danger 最大值写入改为逐行为 contribution/constraint maps。
- [x] 拆分 context combinator 与 direction selector，并通过合同测试验证替换能力。
- [x] 将求解输出从单位方向升级为 preferred velocity 或方向 + speed scale。
- [x] 按正确速度合同重做 Arrive；当前“目标方向写 danger”实现不得保留为正式 Arrive。
- [x] 将普通 Seek、预测 Pursuit、Orbit/Strafe 和友军 Side-step 分成独立通用行为，不复制 duolafashi 的业务类名和可疑近似 VO 实现。
- [x] GameCore 可按业务状态选择 Profile 行为组，插件不拥有 Chase/Orbit/Sprint 的游戏语义。
- [x] 将局部避让接口升级为 world-level batch simulation 后端；轻量后端和未来 ORCA/RVO 使用同一上层结果合同，且只输出安全速度、不直接移动角色。
- [x] 将 Separation、预测 local avoidance、overlap/push resolve 明确拆成三个阶段。
- [x] 区分 obstacle filter 与 neighbour filter，并记录目标/视线/攻击预检仍无法复用的查询成本。
  - [x] `GameConfig` 已将地形/墙体阻挡过滤与 `Character` 邻居/目标过滤拆开，GameCore adapter 不再向两个职责传同一份过滤配置。
  - [x] 世界注册只登记归属于角色主 `Rigidbody2D` 的移动碰撞体，独立 Hitbox 刚体不会再被识别成自身邻居。
  - [x] 目标候选复用 steering 同 tick 的语义检测结果；视线和攻击遮挡仍需独立射线，不能冒充已合并进 broadphase。

## 5. Editor And Debugging

- [x] 生成不可变 debug snapshot，保留每个行为的 contribution、constraint、合成结果、preferred velocity、safe velocity 和 push correction。
- [x] SceneView 只保留一个正式绘制 owner，移除 Gizmos/Handles 重复绘制。
- [x] 实现按行为来源分层开关的 SceneView 调试。
- [x] 实现 Inspector 调试：当前 adapter/profile、行为栈、检测快照摘要和分阶段输出。
  - [x] Profile Inspector 可编辑命名行为组与有序行为栈，Probe Inspector 可查看检测摘要和 preferred/safe/push 分阶段输出。
  - [x] Probe Inspector 明确显示当前 Profile 与当前行为组，不让使用者跨两个面板自行拼接运行状态。
- [x] 实现真正 isolated preview，执行与运行时相同的 behaviour/combinator/selector；当前只画半径和采样线的 Preview 不算完成。
- [x] 调试入口必须由 `ContextSteering2D.Editor` 或 adapter/editor 层提供，不能写成 GameCore 临时 Gizmos。

## 6. FantasyWord Integration

- [x] 将 `AIController.BehaviourRuntime` 的直接 solver/scheduler 调用替换为正式 adapter。
- [x] 将 AI 的最终目标先交给 `TerrainNavigationMap` 生成全局路线，再把当前航点提交给 adapter；steering 不得直接穿越悬崖、坡道边界或桥洞层级。
- [x] 为全局路线增加 `path-follow` 行为组：中间航点不启用 Arrive，最终目标切回带 Arrive 的组。
  - [ ] 运行态验证转折点不停车且不会切角穿越阻挡格。
  - [ ] NPC 接入自身 `TerrainLayerState` 后再验收桥洞与跨层追逐；当前默认层调用不能冒充完整多层 NPC 导航。
- [x] GameCore 只保留目标选择、阵营过滤、攻击触发、身体参数和移动执行。
- [x] 目标选择、攻击预检、steering、局部避让在可行范围内复用同一份 tick frame；无法复用的视线查询需显式记录。
- [x] 移除 `FantasyWord.Steering` asmdef 引用。
- [x] 旧 `Assets/Plugins/FantasyWordSteering` 删除或保留为未接入参考时，必须写清退出条件。

## 7. Verification

- [x] 重构后 Unity 编译无错误。
- [x] 静态搜索确认 GameCore 不直接创建 steering solver/detection scheduler，不持有算法数组。
- [x] 行为栈、combinator、selector、preferred velocity 和 backend replacement 有合同测试。
- [x] 检测复用测试能证明同一 tick 没有重复 broadphase，或明确列出剩余查询。
- [x] 移动测试场景中 NPC 可追敌、Arrive 减速、避障、分离和 push resolve。
- [x] 两个以上 NPC 接近时能区分 behaviour separation、safe velocity 和 penetration push。
- [x] 选中 NPC 时能在原生 SceneView 看到逐行为调试，且不存在重复绘制。
- [x] 截图、测试日志或 Unity Console 记录作为重构后验收证据。
- [ ] 后续自判通过后，必须先给用户看最终截图；用户看图认可后才进入用户自测。
- [x] 完成 100/500/1000 Agent 性能基准，记录 RVO2、PBD、检测和总 fixed-step 成本；不得用空场景或纯数学循环冒充真 Agent 规模。

### 2026-07-13 Runtime, Screenshot And Performance Evidence

- `ContextSteering2DEditModeTests` 当前 26 个唯一用例全部通过，包含 per-intent Arrive 停止半径、即时 debug snapshot 发布、瞬时 push 峰值保留、RVO2、PBD、空间索引、真实速度和角色碰撞 owner 合同。
- `Temp/UnityBridge/results/clickmove-context-steering-runtime.json` 的 strict fresh run 通过：2 个 Agent、2 个 Probe、邻居数 1、首对快照距离 0.25、最大穿透 0.45，并观察到 `transit`、`predictive-target`、Arrive、preferred velocity、safe velocity、RVO 修正、Separation 和 PBD push。
- `ClickMoveTest` 的两个训练假人场景实例启用 `Persistable.m_forceNoPersistence`，避免旧存档位置覆盖测试场景作者坐标；Prefab 与其他场景对象保持原持久化规则。
- `Assets/Screenshots/context-steering-final-sceneview-v7.png` 是最终 SceneView 验收图：选中真实 NPC，显示 Context Map、目标/邻居、Preferred、Safe、行为图例；PureRef 已打开给用户，预览站已发布到 `http://8.148.71.102:18080/#/fantasyword/context-steering-2d-plugin`。
- `Temp/UnityBridge/results/context-steering-performance-benchmark.json` 使用真实 `GameObject + Rigidbody2D + CircleCollider2D + AgentHandle` 密集阵型测得：100 Agent 平均 5.47ms / P95 5.78ms，500 Agent 平均 29.51ms / P95 31.22ms，1000 Agent 平均 64.19ms / P95 71.06ms；采样阶段托管分配均为 0 B。
- 1000 Agent 分阶段平均成本：检测 19.41ms、steering 20.19ms、RVO2 3.44ms、PBD 13.98ms。当前实现不满足 500/1000 Agent 的 50Hz 全量 fixed-step，后续优化优先级应为 steering/检测分频与 LOD，其次是 PBD Job/Burst；不能把当前结果描述成全面战争规模已达标。

### 2026-07-13 Architecture Review And Detection Fix

- 已确认总体 owner 边界继续成立，但补充硬边界：`TerrainNavigationMap` 负责跨坡道、悬崖和桥洞的全局路线，`ContextSteering2D` 只消费当前航点并输出局部速度。
- 修复角色注册把独立 Hitbox `Rigidbody2D` 误登记为自身邻居的问题；现在只登记 `Collider2D.attachedRigidbody == 角色主 Rigidbody2D` 的移动碰撞体，并在检测阶段再次排除自身 handle。
- `GameConfig` 新增独立 `Character` 邻居/目标过滤，GameCore adapter 不再把地形阻挡过滤同时当邻居过滤。
- Unity 在 2026-07-13 08:05 重新生成 `ContextSteering2D.Runtime.dll`、`FantasyWord.GameCore.dll` 和 `FantasyWord.GameCore.EditModeTests.dll`。
- `ContextSteering2DEditModeTests` 专项测试 10 项全部通过，包含配置过滤、自身 Hitbox 隔离、Arrive、逐行为贡献、批量局部避让、推挤和 Simulation 不直接移动 Rigidbody 的合同。

### 2026-07-12 Vertical Slice Evidence

- `ContextSteeringDebugProbe2D` 已接到 `Assets/Prefabs/Entities/Characters/Enemies/测试-训练假人.prefab`，Prefab YAML 中可见脚本 GUID `545708aaeaf6c9a418d0f58df5fdc2c5`、`m_drawSceneGizmos: 1`、`m_onlyDrawWhenSelected: 1`。
- Unity Editor 日志显示脚本编译成功：`Tundra build success`，未见 `ContextSteering2D` / `ContextSteeringDebugProbe2D` 相关编译错误。
- UnityBridge 验证结果 `Temp/UnityBridge/results/context-steering-debug-probe-attach-20260712185156541.json`：训练假人 prefab 已有调试探针；2 个邻居输入时 `syntheticHasPushCorrection=true`，输出推挤修正 `(-0.223, -0.001)`。
- UnityBridge 验证结果 `Temp/UnityBridge/results/context-steering-scene-validate-20260712185245050.json`：打开 `Assets/Scenes/ClickMoveTest.unity` 后确认 prefab 有探针、探针可捕获快照、快照内邻居数为 2、分离来源方向数为 9、推挤修正存在。
- 当前证据只证明竖切求解器、调试探针和轻量 push resolve 可运行；它不证明最终 adapter、共享检测复用、批量后端、真实 isolated preview 或逐行为调试已经完成。
- 旧截图 `Assets/Screenshots/ContextSteering2D/context-steering-real-sceneview-debug.png` 只能证明有调试线，不能作为最终验收图；它缺少图例、分层和可读的位置关系。
- 错误截图 `Assets/Screenshots/ContextSteering2D/context-steering-debug-sceneview-handles.png` 捕获到了非 Unity SceneView 窗口，不得作为证据。
- 调试可读性候选图 `test-results/evidence-image-validation/context-steering-2d-debug/context-steering-readable-verdict-v3.png` 来自 Play Mode 的 `ContextSteeringDebugProbe2D` 快照，能读出训练假人、玩家目标、障碍、邻近单位、16 方向采样和最终方向；该图是验收解释图，不是原生 SceneView 截屏。
- 推挤解析候选图 `test-results/evidence-image-validation/context-steering-2d-debug/context-steering-push-verdict.png` 基于 Play Mode 快照构造重叠邻居帧，输出 `Push=(-0.163,-0.064)`，证明轻量 push resolve 在重叠条件下会给出非零分离修正；普通邻居检测不等于推挤。
- 最终用户验收仍以用户看图认可为准；在用户认可前，不把截图项标成完全完成。
