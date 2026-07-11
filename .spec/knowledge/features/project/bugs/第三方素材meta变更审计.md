---
name: 第三方素材meta变更审计
description: 项目知识：bugs/第三方素材meta变更审计.md：第三方素材meta变更审计。
metadata:
  type: doc
  status: 已交付
---

# 第三方素材 meta 变更审计

> 目的：回答“是不是动了素材、为什么导入设置像变了”。本文件只做审计和风险分级，不执行回滚。

## 当前结论

| 项目 | 数量 | 结论 |
|---|---:|---|
| 已跟踪的 `Assets/Art/**/*.meta` 变更 | 396 | 确实存在大量第三方素材导入设置变更，不能说“没动素材”。 |
| 已跟踪的 `Assets/Art` 非 meta 变更 | 13 | 除导入设置外，还有少量第三方素材包内 Prefab/Animator/Anim 等变更，需要单独确认是否保留。 |
| 未跟踪的 `Assets/Art/**/*.meta` | 4030 | 有大量新导入素材或重新导入产生的 meta，需确认是否是本次正式纳入的素材包。 |
| 未跟踪的 `Assets/Art` 非 meta 文件 | 3843 | 包含新增素材包目录、demo 场景、脚本、图片和 Prefab；不能当作垃圾自动删。 |

## 字段风险统计

| 字段 | 命中文件数 | 风险解释 | 当前处理 |
|---|---:|---|---|
| `spritePixelsToUnits` | 121 | 会改变像素素材在 Unity 里的世界尺寸，可能让角色/装备/阴影比例变掉。 | 高风险，未经确认不批量改回或继续改。 |
| `filterMode` | 44 | 影响像素插值；Point 通常是正确像素风设置，但需要确认是否破坏原包约定。 | 中风险，适合后续用项目侧导入工具统一预览。 |
| `isReadable` | 329 | 影响代码读取像素和 UI 预览裁剪；从可读变不可读会让运行时预览逻辑失败。 | 高风险，装备/UI 预览相关素材必须重点看。 |
| `spriteMode` | 49 | Single/Multiple 改变会影响切片和动画子资源。 | 高风险，可能破坏动画引用。 |
| `textureCompression` | 345 | 影响像素清晰度和包体；像素素材通常不应被有损压缩。 | 中高风险。 |
| `spriteSheet:` | 3 | 说明切片表自身有变动。 | 高风险，需逐文件确认。 |
| `nameFileIdTable` / `internalIDToNameTable` | 0 | 本轮快速统计未在 git diff 中命中这两个字段名，但仍要防止切片名和 FileID 变化。 | 后续用 Unity 资产引用验证补证。 |

## 风险样例

| 路径 | 风险 |
|---|---|
| `Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites/Craftable Items Icons/Craftable_Items_Icons.png.meta` | 图标素材导入设置变化，可能影响装备/物品 UI 图标。 |
| `Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites/Craftable Items Icons/Potion_Icons.png.meta` | 图标素材导入设置变化。 |
| `Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites/Craftable Items Icons/Trinkets_Icons.png.meta` | 图标素材导入设置变化。 |
| `Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites/Craftable Items Icons/Weapons_Icons.png.meta` | 武器图标导入设置变化。 |
| `Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites/Crafting Professions/Alchemy/Characters/Human_LaboratoryWorking.png.meta` | 人类制作动作 SpriteSheet 导入设置变化，可能影响动画切片和尺寸。 |
| `Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites/Crafting Professions/Alchemy/LaboratoryWorkingShadow.png.meta` | 阴影素材导入设置变化，可能影响场景对齐。 |
| `Assets/Art/MINIFANTASY - Crafting and Professions I/Sprites/Crafting Professions/Alchemy/Laboratory_Working.png.meta` | 道具工作动画导入设置变化。 |

## 不能直接做的事

| 事项 | 原因 |
|---|---|
| 不直接 git 回滚 `Assets/Art` | 会撤掉第三方素材包、新 demo 场景、动画控制器、切片和可能已经被正式引用的 GUID。 |
| 不直接批量改 PPU 到 100 | 当前素材包里不同图片可能有不同像素尺寸和用途，盲改会让世界尺寸、动画和装备层错位。 |
| 不直接把所有 `isReadable` 关掉 | 当前 UI 预览裁剪会读取像素，关掉后会回退或失败。 |
| 不直接把第三方 demo 场景删掉 | 用户要求查素材场景怎么用，它们现在是动作来源证据。 |

## 建议的后续修复方式

| 方案 | 内容 | 状态 |
|---|---|---|
| 导入设置审计器 | 写项目侧 Editor 工具，只列出 MiniFantasy 图片当前 `Texture Type / Sprite Mode / PPU / Filter / Compression / Readable / Mipmap`，先预览不改文件。 | 建议做，未实施。 |
| 导入设置应用器 | 在审计器基础上支持按白名单批量应用像素设置。 | 需要用户确认规则后再做。 |
| 资产引用验证 | 对换装控制器、AnimationClip、EquipmentRenderData 引用的 Sprite 做 GUID/子资源存在性验证。 | 需要 Unity Editor 打开后补。 |

