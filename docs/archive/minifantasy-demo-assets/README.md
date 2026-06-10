# MiniFantasy Demo 资产归档

## 归档原因

本目录保存从正式 `Assets/Art` 入口移出的 MiniFantasy 素材包 demo 场景。它们用于展示素材包能力，但不是 `FantasyWord` 当前新游戏的正式场景、Prefab 装配或验证入口。

## 当前内容

- `Assets/Art/MINIFANTASY - Crafting and Professions I/Scenes`
- `Assets/Art/MINIFANTASY - Crafting and Professions I/Scripts/TH_DemoManager.cs`
- `Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Scenes`
- `Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Scripts/CTR_DemoManager.cs`
- `Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Scripts/CTR_AnimateCreature.cs`
- `Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Scripts/CTR_ShadowSwitch.cs`

## 使用边界

- 这些场景可作为素材表现参考。
- 不把这些场景中的 demo manager、demo camera、demo light、临时 UI 或场景摆放当作正式玩法合同。
- 已归档脚本在正式 `Assets/Art` 中无 Prefab/场景引用；仍被素材包 Prefab 引用的采集物、弹体和变体脚本继续留在正式素材包目录。
- 若后续确实需要复用其中某个对象，先把对象纳入参考记录，再迁入正式 `Assets` 入口并重新验证。
- 素材包主体、动画、Sprite、Prefab 和脚本仍留在 `Assets/Art`，没有随本次归档删除。
