---
name: lessons
description: 反复错误候选池：同类问题第二次出现时记录，稳定复用后升级为正式规范、硬红线或 skill。
metadata:
  type: doc
  status: 已交付
---

# 经验教训（Lessons Learned）

本文件记录反复踩坑，不记录单次偶发问题。它是规范升级的候选池，不是待办清单。

## 收录准入

- 同类问题第二次出现才收录，避免把偶发噪音写成长期规则。
- 来源可以是用户纠偏、review 退回、known gaps、测试复现、排查复盘。
- 不收普通待办；待办放任务卡或 openspec。
- 不收项目常识；已稳定成立的规则直接进 `standards/`、`rules/` 或对应 skill。

## 条目格式

```markdown
### <一句话规避规则>
- 日期：YYYY-MM-DD
- 现象：踩了什么坑、复发几次
- 根因：为什么发生
- 规避：下次怎么做，可验证，不写口号
- 来源：用户纠偏 / review 报告 / known gaps / 测试证据
- 状态：候选 / 已升格 -> <落点>
```

## 升级路径

- 第一次：只在当轮汇报或复盘里说明，不进长期规范。
- 第二次：追加到本文件，作为候选经验。
- 第三次左右：必须做升级决策，三选一：
  - 进 `.spec/rules/system.md`：成为硬红线。
  - 进 `.spec/knowledge/standards/`：成为长期做法规范。
  - 进 `.spec/skills/`：成为可复用工作流。
- 升级后保留原条目，并标注“已升格 -> <落点>”。

## 条目

### Unity 阻塞弹窗必须按既定默认动作继续任务
- 日期：2026-07-10
- 现象：场景恢复、外部修改和普通确认弹窗多次让自动化停下，并重复向用户询问已经明确过的选择。
- 根因：弹窗处理口径只覆盖恢复备份，没有统一覆盖外部修改场景和其它普通模态确认。
- 规避：外部修改场景直接选择 `重新加载 / Reload`；其它普通阻塞弹窗点击默认或主按钮继续。涉及删除本地数据或覆盖未知未保存内容时，仍按既有安全红线先取证。
- 来源：用户纠偏。
- 状态：已升格 -> `.spec/knowledge/features/project/开发与验收规范.md`、`.codex/skills/aibridge/SKILL.md`

### 视觉测试层不得越权改正式生成器和配置资产
- 日期：2026-07-10
- 现象：为了让换装工作台尽快显示武器和动作，计划外改动了帧数据、UV 生成/同步工具和装备资产；其中 `战斧.asset` 被添加了用户未要求的 `SlashAttack` 序列。
- 根因：把“完成视觉测试层”的结果目标错误理解成了可以补写正式内容数据，没有先限定允许修改的文件集合，也没有在发现配置缺口时停止并向用户确认是否扩大范围。
- 规避：视觉测试任务默认只允许修改测试场景、工作台 UI 和只读预览代码；`Assets/GameData/EquipmentSystem` 下的正式配置、`GeneratedUV`、第三方素材及其 `.meta`、动画控制器、生成器和同步工具全部视为禁止修改区。若现有数据不足以展示，必须报告具体缺口并停止，只有用户当轮明确授权数据制作或再生成后才能继续。
- 恢复门禁：清理素材差异前必须同时检查 `git check-attr filter` 和 HEAD 原始 Blob。HEAD Blob 是 LFS 指针时，必须经过 `git lfs smudge` 或其它 LFS 感知方式还原真实对象；路径虽然命中现行 LFS 规则、但 HEAD 仍是历史普通图片 Blob 时，不得擅自转换文件或修改 `.gitattributes`，应以 `git hash-object --no-filters` 与 HEAD Blob 的原始哈希一致作为“内容未变化”证据，并把 `git status` 的假修改单独说明。
- 来源：用户纠偏、`2c1c5e21` 与 `ade3a56f` 数据层差异、当前工作区 diff。
- 状态：已升格 -> `openspec/specs/equipment-visual-workbench/spec.md`、`.spec/knowledge/features/project/bugs/换装测试回归矩阵.md`
