# 【小猫unity教程】1/2 2D 45度俯视角水面动态倒影 — Unity 学习笔记

> 教程层级：入门  |  Unity 版本：2022.3 LTS  |  渲染管线：Shader Graph / Sprite Lit Shader Graph，具体 RP 未在转写中明确  |  来源：https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba

## 核心思路

- 教程用一台专门的倒影相机把场景物体渲染到 `RenderTexture`，再让水面材质采样这张纹理。
- 倒影平面通过翻转缩放得到“镜像”效果，再与湖面贴图做透明混合。
- 水波动态来自 Shader Graph 中的时间驱动噪声：噪声扰动 UV，让倒影和水面贴图产生波纹。
- 为了避免水面边缘穿帮，教程用从中心向外的衰减遮罩限制边缘扰动强度。
- 该视频是上半部分：结尾明确指出 45 度俯视角还不完全符合反射规则，下一期会继续改进“看到物体底部”的问题。

## 知识点梳理

### 1. 用相机输出到 RenderTexture [00:16](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=16)

- **知识点**：Unity `Camera` 可以把渲染结果输出到 `RenderTexture`，再被材质或 Shader Graph 采样。
- **对应能力**：`Camera.targetTexture`、`RenderTexture` 资源、Camera `Output` 面板。
- **教程做法**：新建 `Shadow Camera`，设置为正交相机，把目标输出指向新建的 `RenderTexture`。

### 2. 用 Layer 控制倒影捕获对象 [02:16](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=136)

- **知识点**：倒影相机不应该拍到所有场景内容，应该用 Layer/Culling Mask 控制捕获对象。
- **对应能力**：GameObject Layer、Camera Culling Mask。
- **教程做法**：把需要倒影的场景物体放到专门层，让倒影相机只看到这个层；后续又把玩家加入 `Player` 层并勾选进倒影相机。

### 3. Shader Graph 采样倒影纹理 [02:51](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=171)

- **知识点**：Shader Graph 可以通过 Sample Texture 节点读取 `RenderTexture` 并输出到 Base Color。
- **对应能力**：Sprite Lit Shader Graph、Sample Texture 2D、Base Color、Alpha。
- **教程做法**：创建 Sprite Lit Shader Graph，采样倒影 `RenderTexture`，做成材质后赋给一个水面用的 `Square`。

### 4. 通过翻转平面得到倒影方向 [03:50](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=230)

- **知识点**：2D 倒影可以先用简单的负缩放或翻转显示镜像。
- **对应能力**：Transform Scale、Sprite/Quad 材质显示。
- **教程做法**：把显示倒影纹理的 `Square` 在某个轴向翻转，让纹理看起来像水面倒影。

### 5. 用湖面贴图和 Lerp 混合倒影 [04:23](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=263)

- **知识点**：倒影直接显示会太突兀，需要和水面基础贴图融合。
- **对应能力**：Sample Texture 2D、Lerp、Float 参数、Alpha。
- **教程做法**：增加一个湖面贴图采样节点，用 `Lerp` 把倒影和湖面贴图混合，并用 Float 控制混合比例。

### 6. 用透明通道裁剪水面 [06:03](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=363)

- **知识点**：水面材质需要正确使用贴图 Alpha，否则会显示成完整方块。
- **对应能力**：Split 节点、Alpha 输出。
- **教程做法**：把水面贴图输出拆分，取 Alpha 通道接到 Shader Graph 的 Alpha。

### 7. 用时间噪声扰动 UV [07:00](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=420)

- **知识点**：动态水波可以通过噪声纹理扰动 UV，而不是移动物体本身。
- **对应能力**：Time、Multiply、Add、Noise、UV、Remap。
- **教程做法**：用时间节点驱动噪声移动，把噪声通过 `Remap` 压到 `-0.05 ~ 0.05`，再和原始 UV 相加，输出给倒影和水面贴图采样。

### 8. 限制边缘水波避免穿帮 [08:22](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=502)

- **知识点**：水面边缘不应有过强 UV 偏移，否则贴图会露出边界或形变穿帮。
- **对应能力**：Radial/Polar 坐标类节点、One Minus、Clamp、Multiply。
- **教程做法**：用中心向外的渐变反相后限制范围，再乘到噪声偏移上，形成“中间波动强、四周波动弱”的效果。

## 编辑器操作路径

1. 在 Hierarchy 面板中新建 Camera，命名为 `Shadow Camera`。
2. 将倒影相机设为 Orthographic，并调整位置、尺寸，使其覆盖水面附近需要倒影的区域。
3. 在 Project 面板中新建 `RenderTexture`，赋给倒影相机的 `Output / Target Texture`。
4. 新建用于倒影对象的 Layer，设置倒影相机的 Culling Mask 只包含该层和后续玩家层。
5. 创建 Sprite Lit Shader Graph。
6. 在 Shader Graph 中添加倒影 `RenderTexture` 的 Sample Texture 节点，接到 Base Color。
7. 创建一个显示倒影的 `Square`，赋予该 Shader Graph 生成的 Material。
8. 翻转 `Square` 的轴向缩放，使画面成为倒影。
9. 增加湖面贴图采样，用 `Lerp` 混合倒影和湖面贴图。
10. 拆分湖面贴图输出，把 Alpha 通道接到材质 Alpha。
11. 用 Time + Noise + Remap + UV Add 做波纹扰动。
12. 用中心衰减遮罩限制水面边缘的扰动强度。

## 核心代码架构

### 场景层级结构

```text
Scene
├── Main Camera
├── Shadow Camera
│   └── Target Texture -> WaterReflection RenderTexture
├── Reflectable Objects
│   ├── Trees / Props / Player
│   └── Layer -> Reflectable / Player
├── Water Reflection Plane
│   └── Material -> WaterReflection Shader Graph Material
└── Water Surface Mask / Lake Texture
```

### 关键脚本

视频没有写 C# 脚本，核心全在 Unity 编辑器配置和 Shader Graph 节点连接里。若转成项目正式实现，后续需要补 C# 管理：

- 倒影相机或 URP 2D 渲染入口的生命周期。
- `RenderTexture` 分辨率和质量档。
- 可倒影对象层配置。
- 近中远距离分级。
- 游泳中角色是否进入普通倒影捕获。

### 组件连接关系

```text
Shadow Camera.targetTexture -> WaterReflection RenderTexture
WaterReflection RenderTexture -> Shader Graph Sample Texture
Lake Texture -> Shader Graph Sample Texture
Lerp(Reflection, LakeTexture, Blend) -> Base Color
Lake Texture Alpha -> Shader Graph Alpha
Time + Noise + Remap -> UV Offset
UV + Offset -> Reflection Texture UV / Lake Texture UV
Reflectable Layer -> Shadow Camera Culling Mask
```

## 关键要点

- **容易踩的坑**：`RenderTexture` 尺寸改完后，相机预览/输出有时需要重新赋值或刷新才生效；视频提到 2022.3 LTS 仍有这个现象。
- **容易踩的坑**：倒影相机如果不限制 Layer，会把地面也拍进去，导致水面里出现不该有的地表内容。
- **容易踩的坑**：只做翻转适合快速看到倒影，但 45 度俯视角下会看到物体底部，教程本期结尾说明这还不符合最终反射规则。
- **最佳实践**：倒影纹理应通过明确对象层捕获，不要直接拍整张屏幕。
- **最佳实践**：水波扰动要压小范围，边缘还要衰减，否则水面外轮廓容易穿帮。
- **延伸学习**：Unity `Camera.targetTexture`、`RenderTexture`、Shader Graph `Sample Texture 2D`、`Lerp`、UV distortion、URP 2D 自定义 Renderer Feature。

## 对 FantasyWord 的吸收结论

### 1. 可直接吸收 [00:16](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=16)

- 用共享倒影捕获生成一张低分辨率纹理。
- 用 Layer/配置过滤可倒影对象。
- 水面材质采样倒影纹理并与动画水基础画面融合。
- 用轻微 UV 噪声扰动制造水波。
- 用边缘衰减避免水面 Mask 边界穿帮。

### 2. 不能照搬 [09:35](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=575)

- 不能只靠一个翻转平面作为正式 45 度俯视角倒影，因为视频本身也指出它不符合 45 度反射规则。
- 不能每片水域一台相机；FantasyWord 是开放世界和移动端目标，需要共享捕获与质量档。
- 不能把水面 Shader 当作游泳遮罩 owner；项目游泳动画已经负责半身显示。
- 不能直接用 `LakeGrass` 这类草岸混合瓦片的整张 alpha 当倒影 Mask。
- 不能让 xBRZ 对倒影 RenderTexture 做错误的二次处理。

### 3. 项目落地路线 [07:00](https://www.bilibili.com/video/BV1xo4y1T7FJ/?spm_id_from=333.337.search-card.all.click&vd_source=7f7cddebb8e568a415f97f9539bbcaba&t=420)

1. V0 先用共享正交倒影相机 + 低分辨率 `RenderTexture` 复现教程核心效果。
2. 水材质保留动画水，叠加倒影纹理和小幅像素扰动。
3. 用正式水 Mask 限制倒影范围。
4. 游泳中玩家从完整倒影捕获中排除。
5. 近景保留明显倒影，中景弱化，远景/低端档关闭动态倒影。
6. V0 通过后，再迁移到 URP 2D 自定义渲染入口，解决 xBRZ 和共享渲染生命周期问题。

