# 正式 Human 主图集 Idle/Walk 切片

来源锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。这不是完整换装或视觉验收，也不更改旧的合成测试注入接口。

## 已接入

- 从共享控制器核实 Idle/Walk 引用，读取共享片段 m_SpriteHash 常量曲线；float32 位解释后关联 `category_label` 30 位 CRC32 哈希，逐键核对四向精灵库。
- Sprite GUID/FileID 与原 PNG.meta 内部 ID 联接，不从截图猜行列。提取器验证原 Git LFS SHA256 和逐字节 meta；原文件只在私有目录。
- Idle 16 标签、2 秒；Walk 4 标签、0.5 秒，均间隔 0.125 秒，末关键帧重复最后标签、循环。源控制器速度为 1。
- Godot AtlasTexture 采用原 32×32 区域、中心 pivot、PPU 8、最近邻采样，转换 Unity 左下原点；四向按 SE/SW/NE/NW，方向切换不重置动画。
- `entry.start_human_presentation(manifest, private_directory)` 显式附着于原 Body 偏移，不移动物理根。无合同或缺图就拒绝，不生成替代角色。
- 返回节点的 `set_movement` 必须接原 owner 实际动画位移通知；`set_facing` 必须接 owner 已裁决身体朝向，不能把移动意图当作权威朝向。入口不偷偷接管 GAS/角色 owner。

## 私有重现

```sh
python3 godot/tools/extract_formal_human_animation.py --repo ORIGINAL_GIT --textures PRIVATE_PNG_META_DIRECTORY --output PRIVATE_DIRECTORY/animation.json
GODOT --headless --path godot --script res://tools/check_formal_human_animation.gd -- PRIVATE_DIRECTORY/animation.json PRIVATE_PNG_META_DIRECTORY
```

提取器需要 Python PyYAML。第二条运行真实原图 80 个裁片像素、全部关键帧时间、循环、方向保时、入口偏移检查，不是 GPU 截图比对。JSON/PNG/meta 不应加入仓库。一般无素材测试另检查非法嵌套合同无副作用失败。

## 尚未验收

完整共享控制器状态、动态换装与阴影，以及正式 PlayerSystem/GAS owner 到完整角色表现生命周期均不由本切片宣称完成。基础外观接入记录见既有材质文档；Dmg 增量见下节。此入口只供明确选择的源图样本，默认场景不会展示一个缺层角色冒充完整迁移。Unity/Godot 实机相同状态截图、渲染混合/排序等仍需另行对照。

## 增量：显式 Dmg 表现与基础材质

提取器默认保持原两动作合同；动画和材质提取命令同时增加 `--include-damage` 后，会额外逐字核对原 Dmg 控制器引用、四向库、PNG/meta、FrameData 和 GeneratedUV/Human 的 Body/Head 图。源 Dmg 是 4 帧、8Hz、0.5 秒、非循环；末尾 0.5 秒关键帧重复标签 3，控制器速度 1、无转换。不得用同名 Art UV 代替帧数据引用。

返回的 `HumanPresentation.try_play_damage_animation()` 接受显式表现请求；不产生按键、碰撞伤害、生命值或 GAS 事件。缺少 Dmg 的旧合同返回失败而不生成占位。三动作展示必须绑定覆盖全部三动作的基础材质合同；不能沿用两动作 UV。

恢复仍由既有 CharacterActionAnimatorDriver 独占：请求时默认恢复 Idle；之后原移动 owner 的 SetMovement 可以更新为 Walk/Idle，但不抢占受击。再次受击重播首帧并延期；转向只换方向库；显式新动作取消旧期限；动作锁保持原“请求成功但不切换”语义；非运行预览不自动恢复。未另建计时器。

`tests/test_formal_human_damage.gd` 使用真实 ClickMoveTest 展示入口验证这些分支、四向 16 帧、材质持续复用与 Dmg 独有 UV。默认是合成合同测试；传入五个参数（动画 JSON、材质 JSON、原 PNG 目录、生成 UV 目录、外观目录）可运行私有原图逐像素裁片检查。测试不代表 GPU 或 Unity/Godot 截图一致。

本节只新增原 Dmg 图集/时序/基础外观的显式展示请求，不宣称正式伤害 owner 到表现已接通。完整死亡、打断/GAS、装备/坐骑、阴影和跨引擎画面验收仍未完成。
