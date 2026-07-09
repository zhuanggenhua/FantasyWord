# Assets/_Recovery 归档说明

- 来源：`Assets/_Recovery/0.unity` 及其关联 `.meta`，原属旧 Unity 恢复链路残留。
- 归档时间：`2026-06-14`
- 归档原因：该场景不在当前正式场景入口、代码引用或构建链路中，但会触发 `scripts/Invoke-WorkspacePreflight.ps1` 的正式目录违规检查。
- 当前处理：保留原始场景文件与 GUID 证据到 `docs/archive/legacy-recovery/Assets__Recovery/`，并从正式 `Assets` 树移除，避免旧恢复残留继续污染当前框架基线。
