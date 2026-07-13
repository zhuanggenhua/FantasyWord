# Tasks: implement-persistent-world-terrain-mutation

## 1. Scope Lock

- [ ] 确认作者底层地表 Tilemap、草覆盖/植被层、玩家改写层和表现层的职责边界
- [ ] 确认首批只做“火烧毁草覆盖层、露出底层土壤、草层可再生”的持久化，不扩大到完整体素/建造系统

## 2. World Terrain Mutation Data

- [ ] 新增按 `TerrainNodeKey` 存储的地形变更数据结构
- [ ] 保存底层地表、覆盖层类型、覆盖层状态、再生剩余时间、变更类型、来源和版本
- [ ] 明确临时状态 Burning/Wet/Oiled/Electrified、持久草层缺失和草层再生进度的保存差异

## 3. Runtime Composition

- [ ] 让地形查询从“作者底层地表 + 初始草覆盖 + 玩家改写层”合成当前世界格状态
- [ ] 让元素反应读取合成后的当前覆盖状态，而不是只读 `EffectiveSurface`
- [ ] 让导航代价读取合成后的当前世界格状态
- [ ] 让表现层只消费当前世界格状态，不拥有保存数据

## 4. Save And Load

- [ ] 保存玩家地形改写层
- [ ] 加载同一世界时恢复玩家地形改写层
- [ ] 卸载/重载地图时不丢失已保存的草层缺失和再生进度

## 5. Flamethrower Persistence Slice

- [ ] 喷火烧草后写入草覆盖层移除和再生进度
- [ ] 保存并重载后仍隐藏草覆盖层，显示底层土壤
- [ ] 重载后未再生草层的格子不再按有草覆盖可燃
- [ ] 作者模板 Tilemap 文件不被 PlayMode 改写

## 6. Verification

- [ ] 补合同测试覆盖保存、加载和查询合成
- [ ] 在 `ClickMoveTest` 完成真实 PlayMode 闭环
- [ ] 验证技能、Cue 和表现层没有直接写死草层销毁、露土、再生或保存逻辑
