# Decisions（决策记录）

这里记录架构、流程、规范层的决策。只新增，不改写旧决策；如果决策被取代，新建一条说明替代关系。

## 决策索引

- [0001-EX-GAS 资源身份 owner](0001-ex-gas-resource-identity-owner.md)
- [0002-ResourceSystem 资源 owner 边界](0002-resource-system-owner-boundary.md)
- [0003-UI 菜单与按钮 owner 边界](0003-ui-menu-owner-boundary.md)
- [0004-音频运行时 owner 边界](0004-audio-runtime-owner-boundary.md)
- [0005-存档与数据库稳定身份边界](0005-persistence-database-stable-identity.md)
- [0006-任务日志进度生命周期 owner 边界](0006-quest-journal-progress-lifecycle.md)
- [0007-条件监听生命周期 owner 边界](0007-conditional-listener-lifecycle.md)
- [0008-命令异步执行 owner 边界](0008-command-async-execution-boundary.md)
- [0009-UI 菜单异步按钮 owner 边界](0009-ui-menu-async-button-boundary.md)
- [0010-角色任务浮标监听生命周期 owner 边界](0010-character-actor-quest-icon-lifecycle.md)
- [0011-换装表现资源 owner 边界](0011-equipment-presentation-resource-owner.md)
- [0012-UI 控制器按键提示生命周期 owner 边界](0012-ui-controller-button-lifecycle.md)
- [0013-HUD 当前控制角色监听生命周期 owner 边界](0013-hud-current-controlled-character-lifecycle.md)
- [0014-UI 菜单当前控制角色监听生命周期 owner 边界](0014-ui-menu-current-controlled-character-lifecycle.md)
- [0015-对话 HUD 监听生命周期 owner 边界](0015-dialogue-hud-lifecycle.md)
- [0016-朝向跟随表现监听生命周期 owner 边界](0016-follow-target-direction-lifecycle.md)
- [0017-角色信息面板监听生命周期 owner 边界](0017-ui-character-info-lifecycle.md)
- [0018-EX-GAS 动画 Cue 驱动 owner 边界](0018-ex-gas-animation-cue-driver-owner.md)
- [0019-主菜单 Cancel 输入监听生命周期 owner 边界](0019-main-menu-cancel-input-lifecycle.md)
- [0020-换装表现桥接显式渲染器 owner 边界](0020-equipment-presentation-explicit-renderer-owner.md)
- [0021-Transform 抖动协程 owner 边界](0021-transform-shaker-coroutine-owner.md)
- [0022-对话消息框跳字协程生命周期 owner 边界](0022-dialogue-message-box-coroutine-lifecycle.md)
- [0023-Mod 配置状态 owner 边界](0023-mod-config-state-owner-boundary.md)
- [0024-等待命令延迟 owner 边界](0024-command-wait-player-loop-owner.md)
- [0025-临时 UI 动画协程生命周期 owner 边界](0025-transient-ui-coroutine-lifecycle.md)
- [0026-音频播放生命周期 owner 边界](0026-audio-playback-lifecycle.md)
- [0027-宝箱首次开启防重入边界](0027-chest-first-open-reentry.md)
- [0028-换装工作台按钮监听 owner 边界](0028-equipment-workbench-button-listener-owner.md)
- [0029-HUD 能力失败提示生命周期 owner 边界](0029-hud-ability-message-lifecycle.md)
- [0030-主动能力动画驱动 owner 边界](0030-active-ability-animation-driver-boundary.md)
- [0031-对话通道等待任务生命周期 owner 边界](0031-dialogue-channel-await-task-lifecycle.md)
- [0032-地图复活延迟协程生命周期 owner 边界](0032-map-respawn-coroutine-lifecycle.md)
- [0033-AnimationController 显式依赖 owner 边界](0033-animation-controller-explicit-references.md)
- [0034-EquipmentRenderer 显式动画依赖 owner 边界](0034-equipment-renderer-explicit-animation-owner.md)
- [0035-拾取物延迟禁用 owner 边界](0035-pickable-item-delayed-disable-owner.md)
- [0036-场景命令触发器帧延迟 owner 边界](0036-command-trigger-frame-delay-owner.md)
- [0037-水面倒影显式反射来源 owner 边界](0037-water-reflection-explicit-source-owner.md)
- [0038-受击表现监听者系统就绪边界](0038-damage-presentation-listener-readiness.md)（访问形式表述已由 0046 取代）
- [0039-区域音频系统就绪边界](0039-audio-region-system-readiness.md)（访问形式表述已由 0046 取代）
- [0040-MovementZone 玩家系统就绪边界](0040-movement-zone-player-system-readiness.md)（访问形式表述已由 0046 取代）
- [0041-命令上下文玩家系统就绪边界](0041-command-context-player-system-readiness.md)（访问形式表述已由 0046 取代）
- [0042-GameManager 系统注册表查询失败语义边界](0042-game-manager-system-registry-failure-semantics.md)（仅限查询 API 合同；调用点审计解释已由 0050 收紧）
- [0043-条件当前角色与背包系统就绪边界](0043-conditional-current-owner-system-readiness.md)（访问形式表述已由 0046 取代）
- [0044-AddExperience 命令目标解析边界](0044-add-experience-command-target-owner.md)（访问形式表述已由 0046 取代）
- [0045-UI 菜单上下文系统就绪边界](0045-ui-menu-context-system-readiness.md)（访问形式表述已由 0046 取代）
- [0046-参考流程优先的 GameManager 系统访问审计边界](0046-game-manager-system-access-boundary.md)
- [0047-角色死亡尸体背包转移参考流程边界](0047-character-death-corpse-inventory-reference-flow.md)
- [0048-持久化对象销毁参考流程边界](0048-persistable-destroy-persistence-reference-flow.md)
- [0049-角色死亡与控制重算 PlayerSystem 参考流程边界](0049-character-player-system-reference-flow.md)
- [0050-参考流程审计结论纠偏边界](0050-reference-flow-audit-correction.md)
- [0051-玩家结果型命令必需目标边界](0051-player-result-command-required-target.md)
- [0052-显式目标与策略命令必需配置边界](0052-configured-target-command-required-reference-flow.md)
- [0053-地图结果链必需配置参考流程边界](0053-map-result-reference-flow.md)
- [0054-任务日志结果链必需任务资产参考流程边界](0054-journal-result-reference-flow.md)
- [0055-背包结果写入参考流程边界](0055-inventory-result-reference-flow.md)
- [0056-持久化实例化必需配置参考流程边界](0056-persistence-instantiation-required-contract.md)
- [0057-主玩家控制目标必需配置参考流程边界](0057-player-primary-control-target-required-contract.md)
- [0058-库存多步交易合同边界](0058-inventory-transaction-contract.md)
- [0060-库存奖励写入合同边界](0060-inventory-loot-reward-contract.md)
- [0061-编辑器验证工具与一次性迁移边界](0061-editor-validation-tooling-boundary.md)
- [0062-旧规则型持续效果边界](0062-legacy-temporal-rule-effect-boundary.md)
- [0063-变形感染规则 Formal GAS 编号校验边界](0063-character-alteration-formal-gas-code-validation.md)
- [0064-能力持续效果 Formal GAS 编号校验边界](0064-temporal-ability-effect-formal-gas-code-validation.md)
- [0065-能力持续效果读档恢复校验边界](0065-temporal-ability-effect-restore-validation.md)
- [0066-角色读档槽位覆盖边界](0066-character-loadout-restore-overwrites-runtime-slots.md)
- [0067-换装生成设置与静态门禁 owner 边界](0067-equipment-generation-settings-static-gate-owner.md)
- [0068-当前运行时状态保存必需数据库引用边界](0068-save-current-state-required-database-reference.md)

## 新决策模板

```markdown
# NNNN-短标题

- 日期：YYYY-MM-DD
- 状态：已采纳 / 已取代 / 废弃
- 背景：
- 决策：
- 影响：
- 替代关系：
```

