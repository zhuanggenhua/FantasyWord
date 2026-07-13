# Tasks: introduce-water-surface-reflection

## 1. Preconditions

- [ ] 确认 `ClickMoveTest` 中正式水层、岸线障碍和角色游泳动画入口
- [x] 确认当前 xBRZ Renderer Feature 对运行时 RenderTexture 相机的影响
- [x] 确认当前 Sorting Layer、Layer、Renderer2DData 和主相机配置
- [ ] 确认可倒影对象的首批 Layer/Sorting Layer 归属
- [ ] 确认移动端目标质量档和默认倒影分辨率预算
- [x] 在树木、建筑和玩家上锁定脚底锚点、垂直压缩与 45 度偏斜参数
- [x] 审计 EquipmentUV 主体 Renderer 和动态武器 Renderer 的正式同步入口

## 2. Water Area State

- [ ] 新增或收口正式水域状态入口
- [ ] 明确水默认可游泳
- [ ] 将岸线、石头、悬崖和地图边界从水域规则中拆成独立障碍
- [ ] 提供角色是否在水中、是否游泳、是否参与普通倒影的查询
- [ ] 验证倒影、游泳和后续涟漪消费同一水域状态入口

## 3. Reflection Mask

- [x] 定义水像素 Mask 作者来源
- [x] 避免直接把 `LakeGrass` 这类草岸混合瓦片整体作为水 Mask
- [x] 在 `ClickMoveTest` 为当前水面准备可验证 Mask
- [x] 缺 Mask 时显式关闭倒影或进入调试状态

## 4. Reflection Caster And Proxy

- [x] 新增 WaterReflectionCaster2D
- [x] 支持序列化源 Renderer 和正式 Renderer 提供者
- [x] 为每个源 SpriteRenderer 管理一个 Reflection Proxy
- [x] Proxy 围绕脚底锚点完成翻转、垂直压缩和 45 度偏斜
- [x] 只在 Sprite、flip、color、enabled、材质或 Renderer 集合变化时同步
- [x] 为 EquipmentRenderer 增加非分配 Renderer 快照或变更事件
- [ ] 验证玩家主体换装和当前武器都进入 Proxy 组
- [x] 游泳中角色可以关闭完整 Proxy

## 5. Scene Reflection System And Shared Capture

- [x] 新增场景级 WaterReflectionSystem，不创建跨场景玩法单例
- [x] Caster 通过 OnEnable/OnDisable 显式注册和注销
- [x] 新增 WaterReflectionProxy Unity Layer，主相机排除该 Layer
- [x] 新增一台共享正交捕获相机
- [x] 新增低分辨率 RenderTexture 配置
- [x] 捕获相机只渲染 WaterReflectionProxy Layer
- [x] 为捕获相机配置独立 Renderer2D，不启用 xBRZ 和无关后处理
- [x] 排除 UI、地表、水 Tilemap 和无关特效
- [x] 验证岸边对象能在水面出现像素风倒影
- [x] 验证不为每块水域创建独立相机
- [x] 验证不为每个对象创建 RenderTexture

## 6. Spatial Culling And Distance Tiers

- [x] 建立当前可见水域的粗 Bounds 或水格索引
- [x] 计算 Caster 潜在反射 AABB
- [x] 只启用与可见水域粗范围相交的 Proxy
- [x] 定义 Near/Mid/Far/Off 阈值和默认参数
- [x] 近景保留完整 Proxy
- [x] 中景降低 Proxy alpha、长度或增加垂直压缩
- [x] 远景关闭 Proxy，不进入共享捕获
- [ ] 低端质量档关闭或降到 0.25 分辨率
- [x] 不向水材质上传全部对象位置数组
- [ ] 记录不同质量档的 CPU、draw call、RT 和 GPU 时间成本

## 7. Water Material Composition

- [x] 新增或改造水面合成材质
- [x] 保留动画水基础帧
- [x] 使用水 Mask 裁剪倒影
- [x] 增加像素风 UV 扰动、压暗和透明混合
- [x] 使用边缘衰减限制 UV 扰动，避免水面边界穿帮
- [x] 按距离/质量档淡出倒影
- [x] 确保材质不负责游泳身体遮罩
- [x] 确保材质只消费共享 RT、水 Mask 和水域自身参数
- [x] 验证 LakeGrass 草岸像素不会显示倒影

## 8. Swimming Reflection Policy

- [ ] 游泳中的玩家从完整站立倒影中排除
- [ ] 可选实现极弱上半身波动影
- [ ] 入水/出水过渡时倒影淡入淡出
- [ ] 验证现有游泳动画仍由角色表现系统负责

## 9. Verification

- [x] 运行 OpenSpec 严格校验
- [x] 完成 `ClickMoveTest` 近景倒影视觉验收
- [ ] 完成树木/建筑 45 度倒影无明显底部穿帮验收
- [ ] 完成玩家主体换装和武器倒影完整性验收
- [ ] 完成玩家游泳中无完整站立倒影验收
- [ ] 完成中远景倒影弱化/关闭验收
- [ ] 完成低端质量档关闭动态倒影验收
- [ ] 用 Frame Debugger 验证只有一台共享捕获相机和一张共享 RT
- [ ] 用 Profiler 记录启用 Proxy 数、额外 draw call、CPU 和 GPU 成本
- [ ] 检查 Console、材质引用、Renderer2DData、场景 dirty 状态
- [ ] 按用户后续要求决定是否截图或录屏

## 10. Optional Renderer Feature Evaluation

- [ ] 只有共享相机被性能数据证明为瓶颈时才创建 Renderer Feature 对照原型
- [ ] 对照原型不得改变 Caster、Proxy、Mask 和水材质合同
- [ ] 对比共享相机与 Renderer Feature 的 GPU、CPU、内存、xBRZ 隔离和维护成本
- [ ] 没有明确净收益时保留共享相机正式实现
