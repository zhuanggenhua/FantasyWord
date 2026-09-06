---
name: unity-cli
description: Unity 官方 unity 命令行工具的 FantasyWord 项目入口；用于查询 CLI/Editor 能力、打开当前项目、读取绑定配置和明确授权后的无头验证候选，不替代 UnitySkills。
---

# Unity CLI（项目适配）

本 skill 只管 Unity 官方 `unity` 命令行工具。它不是 UnitySkills REST，也不是传统 `Unity.exe -batchmode` 的默认入口。FantasyWord 默认仍用 `.spec/skills/unity-skills` 做已打开 Editor 的结构化自动化，用既有项目脚本和 AIBridge 证据链处理历史专项验证。

上游 Unity CLI 资料只作为候选能力参考；执行时以本机当前 `unity --help`、项目 `ProjectSettings/ProjectVersion.txt` 和本文件为准。

## 先查本机真实能力

准备用 Unity CLI 前，必须先查当前命令是否存在、版本和帮助，不按上游最新版假设命令可用：

```powershell
Get-Command unity -ErrorAction SilentlyContinue
unity --version --format json
unity --help
```

如果要使用子命令，先读对应 help：

```powershell
unity open --help
unity editors --help
unity projects --help
```

命令不存在、help 不含目标子命令或输出不能机器读取时，结论是当前 CLI 能力不足；不得换成手写脚本或第二个 Editor 冒充同一条 Unity CLI 路线已经完成。

## 本机绑定配置

`Library/UnitySkills/cli_config.json` 是本机 UnitySkills 冷启动绑定状态，不是 `.spec` 规范正文，也不进入 Git 长期知识。它只回答“这台机器用哪个 Unity CLI / Editor 打开当前项目”；本 skill 才回答“什么时候允许用、什么时候必须停下”。

配置缺失不代表 `unity-cli` 或 `unity-skills` skill 缺失；现实后果只是 `.spec/tools/unityskills-ensure.mjs` 不能在 Unity 未打开时自动冷启动当前项目。此时应先报告“本机缺少 UnitySkills CLI 绑定配置”，再按本机真实路径补 `Library/UnitySkills/cli_config.json`，不得把机器路径写进 `.spec` 文档正文。

最小配置字段：

```json
{
  "schemaVersion": 1,
  "enabled": true,
  "cliPath": "<本机 Unity CLI 或 Editor 路径>",
  "cliVersion": "<cliPath 对应版本>",
  "projectPath": "<当前项目绝对路径>",
  "editorVersion": "<ProjectSettings/ProjectVersion.txt 中的 Unity 版本>",
  "boundAt": "<ISO-8601 UTC 时间>",
  "features": {
    "coldStart": true,
    "openArgs": true,
    "cliTest": true,
    "cliRun": false,
    "cliBuild": false
  }
}
```

若无法确认 `cliPath` 存在、`editorVersion` 与当前项目版本匹配，或 `unity open --help` 不支持传参，则不得启用 `features.coldStart`；只能保留查询能力并说明自动冷启动未启用。

## 允许用途

- 查询 Unity CLI、Editor 安装、默认 Editor 和 Hub 项目注册表。
- 在当前项目没有已打开 Editor 时，用已绑定 Editor 路径打开 FantasyWord。
- 读取或验证 UnitySkills CLI 绑定配置。
- 当轮明确需要 Unity CLI，且本机 help 证明命令存在时，作为无头测试、构建或一次性 batch 的候选入口。

当前项目绑定配置检查：

```powershell
if (Test-Path Library/UnitySkills/cli_config.json) { Get-Content -Raw Library/UnitySkills/cli_config.json }
node .spec/tools/unityskills-ensure.mjs --check-only
```

只有同时满足以下条件，才能把 Unity CLI 作为本轮 Unity 入口：

1. 本轮目标确实是查询、打开当前项目，或用户明确要求无头测试 / 构建候选。
2. `unity --help` 或子命令 help 证明目标命令存在。
3. 当前项目没有已经打开的 Editor，或本轮目标只是安全查询，不会改变 Editor / 项目状态。
4. 不绕过 `.spec/skills/unity-skills`、AIBridge 既有验证链、包管理裁决和 Unity 序列化安全规则。

## 禁止用途

- 不得用 Unity CLI 抢 `.spec/skills/unity-skills` 的默认 Editor 自动化入口。
- 当前项目已有 Editor 或 `Temp/UnityLockfile` 被持有时，不得用 Unity CLI 另起一个 Editor 来绕过阻塞。
- 不得自行安装、升级、卸载 Unity CLI、Unity Editor、Editor modules 或 Unity Pipeline 包；这些属于用户明确授权动作。
- 不得为了使用上游资料里的新命令，擅自升级本机 CLI。
- 不得用 Unity CLI 直接增删 UPM 包来绕过 `.spec/skills/unity-package-management`。
- 不得把 Unity CLI 的成功退出码单独解释成测试完整通过；测试必须有可回读结果文件或明确机器输出。

## 与其它入口分工

| 场景 | 使用入口 |
| --- | --- |
| 已打开 Editor 的场景、对象、Prefab、资源、Console、批量操作 | `.spec/skills/unity-skills` |
| 包查询、安装、移除、升级和 manifest / lockfile 裁决 | `.spec/skills/unity-package-management` |
| 既有 AIBridge 专项验证链、历史 AIBridge smoke、Console/截图证据 | `.spec/knowledge/features/project/AIBridge常用命令.md` |
| 查询/打开 Unity 项目、列 Editor、检查 CLI 能力 | 本 skill |
| 当前项目脚本已有明确验证入口 | 对应 `scripts/Invoke-*.ps1` 或 `.spec/tools/*.mjs` |

## 命令规则

- 需要机器读取输出时，优先使用 `--format json` 或命令支持的 JSON 参数。
- 需要非交互执行时，必须显式使用 help 中存在的非交互参数。
- 命令失败时先读 stdout / stderr / help / 项目日志，不猜测命令语义，不换第二套 Unity 工具冒充成功。
- 如本机 CLI 版本低于上游资料描述，按本机 help 收窄能力；上游只作为升级候选，不作为当前可执行事实。
