# Project Context

## 项目

- 名称：`FantasyWord`
- Unity 工程：`C:\Gamedev\Unity\Project\FantasyWord`
- Unity 版本：`6000.3.10f1`
- 渲染管线：URP 2D
- 输入：Unity Input System

## 当前方向

`FantasyWord` 是单机优先的俯视角开放世界像素游戏，强调高自由度、探索、交互、采集/制作、角色成长、战斗、物品和世界状态积累。

当前项目不是旧 `FantasyWorld` 恢复任务的延续。旧恢复记录、旧任务计划和旧用户故事只作为历史事实线索；新游戏目标、玩法流程和验收口径必须重新定义。

联机方向更新为长期候选：FishNet 主机权威的有限人数合作。当前阶段仍优先完成单机核心、插件接入、目录治理、AI 规范、Mod 兼容边界和可验证工程地基；不接入网络包、不创建网络目录或网络占位层。

## 固定技术站位

- 编辑器自动化：AIBridge
- 技能/状态替换方向：EX-GAS（当前专项推进中；必须替换同职责旧入口，不得并行）
- 基础设施：YokiFrame
- Inspector 辅助：当前未锁定固定第三方 Inspector 辅助插件；如后续重新接入 NaughtyAttributes，先更新 `docs/ai/第三方插件接入清单.md`
- 异步流程：UniTask
- 音频后端：BroAudio
- 像素素材来源：MiniFantasy 是正式美术基线，当前工程已有像素素材按来源与授权复核后纳入
- 装备/换装模块：`Assets/Scripts/Presentation/EquipmentSystem`

## AI 友好原则

- 规则真相优先在 C# runtime 和结构化数据中，不藏在场景层级或不可 diff 的编辑器状态里。
- 第三方插件必须由项目正式拥有者闭包统一接入，玩法层不散落依赖插件 API，也不额外再造 facade、wrapper 或 adapter。
- 关键配置、技能、存档、验证入口必须可搜索、可 diff、可批量生成、可自动验证。
- 不为了未来联机、mod 或大型编辑器提前引入当前阶段不需要的复杂度；但会改变世界的玩法规则必须有单机也成立的正式入口，便于 Mod 审计和未来 FishNet 薄适配。
- 目录重整要保护 `.meta` 和 GUID；仍有参考价值但不进入正式链路的内容优先归档，不直接删除。
