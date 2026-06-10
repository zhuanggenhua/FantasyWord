# AIBridge 截图回归流程（2026-03-13）

## 目标
- 固化 `MiniFantasyUVTest.unity` 的可复用加载和截图链路。
- 默认超时策略：
  - 连接状态：`60000ms`
  - 场景加载：`60000ms`
  - 单次截图：`20000ms`

## 脚本位置
- `Tools/AIBridge/run-mini-fantasy-uv-smoke.ps1`

## 基础用法
```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\AIBridge\run-mini-fantasy-uv-smoke.ps1
```

## 自动拉起 Unity 并跑 3 轮
```powershell
powershell -ExecutionPolicy Bypass -File .\Tools\AIBridge\run-mini-fantasy-uv-smoke.ps1 -LaunchUnityIfNeeded
```

## 结果位置
- 结构化结果：`AIBridgeCache/results/aibridge-smoke-*.json`
- 文本日志：`AIBridgeCache/results/aibridge-smoke-*.log`
- 截图目录：`AIBridgeCache/screenshots`

## 验收口径
- 连续 `3` 轮 `SceneCommand_Load -> ScreenshotCommand_Image` 均成功。
- 每轮都在 `AIBridgeCache/screenshots` 产出新的 PNG。
