# 0026-音频播放生命周期 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `AudioChannel` 是正式音频通道 owner，内部负责 BroAudio 播放、独占 AudioSource 播放和 Unity AudioClip fallback 池。
  - fallback 播放器是池化 `GameObject`，播放完成、停止、通道销毁和对象禁用都可能打断播放协程。
  - 旧实现主要通过 `Stop()` 和 `OnDestroy()` 清理通道播放，但组件禁用和 fallback 播放器外部禁用时缺少同一条生命周期清理合同。
- 决策：
  - `AudioChannel` 禁用时必须停止当前播放、清理独占通道协程、停止 fallback 活动播放器并停止 BroAudio 播放。
  - `AudioChannelFallbackPlayer` 的公开停止入口、禁用和销毁都必须走同一个内部清理函数，停止播放协程、停止 `AudioSource`、清空 clip、跟随目标、完成回调、剩余时长和暂停状态。
  - 禁用回调中的清理不得再次强制禁用对象，避免对象池回收和 Unity 生命周期形成重复递归。
  - 音频静态门禁必须覆盖通道禁用停播和 fallback 播放器禁用/销毁清理合同。
- 影响：
  - 禁用音频通道组件时不会留下仍在播放的独占音频、fallback 子播放器或 BroAudio player。
  - fallback 播放器被对象池、父级通道或 Unity 生命周期禁用/销毁时，不会保留旧回调或旧 AudioClip。
- 替代关系：
  - 本决策补强 `0004-音频运行时 owner 边界`，不改变音频资源身份、通道选择或 BroAudio 作为内部执行层的裁决。
