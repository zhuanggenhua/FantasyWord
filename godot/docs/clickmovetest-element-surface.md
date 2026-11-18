# ClickMoveTest 原地表反应接入边界

从锁定的 Unity 版本提取规则 Tilemap、覆盖来源和元素 Registry 数据。模式仅覆盖首批与原草地和水熄火验证器相关的作者规则。五个覆盖来源按原优先级升序读取，首个可映射的覆盖胜出；底层 Dirt 和上层 Grass 不是同一字段。外部提取文件不进仓库。

原点火验证器将 Fire 点施加于实际地形格；运行时另接通原可通行四邻与锥形判定，供 20010 喷火技能任务调用。没有自动火势蔓延。燃烧按 scaled 0.1 秒步长消费，等强度不会刷新 KeepStronger；自然燃尽移除覆盖而非改写底图。已有火的格接受 Water 时立即灭火、加 Wet 并发出 Steam，不走自然到期。Wet 和 Burning 的有效代价按原倍率取样；没有更改现有静态寻路图或自行添加水技能。

`test_clickmovetest_element_surface.gd` 在同一 Entry 中经原地图验证点施加和锥形范围。设置 `FORMAL_SURFACE_RULES` 和 `FORMAL_SURFACE_ASSETS` 以使用私有精确规则和覆盖。

## 20010 喷火运行时边界

模块装配仍需原地图规则、角色动作和明确的装备槽位。原验证器把 20010 装进索引 0，对应 Q 的归一化动作 `Gameplay/FireAbility1`，不是默认赠送技能。时间轴 65 帧；第 1 帧开始按 3 帧间隔提交 20 次地表火元素；1、10、20、30、40、50、60 帧用原层 128 多边形请求伤害效果 2003。每次任务独立读取执行帧角色根和实际朝向。瞬时伤害走现有正式目标、属性与受击逻辑，无推力；按键松开分别中断准备或结束后摇。普攻、蓄力和喷火共用同一个角色的攻击标签 3003，未验收原 ECS 中多个激活请求同时到达的排序。

`test_clickmovetest_flamethrower_batch.gd` 可通过 `FORMAL_FIRE_BATCH`（原图集与规则目录）、`FORMAL_SURFACE_ASSETS`（私有覆盖与规则 JSON）运行原地图验证。尚未接入火焰 Tilemap、跨层光照材质或 Unity 画面对照；不是完整喷火表现或整项目交付。


## 独立的燃烧接触伤害

原 `TerrainSurfaceDamageSystem` 读取活动地图上角色当前根所在格；不是给喷火命中的角色挂一个伤害状态。全局每 0.5 秒采样，暂停不累计。通过 `start_surface_contact_damage` 装配同一实际地图和注册的训练假人；玩家属性和受击钩子必须由调用者提供已有的正式拥有者。仅 Burning 有效，发出 1 点魔法的正式效果请求，零速度，不添加攻击 Cue。当前场景使用独立效果消费阶段，采样不直接改生命；自伤与空来源允许，自伤不推。水熄火后，采样不再为该格提交伤害。随场景卸载丢弃待消费和地图计时，不在刷新后重播伤害；没有验收其他场景、角色注册或原 Unity 全局 ECS 的跨卸载队列顺序。

`test_clickmovetest_flamethrower_batch.gd` 用原地图及图集验证 Q 后真实玩家与假人进入不同燃烧格、各自受伤、暂停、安全阶段消费与局部熄火。`test_terrain_surface_damage_system.gd` 独立覆盖补帧、目标去重、空来源、死者和地图生命周期。

## 原喷流与音频

在正式 20010 槽位和时间轴装配之后，`bind_flamethrower_cues(owner, png_path, ogg_path)`
接收私人保存的原 PNG 和 OGG 并核对锁定散列。素材不在本分支重新分发；缺失或不匹配时不合成替代素材。
原 Cue 在显示阶段激活：第 1 帧挂在施法者根，保留原挂载初始旋转覆盖顺序；
后续监听同一角色的 `target_direction_changed`，不是命中所读取的身体方向。
原 8 帧序列每秒 14 帧，PPU 8，左中枢轴，Jet 偏移 +0.35；第 60 帧或取消时移除喷流。
音轨走非空间 `GameplaySoundFX` 单次触发，原通道默认增益 0.5，预热四声道并允许重叠，
Cue 移除不截断音轨。宿主可用通道偏好设置覆盖音量，独立主音量不在此改动。

验收环境变量：用 `FORMAL_FLAMETHROWER_CUE` 传入两个原素材同目录给实际入口集成测试；
独立测试用 `FORMAL_FLAMETHROWER_PNG` 与 `FORMAL_FLAMETHROWER_AUDIO` 两个文件路径。
无头测试验证真实资产加载、播放生命周期和显示节点配置；未比较 Unity 原材质、跨层排序、
渲染截图或实机听感。地表火焰 Tilemap 的动画和渲染另行迁移。
