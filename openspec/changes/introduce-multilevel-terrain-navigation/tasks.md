# Tasks: introduce-multilevel-terrain-navigation

## 1. Preconditions And Compatibility

- [ ] 完成 `implement-realtime-terrain-navigation` 的单层坡道 EditMode 和场景验证
- [ ] 审计当前玩家/NPC 移动 Collider2D、Rigidbody2D、Hitbox 与 Interaction 层级
- [ ] 审计当前 Y 排序、SortingGroup 和角色渲染入口
- [ ] 确认 `implement-element-reaction-foundation` 使用可带默认层的 `TerrainNodeKey`
- [ ] 记录当前第三方二维 A* 的正式退场条件

## 2. Node Identity And Layer Sources

- [ ] 新增稳定 `TerrainLayerId`
- [x] 新增 `TerrainNodeKey = Cell + LayerId`
- [x] 新增 `TerrainNavigationLayerSource`
- [x] 将当前 `m_ruleTilemap` 迁移为默认层来源并保留序列化兼容
- [ ] 验证同格不同层节点、重复 LayerId 和重复节点会明确处理

## 3. Sparse Navigation Graph

- [ ] 新增 `TerrainNavigationGraph`
- [ ] 从多个规则 Tilemap 构建稀疏节点
- [ ] 生成同层正交边和动态代价
- [ ] 新增项目侧图 A*，不修改第三方插件源码
- [ ] 验证默认层路线与当前二维路线结果一致
- [ ] 多层图稳定后移除正式运行时对二维 cost map 的依赖

## 4. Explicit Layer Transitions

- [ ] 新增 `TerrainTransitionLink`
- [ ] 支持 Ramp、Stairs、Ladder 和 Drop 类型合同
- [ ] 保存双向/单向、附加代价、世界路径点和切层提交点
- [ ] 将当前坡道方向与中心线路径迁移到链接校验
- [ ] 验证不存在端点、方向冲突和重复连接会明确失败

## 5. Destination Resolution And Debugging

- [ ] 新增 `TerrainDestinationResolver`
- [ ] 支持选择遮罩、当前层和可达性裁决
- [ ] 多候选仍歧义时拒绝命令，不固定选择最高或最低层
- [ ] Scene Gizmos 绘制节点层、候选目标、最终目标、路径和切层点
- [ ] 多单位命令首批按单位当前层分别解析

## 6. Entity Layer, Collision And Rendering

- [ ] 新增 `TerrainLayerState`
- [ ] 新增 `TerrainCollisionBandConfig`
- [ ] 在 TagManager 中只配置首批所需的少量可复用 TerrainBand
- [ ] 将移动地形碰撞代理与 Hitbox/Interaction 层职责分离
- [ ] 在过渡提交点原子切换逻辑层、碰撞带和表现带
- [ ] 使用 PresentationBand + 同层 Y Sort 更新正式角色表现入口
- [ ] 验证桥面护栏不阻挡桥洞实体，桥洞碰撞不影响桥面实体

## 7. Element And Surface Migration

- [ ] 将运行时地表状态键迁移为 `TerrainNodeKey`
- [ ] 扩展 `TerrainSurfaceSample` 返回节点层身份
- [ ] 元素范围沿导航图合法边展开
- [ ] 同格不同层不得自动传播元素状态
- [ ] 验证桥面 Burning/Wet/ScorchedDirt 不影响桥洞
- [ ] 默认层地图保持现有元素地表语义

## 8. Persistence And Recovery

- [ ] 角色位置存档增加 `TerrainLayerId`
- [ ] 检查点明确目标地形层
- [ ] 读档时同时校验世界坐标和地形层
- [ ] 无效或缺失层时回退明确检查点，不从画面排序猜层
- [ ] 首批不保存过渡中进度，但必须阻止保存出不可恢复状态

## 9. Bridge Vertical Slice In ClickMoveTest

- [ ] 在现有 `ClickMoveTest` Grid 内搭建桥洞验证区
- [ ] 增加地面规则层、桥面规则层和左右过渡链接
- [ ] 增加地面/桥面碰撞带与桥前景遮挡层
- [ ] 地面到地面路线从桥洞穿过
- [ ] 地面到桥面路线通过左坡
- [ ] 桥面到地面路线通过右坡
- [ ] 同一投影位置的点击目标解析可解释且稳定
- [ ] 桥面和桥洞地表状态彼此独立

## 10. Verification

- [ ] 补节点身份、图邻接、跨层链接和目标解析合同测试
  - [x] 已补默认层来源兼容测试：空来源继续使用旧 `m_ruleTilemap`，配置默认层来源时优先使用 `TerrainNavigationLayerSource`
- [ ] 补碰撞带与层切换状态合同测试
- [ ] 补桥面/桥洞地表隔离测试
- [ ] 运行 Unity 编译与相关 EditMode 测试
- [ ] 在 `ClickMoveTest` 完成连续移动、碰撞和遮挡验收
- [ ] 检查 Console、序列化引用和场景 dirty 状态
- [ ] 按用户后续指令决定是否执行端到端截图
- [ ] 运行 `npx openspec validate introduce-multilevel-terrain-navigation --strict`
