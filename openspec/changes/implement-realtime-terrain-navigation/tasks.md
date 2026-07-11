# Tasks: implement-realtime-terrain-navigation

## 1. Proposal And Reference Correction

- [x] 新建并严格校验 `implement-realtime-terrain-navigation` change
- [x] 从核心路线的高低差参考中移除回合制战棋参考
- [x] 明确即时制、连续坐标、自动经过坡道的 RTS 移动语义
- [x] 吸收 Godot 楼梯运动投影思想并裁掉瓦片名与角色逐帧速度修正
- [x] 记录知乎桥洞、多高度碰撞与逻辑楼梯作为后续升级条件

## 2. Terrain Rule Authoring

- [x] 新增 `TerrainNavigationTile` 规则 Tile 资产类型
- [x] 新增 `TerrainNavigationMap` 场景地形导航组件
- [x] 让 `MapInfo` 显式引用当前场景的 `TerrainNavigationMap`
- [x] 给坡道规则增加从低层到高层的明确方向
- [ ] 在 `ClickMoveTest` 的现有 Grid 下增加规则 Tilemap
- [ ] 为低地、高台、坡道、悬崖阻挡和基础地表配置规则 Tile

## 3. Path Calculation

- [x] 将规则 Tilemap 转换成 A* cost map
- [x] 接入现有 `AStarPathfinding`，不修改第三方插件源码
- [x] 处理起点/目标最近可行走格
- [x] 将格路径转换并压缩为连续世界路径点
- [x] 将连续坡道格转换为方向明确的入口、中心和出口路径点
- [x] 补充不同坡向、双向通行和错误坡向拒绝的 EditMode 测试
- [x] 为不可达、高台坡道和悬崖阻挡补 EditMode 验证

## 4. Continuous Route Execution

- [x] 扩展 `Movable.MotionRuntime` 支持多路径点移动
- [x] 让新点击命令覆盖旧路径
- [x] 让方向输入取消点击路径
- [x] 让路径碰撞失败后停止并清理命令
- [ ] 保持现有单目标移动和相机跟随回归

## 5. Surface Query Foundation

- [x] 建立基础地表类型和运行时覆盖状态数据
- [x] 支持从世界坐标查询层级、地表与覆盖状态
- [x] 让路径代价读取基础地表配置
- [x] 验证运行时覆盖状态不会改写原始 Tile 资产

## 6. Scene And End-To-End Validation

- [ ] 在场景锁释放后运行 `TerrainNavigationMapEditModeTests`
- [ ] 在 `ClickMoveTest` 验证低地绕障碍路径
- [ ] 验证点击高台会自动经过坡道
- [ ] 验证不能从悬崖正面直接上台地
- [ ] 验证不可达目标会明确失败
- [ ] 验证连续移动、角色动画和相机跟随
- [ ] 检查 Console、场景 dirty 状态和序列化引用
- [ ] 生成轻量预览并完成真实 GameView 图面验收
- [ ] 上传最终端到端截图到任务证据服务器
- [x] 运行 `npx openspec validate implement-realtime-terrain-navigation --strict`
