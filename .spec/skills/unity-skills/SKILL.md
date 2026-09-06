---
name: unity-skills
description: 通过本项目已安装的 UnitySkills 包自动化 Unity Editor；用于场景、对象、脚本、资源、材质、测试和批量操作，不复制上游模块文档。
---

# UnitySkills 项目薄入口

本文件只裁决 FantasyWord 使用 UnitySkills 的项目边界。通用协议、REST schema、模块说明和官方链接不在 `.spec` 重复保存，统一读取本地包内资料：

- 上游入口：`Packages/com.besty.unity-skills/unity-skills~/SKILL.md`
- 模块索引：`Packages/com.besty.unity-skills/unity-skills~/skills/SKILL.md`
- 模块资料：`Packages/com.besty.unity-skills/unity-skills~/skills/<module>/SKILL.md`
- 官方链接索引：`Packages/com.besty.unity-skills/unity-skills~/references/*.md`

## 项目边界

- 使用前先按 `.spec/skills/before-you-code/SKILL.md` 锁定问题对象、真相来源、目标入口 / 环境和验收口径。
- UnitySkills 只操作当前 FantasyWord 项目的唯一 Unity Editor；不得为绕过阻塞另起第二个 Editor。
- Unity 未打开时，`.spec/tools/unityskills-ensure.mjs` 只有在本机 `Library/UnitySkills/cli_config.json` 明确启用冷启动绑定后才允许打开当前项目；该配置的职责和字段口径由 `.spec/skills/unity-cli/SKILL.md` 承载。
- 准确参数、返回值、权限模式和可用 skill 以本机 UnitySkills server 的 `/health`、`/skills`、schema / dryRun 输出和包内 `SKILL.md` 为准。
- 修改脚本、资源、Prefab、场景或包配置前，继续遵守 `.spec/rules/system.md`、`.spec/knowledge/standards/unity-serialization-safety.md` 和对应功能规范。
- 批量写入、Prefab / Scene 变更、删除、高风险包操作或可能触发 Domain Reload 的动作，必须先做 dryRun / 计划检查，并按项目规则说明影响范围。
- AIBridge 仍是本项目既有专项验证链；需要沿用 AIBridge 的任务继续读 `.spec/knowledge/features/project/AIBridge常用命令.md`，不能用 UnitySkills 成功回执替代业务验收。

## 不承载内容

- 不在 `.spec/skills/unity-skills/` 内保存上游 `skills/`、`references/`、示例、脚本或完整模块文档。
- 不把 UnitySkills 通用模块注册成多个 FantasyWord 项目 skill；FantasyWord 只有本薄入口一个 `unity-skills` 项目 skill。
- 不用 UnitySkills 的可执行成功替代业务完成声明；编译、场景回读、PlayMode、截图或玩家效果仍按目标验收口径单独证明。

## 读取路由

- 场景 / 对象 / Prefab / 资源自动化：先读包内 `skills/scene`、`skills/gameobject`、`skills/prefab`、`skills/asset` 对应 `SKILL.md`。
- 脚本、程序集、测试和编译反馈：先读包内 `skills/script`、`skills/asmdef`、`skills/test` 对应 `SKILL.md`。
- 架构、模式、脚本角色、序列化手改：只在进入对应代码或 YAML 修改时，按需读取包内 advisory 模块。
- UGUI / UI Toolkit / TMP：先读 `.spec/skills/unity-ui-development/SKILL.md`，再按需读取包内 UI 模块。
- UPM 包查询、安装、移除、升级：先读 `.spec/skills/unity-package-management/SKILL.md`，再按需读取包内 `skills/package` 和 `skills/project` 模块。

