---
name: equipment-system-workflow
description: FantasyWord 换装与坐骑表现工作流。覆盖普通换装、坐骑原版素材直显、骑乘姿态普通装备叠加、动作协议和真实 GameView 完整截图/GIF 验收。
---

# Equipment System Workflow（换装与坐骑表现工作流）

## 适用范围

- FantasyWord 的 MiniFantasy 换装系统、装备表现资产、坐骑表现资产、帧编辑器配置和运行时表现验收。
- 普通换装任务：新增或修正装备层、配置角色帧数据、生成 Body/Head UV 图、排查 Idle/Walk/Attack 换装错位。
- 坐骑任务：接入作者原版坐骑本体和骑手基础层 Sprite，并在运行时逐帧直显；阴影不进入坐骑动作接入门槛。
- 验收任务：用装备测试场景真实 GameView 完整截图验收，不用局部图、离屏图或预览图替代。
- 不适用：普通角色动画状态机重构、正式战斗技能逻辑、非 MiniFantasy 素材迁移；这些任务先回到对应 Unity / GAS / 素材 skill。

## 前提锁定

修改代码、资源、场景或发布截图前，先锁定四项：

1. **问题对象**：明确是身体、头部、眼睛、手脚、服装、头部装备、武器槽、坐骑表现，还是工作台 UI。
2. **真相来源**：普通换装优先用正式 `CharacterFrameData`、装备资产、`EquipmentRenderer` 运行时输出和 Unity PlayMode 当前 GameView 完整截图；坐骑优先用作者原版坐骑 Sprite、骑手基础层 Sprite、`MountRenderData`、`MountedCharacterPresentation` 运行时输出和 Unity PlayMode 当前 GameView 完整截图。阴影按普通换装 Shader 职责理解，不作为坐骑动作接入门槛。离线合成图只能作辅助证据。
3. **目标入口/环境**：默认装备验收入口是 `Assets/Scenes/EquipmentSystemDemo.unity` 的 `EquipmentSystemDemoCharacter`。移动/实战场景只在用户明确要求时作为补充入口。
4. **验收口径**：写清动作、方向、帧、装备组合、是否为坐骑原版素材直显、是否允许基础动画自带武器、最终截图必须是完整画面，以及是否需要上传截图站。

任一项没锁定时，只能继续定位或补证据，不得先改。

## 关键真相源

- 帧数据：`Assets/GameData/EquipmentSystem/FrameData/人类帧数据.asset`
- 生成 UV：`Assets/GameData/EquipmentSystem/GeneratedUV/Human/*_BodyUV.png`、`*_HeadUV.png`
- 工作台目录：`Assets/GameData/EquipmentSystem/Data/Workbench/换装工作台目录.asset`
- 默认外观：`Assets/GameData/EquipmentSystem/Appearance/基础人形外观.asset`
- 装备资产：`Assets/GameData/EquipmentSystem/Equip/Visual/*.asset`
- 运行时渲染：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/EquipmentRenderer.cs`
- 坐骑表现资产：`Assets/GameData/EquipmentSystem/Mounts/*.asset`
- 坐骑运行时表现：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/MountedCharacterPresentation.cs`
- 类型配置：`Assets/Scripts/Presentation/EquipmentSystem/Data/Appearance/EquipTypeConfig.cs`
- 装备测试场景：`Assets/Scenes/EquipmentSystemDemo.unity`

## 层级含义

| 现实对象 | 配置/代码含义 | 渲染来源 |
| --- | --- | --- |
| 服装、裤子、披风、背包 | 身体/躯干装备层 | Body UV Map + 装备 Sprite |
| 头盔、帽子、面罩、护目镜 | 头部装备层 | Head UV Map + 装备 Sprite |
| 手套 | 左右手颜色替换 | 帧数据里的手部蒙版 + Color 装备 |
| 鞋子 | 左右脚颜色替换 | 帧数据里的脚部蒙版 + Color 装备 |
| 眼睛、眼部装饰 | 角色外观层 | 帧数据眼睛蒙版 + `CharacterAppearance` |
| 武器、盾牌 | 独立武器槽 | 武器锚点和武器序列，不属于 Body/Head UV |
| 坐骑本体、骑乘基础人形 | 坐骑表现层 | 作者原版 Sprite 逐帧直显 |

## 帧编辑器与 UV 流程

1. 先锁定动作和方向，例如 `Idle`、`Walk`、`Attack`，以及 SE/SW/NE/NW。
2. 在帧编辑器中按现实部位涂色：头部、身体、左右手、左右脚、左右眼。
3. 对头部和身体执行扩展，让装备层覆盖需要跟随动作的像素区域。
4. 设置或核对眼睛和手的位置；眼睛只在正面方向显示，背面方向不显示不是失败。
5. 生成对应动作的 `BodyUV` 和 `HeadUV`，保留 `.meta` 和 GUID，不新建替代资源顶包。
6. 资源层检查通过后，再进 Unity PlayMode 做端到端截图；不要用 UV 预览图或离线合成图替代最终验收。

## 动画生成流程

1. 动作状态只能来自共享动作 Animator；方向由 `SpriteLibrary` 方向变体承担，不恢复动作 × 方向状态。
2. 生成设置唯一正式 owner 是 `Assets/GameData/EquipmentSystem/Data/Workbench/换装动画生成设置.asset`。
3. 发现多个 `EquipmentSystemGenerationSettings` 时必须先收口设置资产，不得由生成器按路径排序猜一个。
4. 单方向素材可以复制到四方向库，但必须在报告或门禁中可见；不得把复制结果说成真实四向作者帧。
5. 生成器只写派生动画资产和工作台目录中应由它拥有的派生引用；不得加载、保存或修补场景/Prefab。
6. 已有 Unity 序列化引用优先保留；只有运行时动态加载外观、DLC 或热更资源时，才接入 Yoki/Addressables。

## Attack 特例

- Attack 基础动画可能自带武器像素；这不是装备武器。
- 排查 Attack 的服装、帽子、眼睛、手套错位时，不装备武器/盾牌，不修改 `长矛.asset`、`战斧.asset` 等武器资产。
- 只有用户明确说“武器装备位置错误”时，才进入武器槽、锚点和武器序列排查。
- 截图前必须确认实际 Sprite 是 Attack，例如 `Minifantasy_CreaturesHumanAttack_*`；`requestedAnimation=Attack` 但 Sprite 仍是 Idle 时，不能当作 Attack 端到端证据。
- 选择 Attack 验收帧时，优先选能同时看到身体、头部和至少前向手部的帧；挥击幅度大的帧可作为补充，不一定适合检查手套。

## 坐骑表现规则

1. 坐骑当前按作者原版素材直显：坐骑本体 Sprite、骑手基础层 Sprite 必须来自坐骑素材自身的同画布、同帧、同方向序列。
2. 坐骑本体始终按作者原版 Sprite 直显，不使用普通换装材质，也不把 Body/Head UV 或装备 Shader 当作坐骑本体通过门槛。阴影按当前项目口径不进入坐骑动作适配。
3. 骑手没有普通装备时按作者原版 Sprite 直显；骑手有普通装备时，仍使用同一作者骑手 Sprite 作为当前帧，但切换到该坐骑的骑乘 `CharacterFrameData` 和 Body/Head UV，通过现有 `EquipmentRenderer` 合成普通装备。两种模式必须分开验收。
4. 坐骑动画必须通过“角色动作输入 -> 坐骑动作语义 -> 坐骑资产逐帧数据”对接；角色 `Idle/Walk` 只能作为输入，分别映射为坐骑 `Stand/Move`，不得直接把普通角色动作名当成坐骑素材动作真相。
5. 坐骑不生成“动物 × 动作 × 方向”的 Animator 状态组合；正式做法是通用逐帧播放器同步坐骑本体和骑手基础层 Sprite。
6. 每个坐骑资产声明自己支持的动作语义，例如 `Stand/Move/Attack/Hurt/Die/MountUp/MountDown`；不支持的语义只能按资产默认动作回退，并在报告里可见，不能说成该动作已真实接入。
7. 运行时只同步动作语义、方向和帧索引；当前不得新增独立挂点或偏移配置作为坐骑接入前提。
8. 坐骑验收必须分别记录坐骑本体和骑手基础层的真实 Sprite 名；任何一层为空都不能称为坐骑表现通过。阴影不是坐骑动作接入的必备层。
9. 四向素材缺任一方向时必须失败，除非资产显式声明四向共用 SE；本体/骑手都有帧但数量不一致时必须失败，不得截成较短序列。
10. 自定义动作按精确键选择；动作回退必须出现在运行时报告中。非循环动作必须配置完成行为。
11. 样板生成器只补齐自己拥有的 Stand/Move 和缺失 UV；已有完整帧、人工标注和其它动作不得覆盖。重复执行前后要比较动作数、UV GUID 和目标资产哈希。

## 运行时验收

1. 用 `EquipmentSystemDemo` 或用户指定的装备测试入口，不要默认拿当前 PlayMode 场景当目标。
2. 普通换装验收使用正式 `EquipmentRenderer` 运行时输出；坐骑验收使用正式 `MountedCharacterPresentation` 运行时输出，并按原版 Sprite 直显判断坐骑本体和骑手基础层。
3. 使用工作台控制器或等价正式组件设置角色、动作、方向和装备；坐骑验收必须明确当前坐骑表现资产。
4. 非武器层验收时显式保持 Weapon / Shield 槽为空；记录主手/副手装备槽状态。
5. 至少覆盖代表性 Idle 与 Attack；坐骑最小闭环至少覆盖角色 Idle/Walk 输入解析出的坐骑 Stand/Move 与 SE/SW/NE/NW，且每组必须对照资产验证连续两帧。若用户指定更多动作或坐骑资产支持更多语义则按支持集覆盖。
6. 记录每张截图的场景、动作、方向、Sprite 名、装备槽数量、武器槽是否为空；坐骑截图还要记录坐骑本体和骑手基础层 Sprite 名。
7. 最终验收图必须是当前真实 GameView 通过 `ScreenCapture.CaptureScreenshot` 产生的完整画面，能看到角色/坐骑和场景关系。只围绕角色裁出来的 256x256 小图、局部辅助图、近景裁图、局部放大图、临时离屏相机、RenderTexture、只渲染临时对象的截图、材质预览、Sprite 预览和 UV 预览，一律只能作为内部调试证据，不能作为最终验收图，也不能发布为 `passed`。
8. 动作、序列帧、挥砍、特效或时序类问题，优先录制 GIF 或输出连续帧证据；静态截图只能证明单帧状态，不能单独证明动画接入完成。
9. GIF 可以由 PlayMode 中当前真实 GameView 连续截图编码生成，但不得用离线摆图、素材拼贴、临时离屏相机或手工合成帧冒充端到端动画。
10. 截图/GIF 不得黑屏、裁边、加载中、只截局部、只截临时对象、出现洋红错误块，或来自错误场景。

## 图片核验与发布

- `.codex/skills/safe-image-reading/SKILL.md` 与看图前压缩/预算门禁已于 2026-07-14 按用户要求暂停，不再作为当前截图核验入口。
- 端到端证据仍应能回到真实截图和真实 Unity 现场，不用轻量图产物替代现实真相源。
- 用户要求上传服务器时，先使用 `artifact-preview-publisher`；只发布已经核验通过的最终图。
- 候选图、失败图、离线合成图、黑图、错误场景截图、局部裁图、临时离屏相机图和局部辅助图不得发布为 `passed`。

## 禁止行为

- 不得把离线合成图、UV 预览图或辅助标注图说成端到端证据。
- 不得把局部辅助截图、角色近景裁图、临时离屏相机图、RenderTexture 图、材质预览或 Sprite 预览说成最终验收截图。
- 坐骑当前验收不得把换装 Shader、Body/Head UV 材质状态或离线材质结果当作坐骑本体通过条件；坐骑本体和骑手基础层必须回到作者原版 Sprite 直显结果。阴影不作为坐骑动作接入门槛。
- 不得因为 Attack 画面里有武器，就默认修改武器装备资产。
- 不得把当前打开场景、旧截图或上一次 PlayMode 状态当作本轮目标入口。
- 不得覆盖正确装备资产、场景或 `.meta`；资源错误需要撤回时只做最小手工修正，不用 git 回滚。
- 不得写 fallback 0、占位图或临时 Sprite 到正式装备链路冒充修复。
- 不得新增第二个换装动画生成设置资产；不得让生成器全工程扫描后自行选择设置。
- 不得把 Yoki/Addressables 字符串 key 强行替代稳定序列化引用，除非目标本来就是运行时动态加载。
- 不得声称“修好”或“通过”，除非已有新鲜 PlayMode 运行时截图或等价真实证据。

## 完成前检查

- 问题对象、真相来源、目标入口、验收口径都已写清。
- 相关资源 diff 只包含本轮目标文件；武器资产没有无关差异。
- Attack 验收图的实际 Sprite 名是 Attack。
- Weapon / Shield 槽状态符合本轮目标。
- 身体、头部、眼睛、手脚的表现结论来自真实运行时截图。
- 坐骑表现结论来自真实运行时完整截图；坐骑本体和骑手基础层都已记录真实 Sprite 名，穿普通装备时另行确认骑手换装 Shader 与骑乘 UV，坐骑本体仍保持原版直显。
- Idle/Walk 四向已分别对照资产验证第 0 帧和下一帧，本体与骑手都真实推进且没有静默动作/方向回退。
- 生成器重复执行没有减少动作、改变已有 UV GUID 或覆盖人工帧数据。
- 最终验收图是当前真实 GameView 的 ScreenCapture 完整画面，不是局部裁图、局部放大图、临时离屏相机图、RenderTexture 图、局部辅助图或预览图。
- 如果上传截图站，公开详情页、API、图片 URL 和文件 hash 均已核验。
