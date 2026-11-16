# ClickMoveTest 正式人形：Idle / Walk 基础外观

从 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 锁定场景中的玩家实例、玩家预制体和基础 Actor。正式 Actor 引用人类帧数据、基础人形外观，初始装备列表为空。本切片沿用已迁移的四向 Idle / Walk 精灵与动作驱动，接同一个 Sprite2D 的基础合成材质。

- `人类帧数据.asset` 的 Idle / Walk 动作各引用独立的 Body / Head 数据图。取 `EquipmentSystem/GeneratedUV/Human` 的精确 GUID，不取美术目录里的同名 PNG。记录动作帧坐标、头/躯干实际朝向和双眼闭合标记。状态 owner 先换双 UV，实际精灵引用变化才用该 Sprite 的区域更新帧与外观；不因动画循环或转向创建新材质。
- 按源基础外观挂接四向头发、胡子、独立双眼颜色和东/西眼部装饰；北向不启用眼睛与眼饰。身体前后深度只看躯干，不替代头朝向。正式外观无面饰及肤色表，初始无动态装备。
- 全图 UV 左上起点；精灵以原图集区域绘制，基底和双 UV 数据以整图坐标采样。装备贴图的原 Sprite 区域为整图。不开启颜色空间不明的肤色转换。

私有输入准备：在已经核实的 Idle/Walk 私有 PNG + meta 之外，准备原 GeneratedUV 四对文件与基础外观引用的 PNG + meta（外观文件按 `hairSE.png` 等字段名存放）。运行 `tools/extract_formal_human_material.py --repo <locked-git> --human <atlas-dir> --generated-uv <generated-uv-dir> --appearance-dir <appearance-dir> --output <private-json>`；原素材和合同不随仓库分发。先从入口 `start_human_presentation` 得到现有表现节点，再调用该节点 `bind_base_material(data, uv_directory, appearance_directory)`。错误合同不动现有 Sprite，也不自动接入正式启动。

`tests/test_formal_human_material.gd` 在实际 Godot Sprite2D/AnimationPlayer 上校验持久材质的采样、动作更新次序、方向和全部 80 帧；公开测试只用合成输入，同脚本可以从私有目录验证原输入。未接原描边/阴影、挂载/换装、受击与其他动作、正式 PlayerSystem/GAS，未做 Unity/Godot 同机像素对比。它不是整场景或整个迁移的验收。
