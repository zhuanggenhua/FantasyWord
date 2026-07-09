# Design: complete-composite-sandbox-character-runtime

## Summary

这次 change 不是增加业务，而是把已经确认必须存在的三块框架层能力补成正式闭包：

- `控制组进阶`
- `RTS 命令链`
- `GAS 完整合同`

三者必须一起看，因为它们共同决定“谁发起、谁拥有、谁裁决、结果写到哪里”。

## Architectural Position

正式分层保持不变：

- 世界规则与长期数据：`GameCore` 对齐 `2DRPGEngine`
- 角色执行与动作模式：`GameCore` 吸收 `TopDownEngine`
- 规则层：`EX-GAS`
- 控制组与订单链：吸收 `RTS Starter Kit` 思路，落到 `GameCore` 正式命令运行时
- 工具层：`YokiFrame`

禁止做法保持不变：

- 不新造 `Adapter/Facade/Wrapper/Compatibility`
- 不把 TopDown manager、RTS 全局控制器或 GAS manager 变成项目生命周期真相
- 不为了“先能跑”继续长期保留 legacy 与新运行时并行改同一事实

## Track A: Control Group Runtime

控制组不是 UI 选择器，而是正式输入目标与控制权闭包。

正式要求：

- 控制组必须有显式成员、主控成员、当前焦点和控制权判定。
- 命令分发必须区分“所有成员都执行”和“只由主控成员执行”的类别。
- 控制组成员变化、失控、死亡、复活、变形、AI 接管和读档恢复必须进入同一正式拥有者。
- UI 只消费控制组快照，不直接改内部成员集合。

控制组不等于未来联机，但必须保留主机权威兼容边界：

- 输入来源是谁。
- 命令 actor 是谁。
- 哪些成员被批准执行。
- 命令结果最终写到哪个 owner。

## Track B: RTS Command Runtime

当前已有 `GameCommandContext`、`PlayerCommandRequest` 和一批正式命令入口，但还不等于完整 RTS 命令链。

本 change 要补成的正式闭包：

- 显式订单对象，而不是 UI 回调直接改世界。
- 单位/控制组可区分覆盖命令与追加命令。
- 停止命令是正式订单，而不是临时打断脚本。
- 批量命令可以一次下发，但成员逐个裁决距离、状态、权限和目标合法性。
- 队列与队形语义进入正式合同，不由调用方各自猜测。

本 change 不引入：

- 3D NavMesh
- RTS 全局 GameController
- 采集/建造业务
- 网络 orders / RPC

## Track C: GAS Full Contract

当前状态已经不是“完全没接 GAS”，但也不能误报为“已经完成”。

当前可用事实是：

- 正式属性读取、资源写入口、通知、零血死亡判定和当前值存档已优先走 `CharacterBase + ASC`。
- 规则与动作执行分工已经定成 `GAS 管规则，GameCore/TopDown 管执行`。
- 仍存在 legacy 缓冲、过渡镜像、部分持续效果执行壳和历史闭包残留。

本 change 的目标是把“已部分接入”推进到“正式完成替换边界”：

- 属性真相必须唯一。
- 冷却、消耗、标签阻断和持续效果规则必须有唯一裁决口。
- 能力授予、压制、替换、撤回、存档和读档恢复必须走统一正式链路。
- legacy `Stats/currentStats`、旧 effect/runtime 镜像和仅用于过渡的 fallback 必须压缩到迁移与兼容最小面，不能继续参与正式运行时裁决。

仍保持的边界：

- `GAS` 不直接执行移动、武器、受击、投射物、召唤或反馈。
- `GameplayEffectAsset / GameplayEffectSpec` 继续只承载规则和映射。
- 动作结果仍由 `GameCore` 正式拥有者执行。

## Verification Strategy

这次 change 的完成证据必须同时满足：

1. OpenSpec delta 写清正式要求，不再把这三块描述成后续项。
2. 静态门禁能拒绝双真相和回潮。
3. 必要 smoke 覆盖：
   - 控制组成员命令分发
   - RTS 正式订单链关键路径
   - GAS 存读档恢复与对象池/禁用清理关键路径
4. Unity Console 在验证窗口内没有新的 Error/Exception。

默认不为每个小 API 补机械单测；只补必要 smoke 和高风险合同验证。
