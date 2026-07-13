# Design: introduce-water-surface-reflection

## Runtime Flow

```text
主相机与水域入口确定当前可见水域粗范围
  -> WaterReflectionSystem 查询可能投影到可见水域的 Caster
  -> Caster 按脚底锚点、45 度参数和质量档更新 Reflection Proxy 组
  -> 一台共享捕获相机只渲染 WaterReflectionProxy Layer 到低分辨率 RT
  -> 水面材质采样动画水、水 Mask 和共享倒影 RT
  -> 水 Mask 精确裁剪，边缘衰减和像素扰动完成最终水面
```

游泳动画已经负责“只显示上半身”，本方案不再重复实现身体遮罩。水面倒影只消费“角色是否在水中”这一状态，用来决定玩家自身倒影是否淡出或关闭。

## Authoring Model

### Visual Water

现有动画水 Tilemap 继续作为水面视觉作者入口：

```text
地形Grid
  河流与湖泊      动画水 RuleTile，可见水面
  水域检测        可选 Trigger/Mask，表示默认可游泳区域
  岸线障碍        岸边、高差、石头、悬崖、地图边界等阻挡
```

原则：

- 视觉水不承担整块阻挡职责。
- 可游泳不是“特殊水”，而是开放世界水域默认行为。
- 不可穿越的地方由岸线、障碍或高差表达。
- 水像素 Mask 可以来自单独 Mask Tilemap、生成纹理或后续水域配置，但不能从混合了草岸的 Tile Sprite alpha 直接推断。

### Reflection Mask

倒影只能画在真实水像素内。首批允许两种来源：

1. 手工或工具生成的水 Mask。
2. 与水域检测一致的 Tilemap/网格区域，再经过像素边界修正。

`LakeGrass` 这类同时包含水面和草岸的动画瓦片不能直接整块作为倒影 Mask，否则岸草也会出现倒影。

## Reflection Caster And Proxy Model

### WaterReflectionCaster2D

每个可倒影对象通过显式组件进入系统。组件至少配置：

- 反射脚底锚点。
- 最大投影距离。
- 垂直压缩比例。
- 45 度俯视偏斜系数。
- 近中远强度。
- 静态或动态同步模式。
- 正式源 SpriteRenderer 列表或渲染器提供者。

Caster 在 OnEnable / OnDisable 向场景级 WaterReflectionSystem 注册和注销，不通过全局查找或对象名称发现依赖。

### Reflection Proxy Group

一个 Caster 可以管理多个 Proxy Renderer：

- 普通树木或道具通常只有一个 Proxy。
- 玩家至少需要主体 Proxy，并在武器 Renderer 出现时动态补充对应 Proxy。
- Proxy 使用专用 WaterReflectionProxy Unity Layer，主相机不渲染该层。
- Proxy 围绕脚底锚点形成翻转、垂直压缩和 45 度偏斜后的几何。
- 动画 Sprite、flip、color、enabled 和材质表现只在源状态变化时同步；静态物体不做无意义逐帧复制。

不能把玩家简化为复制一个主 Sprite。当前 EquipmentUV Shader 负责主体换装合成，EquipmentRenderer 还会动态创建武器 SpriteRenderer，因此它需要提供明确的非分配 Renderer 快照或变更事件；反射系统不得每帧按名称扫描生成武器子物体。

## Reflection Capture

### Formal Shared Proxy Camera

正式首版使用一台共享正交捕获相机：

- 与主相机保持相同的正交覆盖和像素网格对齐。
- 输出到低分辨率 RenderTexture。
- 只渲染 WaterReflectionProxy Layer。
- 使用独立 Renderer2D，不启用 xBRZ、后处理和无关 Renderer Feature。
- RenderTexture 使用可控分辨率、点采样或像素风友好的受控滤波。
- 不为每条河、每个湖、每个 Tilemap 单独创建相机。
- 不为每个对象创建 RenderTexture。

这台相机捕获的是已经形成正确反射几何的 Proxy，不承担物理镜面相机变换，因此多片水域可以共享同一张纹理。

### Optional Renderer Feature Replacement

Unity 6 URP 2D 支持 ScriptableRendererFeature2D、ScriptableRenderPass2D 和 Render Graph。它们保留为以后替换“共享捕获相机内部实现”的候选，但首版不强制迁移：

- 只有 Frame Debugger、GPU 时间或内存数据证明共享相机是瓶颈时才评估替换。
- 替换后仍必须保留 Caster、Proxy、WaterReflectionProxy Layer、共享纹理和水 Mask 合同。
- 不能为了使用新 API 重写对象状态和水域作者入口。

### Camera Sorting Layer Texture Position

Camera Sorting Layer Texture 可以作为补充方案，用于简单屏幕层采样或临时实验，但不作为正式倒影捕获 owner：

- 它按排序层截取相机颜色，适合快速得到“已经渲染过的前景”。
- 它无法让 Reflection Proxy 只进入离屏纹理而不直接泄漏到陆地画面，也不负责代理注册、游泳状态和空间剔除。
- 如果实施阶段使用它，必须只作为材质辅助输入，不得替代倒影对象筛选配置。

## Spatial Culling And Distance

WaterReflectionSystem 只做粗粒度空间工作：

1. 收集当前相机可见水域的世界 Bounds 或水格粗索引。
2. 计算每个 Caster 的潜在反射 AABB。
3. 只有潜在反射 AABB 与可见水域粗范围相交时才启用 Proxy。
4. 最终是否显示在某个像素上由水 Mask 决定。

管理器不得把所有对象位置上传给每个水材质。这样可以避免固定长度 Shader 数组、水体数乘对象数更新，以及每个材质不同参数造成的批处理破坏。

## Reflection Object Policy

### Reflectable Objects

首批允许进入倒影纹理的对象：

- 岸上玩家和 NPC。
- 树木、建筑上层、桥、牌子等高于水面的静态/半静态对象。
- 明确标记为可倒影的装饰物。

首批不捕获：

- UI。
- 地表 Tilemap。
- 水 Tilemap 自己。
- 粒子和高频特效，除非后续单独评估。
- 游泳中的玩家完整站立形态。

### Swimming Player Policy

角色处于游泳状态时：

- 默认从普通倒影捕获中排除玩家完整身体。
- 可选保留极弱的上半身暗影或波动影，但必须跟随游泳动画实际显示部分。
- 不由水面 Shader 重新遮挡角色下半身。
- 涟漪、入水波纹和水花可在后续 VFX change 中扩展。

## Distance And Quality Tiers

### Tier Inputs

倒影强度由以下输入共同决定：

- 主相机质量档。
- 当前平台质量档。
- Caster 潜在反射 AABB 到最近可见水域粗范围的距离。
- Caster 到玩家或相机焦点的距离。
- 对象是否处于游泳状态。

### Tier Behavior

| 等级 | 捕获更新 | 材质采样 | 视觉 |
| --- | --- | --- | --- |
| Near | 启用完整 Proxy 并按源状态变化同步 | 正常采样倒影 RT | 清晰但像素化的倒影，轻微波动 |
| Mid | Proxy 变短、变暗或更强压缩 | 倒影 alpha 降低，扰动增大 | 只保留主要明暗块 |
| Far | 关闭 Proxy，不进入共享捕获 | 使用静态暗色/水面动画变化 | 无清晰倒影 |
| Off | 不分配或不绑定 RT | 跳过倒影分支 | 仅动画水 |

默认移动端目标：

- RT 分辨率从 0.5 屏幕比例起步。
- 低端档允许 0.25 或关闭。
- 中远景不做额外局部反射相机，远景 Caster 直接关闭 Proxy。

## Water Material Composition

水面材质负责：

1. 采样现有动画水基础帧。
2. 使用水像素 Mask 裁剪倒影。
3. 用像素步进的轻微 UV 扰动处理水波。
4. 用边缘衰减限制 UV 扰动，避免水面 Mask 或贴图边界穿帮。
5. 按距离和质量档淡出倒影。
6. 对倒影颜色做压暗、降饱和和透明混合，保持像素风。
7. 只读取共享 RT 和水域自身参数，不接收全部倒影对象的位置数组。

水面材质不负责：

- 判断角色是否能游泳。
- 播放游泳动画。
- 遮挡游泳角色身体。
- 生成正式水域碰撞。

## Tutorial Coverage Boundary

当前链接已经完整转录，标题中的 1/2 不代表本地转录缺失。视频结尾说明普通纹理翻转仍会暴露 45 度俯视角的物体底部问题，但没有可用后续视频。

本提案已通过公开实现和评论方案完成裁决：

- 反射几何围绕对象脚底锚点生成，不围绕整张水面纹理翻转。
- Proxy 使用垂直压缩和可调 45 度偏斜。
- 水 Mask 只负责最终水像素裁剪。
- 在 ClickMoveTest 中用树木、玩家和建筑验证不会出现明显底部穿帮。

因此本 change 不依赖不存在的后续视频；45 度代理参数和场景验收属于正式实施任务。

## Water Area State

水域状态入口至少需要回答：

- 当前世界位置是否为水域。
- 水域是否可游泳；默认是可游泳。
- 角色是否正在水中。
- 角色是否处于入水/出水过渡。
- 该角色是否应该参与普通倒影。

该入口可以先由 Trigger/Mask 实现，后续再与地形导航、水域数据和开放世界加载整合。倒影、游泳、涟漪不得各自从不同来源判断“是否在水中”。

## Collision Boundary

水不再默认等于阻挡。阻挡职责拆给：

- 岸边高差。
- 石头、树根、建筑、码头边缘。
- 地图边界。
- 特殊剧情或危险障碍。

如果某片水后续真的不可游泳，应作为特殊水域规则显式配置，而不是通过水 Tilemap 实体碰撞隐式表达。

## Failure Handling

- 倒影 RT 未配置：水面使用纯动画水，不报假成功；调试面板提示倒影关闭。
- 水 Mask 缺失：不得把整块混合瓦片当水像素；只允许临时关闭倒影或使用明确调试 Mask。
- 倒影对象层为空：水面不显示动态倒影，并在调试信息中列出捕获配置缺失。
- WaterReflectionProxy Layer 或独立 Renderer2D 缺失：共享捕获初始化失败并说明缺少的项目配置，不自动改用主相机。
- Caster 缺少正式源 Renderer：该对象不生成 Proxy，并报告具体对象和缺失引用。
- EquipmentRenderer 没有提供动态 Renderer 集合入口：玩家只能进入代理接入调试状态，不得把单主体 Sprite 当完整玩家倒影交付。
- 游泳状态不可用：玩家倒影按岸上规则处理，但不得声称游泳倒影已完成。
- xBRZ 影响倒影 RT：视为渲染配置缺口，必须隔离 Renderer 或跳过 RT 相机。
- 低端质量档关闭倒影：这是质量策略，不是错误。

## Validation

### Focused Contracts

- 水域默认可游泳。
- 岸线/障碍阻挡不等于水面阻挡。
- 游泳中的玩家不进入完整站立倒影。
- 可倒影对象过滤不包含 UI 和水 Tilemap。
- Proxy Layer 不会被主相机直接绘制。
- 玩家 Proxy 组包含主体换装结果和当前可见武器。
- WaterReflectionSystem 只启用可能投影到可见水域的 Proxy。
- 水材质不接收全部对象位置数组。
- 近中远质量档能稳定改变倒影强度或关闭状态。
- 缺 Mask 时不会把整块草岸动画瓦片当作水面倒影区域。

### Scene Validation

- 复用 `ClickMoveTest`，不创建第二套水面测试场景真相。
- 近景岸边对象在水中出现像素风倒影。
- 玩家游泳时保持现有游泳动画表现，不出现完整站立倒影。
- 中远景水面倒影弱化或关闭，水面动画仍正常。
- 移动端质量档可关闭动态倒影。
- 使用 Frame Debugger 确认只有一台共享捕获相机、一张共享 RT，且没有重复捕获无关层。
- 使用 Profiler 记录启用 Proxy 数、额外 draw call、CPU 和 GPU 成本。
