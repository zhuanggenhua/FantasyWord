# AIBridge 常用命令

## 适用范围

- 本文记录 `FantasyWord` 的 Unity Editor 自动化、测试和取证命令。
- 本项目目标自动化包：`com.aibridge.unity`。
- 包来源：`https://github.com/aiseog3121/unity-ai-bridge.git?path=/Packages/com.aibridge.unity`。
- 旧 UnityMCP 不再作为正式入口。

## Editor 基线

- 本地开发只使用一个正常 Unity Editor。
- 如果 `FantasyWord` Editor 已打开，自动化连接这个 Editor。
- 如果未打开，先启动正常 Editor，再用 AIBridge。
- 不把 `Unity.exe -batchmode` 当日常验证入口。

启动正常 Editor 示例：

```powershell
Start-Process -FilePath "C:\Gamedev\Unity\Editor\6000.3.10f1\Editor\Unity.exe" -ArgumentList @("-projectPath","C:\Gamedev\Unity\Project\FantasyWord")
```

## 当前迁移状态

- `Packages/manifest.json` 已切换到本地 `com.aibridge.unity`。
- 旧 `cn.lys.aibridge` 和旧 `com.ivanmurzak.unity.mcp` 只应存在于 `Library/` 缓存或历史日志中。
- 若 `Assets/Resources/Unity-MCP-ConnectionConfig.json` 再次出现，说明当前 Unity Editor 仍有旧 MCP 会话残留；删除后刷新包解析并复查。
- 旧 `Tools/AIBridge/run-mini-fantasy-uv-smoke.ps1` 已删除，面向旧 MiniFantasy UV smoke，不是新项目正式验收入口。

## 命令原则

- 默认优先做 `assets-refresh`、Editor 状态读取、Console 读取、精确测试。
- 不为一次性探针新增长期 Editor 菜单。
- 不默认聚焦 Unity，不切 PlayMode，不打开场景取证。

## 后续待补

- 新 AIBridge CLI 路径确认后，补充 `editor-application-get-state`、`assets-refresh`、`console-get-logs` 和 `tests-run` 示例。
- 项目内 `.codex/skills/aibridge/bridge.py` 已迁入；实际调用前必须先读对应 `params/{tool}.json`。
