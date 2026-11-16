# 基础外观绑定迁移边界

## 锁定对象与真相源

本段从 `e173d233` 继续，只迁移 Unity `31629d5` 的基础外观绑定决策，不是最终渲染验收。
源入口为 `EquipmentRenderer.UpdateBodyDepthMode`、`GetSpriteFacingForPart`、`ApplyAppearanceToShader`、`ApplyEyeDecoration`，并核对 `CharacterAppearance`、`DirectionalSpriteHelper.GetByFacing` 与 `CharacterFrameData.GetFacingDirection` 的实际代码。

目标是 `gameplay/presentation/equipment_base_appearance.gd`。这是项目专用表现合同，不新增通用框架、第二套作者数据或运行时搜索入口。输入由原始作者资源的显式适配提供；本段不写任何原素材、原参数清单或资源映射。

## 输入与输出

- `row_index` 是实际精灵帧所属方向行，顺序 SE、SW、NE、NW，不能以动作标签代替。
- `frame.body_regions` 为已显式归一化的部位字典，`head.sprite_facing` 与 `torso.sprite_facing` 必须分别保留原数据。缺部位时回退当前行是原代码行为。
- `left_eye_closed`、`right_eye_closed` 分别来自当前帧，不能合并成一个闭眼位。
- `appearance` 的颜色与纹理引用全部由调用方提供。`hair`、`beard` 各按 `se/sw/ne/nw` 保存纹理引用；眼饰按 `eye_decoration_east/west` 提供。建议采用保留原裁切区域的 `AtlasTexture`；本段不会计算 UV 或替换采样算法。
- `head_equipment` 必须是原槽位选择逻辑已经选出的头部装备；本段仅消费其 `hide_hair/hide_beard`，不自己猜优先级。
- 返回本次完整的受支持绑定决策。调用方必须沿用原 `Refresh` 先重置后应用的顺序；null 纹理表示本次不启用，不能保留上帧纹理的启用位。`appearance_applied=false` 不得伪造眼睛颜色。

## 与原代码一一对应

1. 身体前后和东西只看躯干实际朝向。仅身体深度把非法值修正成 SE；不能把这一校正传播到头部。
2. 眼睛只有头部 SE/SW 时可见，再分别应用单眼闭合。即使身体朝北、头朝南，眼睛仍可见。头朝北、身体朝南则相反。
3. 眼饰 SE 只取东，SW 只取西，背向禁用；没有东西互相回退。闭眼不自动关闭眼饰。
4. 头发、胡须都跟随头部朝向，并先以 SE 是否存在决定是否具备该层。缺 NW 时先 SW 再 SE，缺 NE 或 SW 时回 SE。头部装备可分别隐藏二者，不影响眼睛开关。
5. 左右颜色原样保留，不把测试色或私有作者色写成默认值。

## 验证与未完成项

`tests/test_equipment_base_appearance.gd` 使用原生 Godot `ImageTexture` 做隔离引用身份测试，覆盖 16 组头身朝向交叉、四种单眼闭合组合、缺方向回退、隐藏位、缺外观与非法方向，共 103 个断言。合成纹理只在测试进程内创建，不进入正式资源、场景或视觉交付。

本段没有移植面部装饰、肤色查表及颜色空间转换，没有实现头部装备槽优先级、正式材质参数写入、最终 shader 或原 GameView 截图对比，也没有把合同接入正式角色场景。不得把这段通过称为基础外观全量完成或迁移完成。特别是面部装饰源注释与辅助选择器代码存在差异，后续必须按实际调用路径核实，不能凭“正面显示”的注释补一个新限制。
