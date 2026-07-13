# 2D 像素水面倒影公开实现调研

## 调研目标

本调研比较以下路线在 FantasyWord 中的适用性：

1. 每个可倒影对象创建翻转子 SpriteRenderer。
2. 每片水域建立独立相机和 RenderTexture。
3. 一台共享相机捕获反射代理。
4. URP 2D Camera Sorting Layer Texture。
5. URP Renderer Feature 或屏幕空间平面反射。

项目约束：

- Unity 6000.3.10f1，URP 2D。
- 俯视角像素开放世界，移动端需要稳定预算。
- 水面是动画 RuleTile。
- 普通水域默认可游泳。
- 玩家主体由 EquipmentUV Shader 合成装备，武器还会动态创建独立 SpriteRenderer。
- 当前 xBRZ Renderer Feature 会影响运行时 RenderTexture 相机。

## 公开实现证据

### valryon/water2d-unity

来源：https://github.com/valryon/water2d-unity

- MIT，公开仓库约 430 stars。
- WaterReflectableScript 会为每个可倒影 Sprite 创建名为 Water Reflect 的子对象。
- 子对象持有 SpriteRenderer，并在 LateUpdate 同步源 Sprite、flipX、flipY 和 color。
- 水面脚本只负责材质滚动。

可吸收：

- “对象拥有自己的反射代理”是成熟且简单的 2D 路线。
- 动画 Sprite 只需同步当前帧，不需要再渲染完整场景。

不能直接照搬：

- 实现面向 Unity 5，作者明确没有充分测试移动端。
- 只处理单 SpriteRenderer，不覆盖换装 Shader 和动态武器 Renderer。
- 没有开放世界可见性、远近质量和水域空间裁剪。

### Ymiku/2dWaterReflection

来源：https://github.com/Ymiku/2dWaterReflection

- 仓库说明提供两种 2D 水体反射实现。
- Shadow.shader 在顶点阶段做 Y 翻转、45 度方向偏移和噪声扰动。
- 使用 Stencil 只让倒影出现在水体遮罩区域。
- 对颜色做透明度降低和像素化量化。

可吸收：

- 45 度俯视角需要“绕脚底锚点翻转 + 压缩/偏斜”，不能只做普通纹理上下翻转。
- 水域最终裁剪应由水 Mask / Stencil 完成。
- 倒影可以在对象代理上先形成正确几何，再由水面做细小扰动。

不能直接照搬：

- 使用旧 Built-in RP Shader 写法。
- Stencil 和默认 Sprite Shader 的兼容需要针对 URP 2D、EquipmentUV 和 Tilemap 材质重新设计。

### CamilleChiquet/2D-Water-Reflection

来源：https://github.com/CamilleChiquet/2D-Water-Reflection

- 每个水面资产持有自己的 Camera、RenderTexture 和材质。
- RenderTexture 分辨率按水面 SpriteRenderer 尺寸乘 pixelsPerUnit 创建。
- 相机位置、正交尺寸和比例按单个水面范围配置。
- README 明确支持一个场景中放多个水面资产。

可吸收：

- 按像素密度控制 RT 分辨率。
- 水面范围和相机覆盖区域需要明确对齐。

不采用：

- 多水面意味着多 Camera、多 RT；不适合开放世界大量河流和湖泊。
- 水域成为捕获 owner，会形成水体数量与渲染成本线性增长。

### UnityURP-MobileScreenSpacePlanarReflection

来源：https://github.com/ColinLeung-NiloCat/UnityURP-MobileScreenSpacePlanarReflection

- MIT，公开仓库约 1185 stars。
- 使用 Renderer Feature、Compute Shader、颜色/深度纹理和多个临时 RT。
- 提供 RT 高度、HDR、补洞、去闪烁和不同平台安全路径。
- Android、Metal、DirectX 需要不同处理，代码明确记录设备差异。

可吸收：

- 共享 RT、可配置分辨率和移动端质量降级是正确方向。
- 渲染特性必须有平台安全策略和明确关闭档。

不采用：

- 该方案解决 3D 屏幕空间平面反射，依赖深度和 Compute，不符合本项目 2D Sprite 需求。
- 对像素水面属于明显过度设计。

### Unity 6 URP 2D 官方能力

来源：

- https://docs.unity3d.com/Manual/urp/2D/renderer-features/custom-render-pass-workflow-urp-2d.html
- https://docs.unity3d.com/Manual/urp/2DRendererData-overview.html

官方确认：

- ScriptableRendererFeature2D / ScriptableRenderPass2D 可以通过 Render Graph 创建共享纹理。
- Camera Sorting Layer Texture 可以在指定 Sorting Layer 后截取相机颜色。
- Camera Sorting Layer Texture 支持降采样。

适用判断：

- Renderer Feature 适合后续把共享捕获进一步并入 URP 生命周期。
- Camera Sorting Layer Texture 只能截取已经进入主画面的内容，无法单独解决代理在陆地上的泄漏、对象级启停和换装角色代理同步，因此不作为正式 owner。

## 项目现态影响

玩家角色不是简单单 Sprite：

- 角色主体使用 EquipmentUV Shader 在一个 SpriteRenderer 上合成装备外观。
- 武器会动态创建额外 SpriteRenderer。
- Reflection Proxy 必须覆盖主体和当前启用的武器渲染器。
- 反射系统不得每帧通过名称扫描子物体；EquipmentRenderer 应提供明确的非分配渲染器快照或变更事件。

## 方案裁决

正式方案采用：

“每对象反射代理组 + 场景级注册管理 + 一张共享低分辨率捕获纹理 + 水像素 Mask 合成”。

### 对象侧

- 可倒影对象挂 WaterReflectionCaster2D。
- Caster 持有脚底反射锚点、最大反射距离、垂直压缩、45 度偏斜、强度和质量配置。
- Caster 为每个正式源 SpriteRenderer 管理一个 Reflection Proxy Renderer。
- 动画帧、flip、color、enabled、材质表现和动态武器变化通过明确接口同步。
- Proxy 统一放到 WaterReflectionProxy Unity Layer。

### 系统侧

- 使用场景级 WaterReflectionSystem，不使用跨场景全局玩法单例。
- Caster 在 OnEnable / OnDisable 显式注册和注销。
- 系统维护可见水域的粗粒度空间索引。
- 只有反射 AABB 与可见水域范围相交的 Caster 才启用 Proxy。
- 近中远效果通过每个 Caster 的 MaterialPropertyBlock / Proxy 状态控制，不把对象数组传给水 Shader。

### 捕获侧

- 使用一台共享正交捕获相机和一张共享 RT。
- 捕获相机只渲染 WaterReflectionProxy Layer。
- 主相机排除该 Layer，代理不会直接出现在陆地上。
- 捕获相机使用独立 Renderer2D，不挂 xBRZ，不做后处理。
- RT 对齐像素相机并使用点采样或经验证的低分辨率滤波。
- Renderer Feature 保留为以后有证据时的内部替换候选，不是首版必须迁移目标。

### 水面侧

- 动画 RuleTile 保持原样。
- 水材质只采样共享倒影 RT、动画水基础帧和水像素 Mask。
- Shader 不接收所有倒影对象的位置数组。
- 粗裁剪由 CPU 空间查询完成，精确裁剪由水 Mask 完成。
- 水波只做小幅像素步进扰动，并在边缘衰减。

## 为什么不采用“单例传全部对象位置给每个水 Shader”

- Shader 数组有固定容量，开放世界对象数量不可自然扩展。
- 每个水材质上传对象位置会形成水体数乘对象数的 CPU 和参数更新成本。
- 对象数组会破坏材质共享和批处理稳定性。
- 物体位置加矩形水域 Bounds 只能做粗裁剪，无法匹配 LakeGrass 的不规则水像素。
- 系统会同时持有对象真相、水域真相和材质解释权，职责过重。

正确替代：

- 管理器只做注册、空间粗裁剪、质量选择和共享捕获。
- Proxy 自己承载倒影位置与形状。
- 水 Mask 承载最终显示边界。
- 水 Shader 只做合成，不解释对象列表。

## 性能模型

主要成本：

- 每个启用的源 SpriteRenderer 增加一个 Proxy draw。
- 每帧更新一张共享低分辨率 RT。
- 水面材质增加一次共享 RT 采样和少量扰动计算。

主要控制点：

- 只启用与可见水域相交的 Proxy。
- 静态物体不做无意义逐帧属性同步。
- 动态角色仅在 Sprite/装备/状态变化时同步。
- 远距离 Caster 关闭，低质量档可关闭共享捕获。
- 不创建每水域相机或每对象 RenderTexture。

## 最终结论

评论方案的“对象子反射 + 独立 Layer + 统一管理”应被吸收。

需要修正两点：

1. 统一管理器不向水 Shader 上传所有对象位置；它改为管理代理可见性和共享捕获。
2. 水面范围判断不作为最终像素裁剪；粗范围用于 CPU 剔除，最终显示由水 Mask 完成。

该混合方案比纯反射相机更适合像素 2D，也比纯对象直绘更容易兼容不规则动画水、xBRZ 隔离和开放世界质量分级。
