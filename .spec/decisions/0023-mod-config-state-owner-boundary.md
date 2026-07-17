# 0023-Mod 配置状态 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `Assets/Scripts/GameCore/Runtime/Mods` 是从 Chris 吸收的最小 Mod 地基，负责本地 Mod 目录扫描、zip 解包、启停状态、版本校验和外部 catalog 加载。
  - 当前项目没有继续引入 Chris 全套 Config 框架，`ModConfig` 是项目侧 JSON 配置 owner。
  - `GetModState()` 原先会在读取状态时创建默认记录，并在遇到 `Delete` 状态时删除状态记录，导致“读取配置”和“修改配置”的职责混在一个方法里。
- 决策：
  - `ModConfig.GetModState()` 只作为状态查询入口，不得创建或删除 `ModState` 记录。
  - 扫描到真实 Mod 并需要登记默认状态时，必须显式调用 `EnsureModState()`。
  - 删除状态必须由加载器在处理完磁盘删除后显式调用 `ConsumeDeletedModState()` 消费，不能由普通状态查询顺手移除。
  - `DeleteMod()` 和 `SetModEnabled()` 作为配置修改入口，可以显式创建缺失状态记录后再写入目标状态。
  - 新增 `scripts/Invoke-ModRuntimeStaticGate.ps1`，防止 `GetModState()` 重新承担隐式写入或删除职责。
- 影响：
  - Mod 配置读取、默认登记、启停写入和删除状态消费的 owner 分开，后续 UI、加载器和配置保存更容易审计。
  - 如果磁盘删除失败，删除状态不会在读取阶段提前丢失；只有删除处理完成后才移除状态记录。
- 替代关系：
  - 本决策细化 `0002-ResourceSystem 资源 owner 边界` 中 Mod 地基的配置状态 owner 约束。
