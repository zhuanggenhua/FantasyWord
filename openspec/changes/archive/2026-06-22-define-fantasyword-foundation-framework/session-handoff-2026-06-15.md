# 2026-06-15 新会话交接（历史快照，已被 2026-06-16 晚间复核 supersede）

> 注意：本文件只保留当时的排查方向，不再代表当前现态。涉及最新真相，请以 `session-handoff-2026-06-16.md` 与 `verification-notes.md` 中 `2026-06-16` 晚间补记为准。

## 已被后续证据推翻的旧结论

- `Assets/Scenes/SampleScene.unity` 与 `Assets/Scenes/ClickMoveTest.unity` 里的 `PlayerSystem.m_playerInstance` 并没有完成场景级序列化绑定；当前磁盘版两处都还是 `{fileID: 0}`。
- 当前正式场景预摆的玩家实例来源是 `Assets/Prefabs/Entities/Characters/Heroes/玩家角色.prefab`，它是 `0_Hero_Base.prefab` 的 variant；不能再把 `0_Hero_Base.prefab` 直接当成“当前正式场景正在引用的玩家 prefab”。
- 当时曾误判这条线的下一步是“先恢复 `UIKitMenuHost` partial 拆分导致的编译错误，再回到场景绑定和移动场景验证”；这一判断现已被后续证据推翻，不得再拿来描述当前现态。

## 仍然成立的历史约束

- 总任务仍是继续完成 `2D 移动与场景组织`。
- 仍然只做“有直接参考且能直接搬”的内容。
- 不创造兼容层、空宿主、并行控制器或临时测试控制器。
- `uMMORPG` 仍只是局部证据源，不能升格成当前单机 2D 正式运行时。
