---
name: unity-package-management
description: Unity Package Manager（UPM）包查询、安装、移除、升级和版本裁决的 FantasyWord 项目入口；用户说装包、UPM、添加 com.unity.* 或改 manifest 时使用。
---

# Unity Package Management（项目适配）

本 skill 只管 Unity Package Manager（UPM）层面的包选择、查询、安装、移除和升级。它不负责插件业务接入，不替代 `.spec/knowledge/features/project/第三方插件接入清单.md` 的插件真相源登记，也不直接修改第三方插件源码。

已吸收的通用增量是：Unity CLI 不负责 UPM；包变更优先走 UnitySkills 包模块或 Unity Editor PackageManager 正式入口；不要手改 `Packages/manifest.json` 作为默认安装 / 移除方案；安装、移除和升级会触发包解析、程序集重载和可能的编译变化。

## 默认路径

FantasyWord 已安装 UnitySkills，本项目默认优先用 UnitySkills 的包模块执行 UPM 查询和变更：

- 查询已装包：`project_get_packages` 或 `package_list`
- 检查单个包：`package_check`
- 查询依赖或版本：`package_get_dependencies` / `package_get_versions`
- 安装包：`package_install`
- 移除包：`package_remove`
- 刷新包缓存：`package_refresh`

准确参数、权限模式和返回值以 `.spec/skills/unity-skills/SKILL.md` 指向的 UnitySkills server `/skills`、schema / dryRun 输出和包内资料为准，不从本文猜参数。包模块资料入口：

- `Packages/com.besty.unity-skills/unity-skills~/skills/package/SKILL.md`
- `Packages/com.besty.unity-skills/unity-skills~/skills/project/SKILL.md`

## 前提锁定

准备安装、移除或升级包前，必须先锁定：

1. **现实目标**：为什么要改这个包，解决哪个项目问题。
2. **真相来源**：目标包官方文档、package id、当前 `Packages/manifest.json`、`Packages/packages-lock.json` 和 `.spec/knowledge/features/project/第三方插件接入清单.md`。
3. **目标入口**：优先 UnitySkills 包模块；只有 Editor 不适合、UnitySkills 不可用且用户明确需要无头流程时，才评估 Unity Editor PackageManager 的备用路线。
4. **验收口径**：包解析成功、manifest / lockfile 变化可解释、Unity 编译通过，必要时对应功能 smoke 通过。

## 禁止场景

- 不得因为官方资料推荐某包，就直接安装；先判断 FantasyWord 是否真的需要。
- 不得手写修改 `Packages/manifest.json` 作为默认安装 / 移除方案。
- 不得伪造或手写 `Packages/packages-lock.json`；lockfile 只能由 Unity Package Manager 解析后更新。
- 不得绕过 `.spec/knowledge/standards/unity-serialization-safety.md`、`.spec/tools/unity-yaml-guard.mjs`、插件台账和项目包边界裁决。
- 不得安装商业化、广告、联机、云服务、语音、XR、平台发布相关包，除非用户当轮明确把目标切到对应领域。
- 不得把包安装成功说成业务接入完成；迁移、复制、接入和启用必须分开汇报。
- 不得在已打开 Editor 的情况下另起第二个 Editor 来跑无头包脚本。

## 允许的无头候选

只有在 UnitySkills 不适合、Editor 没有打开、用户明确需要非交互包变更，且本轮已经读过目标包官方文档与 Unity PackageManager 当前文档时，才允许评估无头 `UnityEditor.PackageManager.Client` 模式。

该模式是备用方案，不是默认流程；能用 UnitySkills 包模块时不要新建 bootstrap 脚本。若使用备用方案，必须：

- 使用当前项目匹配的 Unity Editor binary。
- 临时 C# 脚本放在 `Assets/Editor/` 或 Editor-only assembly。
- request 完成后自行以明确状态退出。
- 执行后验证 `Packages/manifest.json`、`Packages/packages-lock.json` 和 Unity 编译结果。

## 汇报要求

包操作完成后必须说明：

- 改了哪个包，以及现实目的。
- 入口是 UnitySkills 包模块、Unity Editor PackageManager 备用路线，还是只做静态读取。
- `manifest.json` / `packages-lock.json` 的变化。
- Unity 包解析、编译或 smoke 验证结果。
- 若只是安装包，还不能称为功能接入完成。

