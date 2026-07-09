# Tasks: formalize-equipment-visual-workbench

## 0. 接续前提

- [x] 建立独立 change，避免把换装生产化继续塞进 foundation change。
- [x] 记录 AIBridge 当前已改动点、已知问题和下一步验证入口。
- [x] 新会话开始后先确认 Unity 当前进程、heartbeat、CLI lock、scene lock、commands/results 目录都处于干净状态。

## 1. AIBridge 收口

- [x] `bridge.py` 加固 CLI 锁 stale 判定：持锁 pid 不存在时应清理。
- [x] `bridge.py` 加固结果读取：结果文件读取重试，并在超时边界最后复查一次。
- [x] `Scene.Open.cs` 改为打开场景后尝试设为 active。
- [x] `Scene.Open.cs` 进一步改为不把 Unity `SetActiveScene` 的 false 结果直接当作场景打开失败。
- [x] 重新执行 `assets-refresh`，确认包侧新代码已被 Unity 编译并装载。
- [x] 重新执行 `scene-open` 打开 `Assets/Scenes/EquipmentSystemDemo.unity`，外层必须返回 `success`。
- [x] 用 `script-execute` 回读 active scene，必须是 `Assets/Scenes/EquipmentSystemDemo.unity`。
- [x] 验证 `editor-application-set-state` 进入/退出 PlayMode 不再外层超时、不留 `.cli.lock`。

## 2. 换装工作台运行态验收

- [x] 进入 `EquipmentSystemDemo`。
- [x] 确认 `EquipmentWorkbenchController` 存在并加载正式目录。
- [x] 确认角色网格包含人类、精灵、矮人、兽人、地精，格子显示 idle 首帧。
- [x] 确认动作切换、方向切换放在左侧，不挤出屏幕。
- [x] 确认中央预览不被 UI 遮挡。
- [x] 确认右侧装备类型可切换。
- [x] 确认右侧装备网格显示装备 icon 或首帧，并高亮当前装备。
- [x] 确认默认字体是 `Silver`。

## 3. 数据与目录复核

- [x] 规则数据与表现资源分层复核：装备规则数据不应混入表现层目录。
- [x] 表现资源复核：装备表现资源位于 `Equip/Visual` 或等价正式目录。
- [x] 中文命名复核：正式项目侧资产使用中文名；稳定 ID、动画键和代码符号保留 ASCII 时必须有兼容理由。
- [x] 确认没有把字符串测试项、测试 UI 项或 GAS 占位字符串当作正式装备定义。
- [x] `Assets/Tests` 保持不存在或为空，不为本轮机械新增测试文件。

## 4. 最终验证

- [x] `npx openspec validate formalize-equipment-visual-workbench --strict` 通过。
- [x] AIBridge `console-get-logs` 最近窗口内 Error 为空。
- [x] AIBridge `console-get-logs` 最近窗口内 Exception 为空。
- [x] 更新本 change 的 `handoff.md` 和必要验证记录。
