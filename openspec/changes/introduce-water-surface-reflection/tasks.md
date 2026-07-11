# Tasks: introduce-water-surface-reflection

## 1. Preconditions

- [ ] 确认 `ClickMoveTest` 中正式水层、岸线障碍和角色游泳动画入口
- [ ] 确认当前 xBRZ Renderer Feature 对运行时 RenderTexture 相机的影响
- [ ] 确认当前 Sorting Layer、Layer、Renderer2DData 和主相机配置
- [ ] 确认可倒影对象的首批 Layer/Sorting Layer 归属
- [ ] 确认移动端目标质量档和默认倒影分辨率预算

## 2. Water Area State

- [ ] 新增或收口正式水域状态入口
- [ ] 明确水默认可游泳
- [ ] 将岸线、石头、悬崖和地图边界从水域规则中拆成独立障碍
- [ ] 提供角色是否在水中、是否游泳、是否参与普通倒影的查询
- [ ] 验证倒影、游泳和后续涟漪消费同一水域状态入口

## 3. Reflection Mask

- [ ] 定义水像素 Mask 作者来源
- [ ] 避免直接把 `LakeGrass` 这类草岸混合瓦片整体作为水 Mask
- [ ] 在 `ClickMoveTest` 为当前水面准备可验证 Mask
- [ ] 缺 Mask 时显式关闭倒影或进入调试状态

## 4. V0 Shared Reflection Capture

- [ ] 新增一台共享正交反射相机或等价 V0 捕获入口
- [ ] 新增低分辨率 RenderTexture 配置
- [ ] 只捕获可倒影对象层
- [ ] 排除 UI、地表、水 Tilemap 和无关特效
- [ ] 验证岸边对象能在水面出现像素风倒影
- [ ] 验证不为每块水域创建独立相机

## 5. Water Material Composition

- [ ] 新增或改造水面合成材质
- [ ] 保留动画水基础帧
- [ ] 使用水 Mask 裁剪倒影
- [ ] 增加像素风 UV 扰动、压暗和透明混合
- [ ] 按距离/质量档淡出倒影
- [ ] 确保材质不负责游泳身体遮罩

## 6. Swimming Reflection Policy

- [ ] 游泳中的玩家从完整站立倒影中排除
- [ ] 可选实现极弱上半身波动影
- [ ] 入水/出水过渡时倒影淡入淡出
- [ ] 验证现有游泳动画仍由角色表现系统负责

## 7. Distance And Quality Tiers

- [ ] 定义 Near/Mid/Far/Off 阈值和默认参数
- [ ] 近景保留清晰像素倒影
- [ ] 中景降低透明度、更新频率或细节
- [ ] 远景关闭动态倒影，保留动画水
- [ ] 低端质量档关闭或降到 0.25 分辨率
- [ ] 记录不同质量档的 GPU/帧时间成本

## 8. Formal URP 2D Integration

- [ ] 将 V0 捕获迁移或收口到正式 URP 2D 自定义渲染入口
- [ ] 使用 Render Graph 管理倒影纹理生命周期
- [ ] 隔离或跳过 xBRZ 对倒影 RT 的二次处理
- [ ] 确认 Camera Sorting Layer Texture 只作为辅助输入，不作为倒影 owner
- [ ] 用 Frame Debugger 或 Render Graph Viewer 验证 pass 顺序和纹理内容

## 9. Verification

- [ ] 运行 OpenSpec 严格校验
- [ ] 完成 `ClickMoveTest` 近景倒影视觉验收
- [ ] 完成玩家游泳中无完整站立倒影验收
- [ ] 完成中远景倒影弱化/关闭验收
- [ ] 完成低端质量档关闭动态倒影验收
- [ ] 检查 Console、材质引用、Renderer2DData、场景 dirty 状态
- [ ] 按用户后续要求决定是否截图或录屏

