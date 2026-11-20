# ClickMoveTest 原 Settings 音量与资产合同

锁定原工程 `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。
`UISettings.cs` 的五行对应 Master、BackgroundMusic（0）、
BackgroundSound（1）、InterfaceSoundFX（2）、GameplaySoundFX（3）。
本场景的 AudioSystem 恰好配置这四个通道，不额外造 Miscellaneous。
原场景四通道和 Master 启动默认 .5，调整按 .1 的 32 位浮点步长和
ties-to-even 舍入，裁剪至 0–1，显示整数加原后缀 ` / 10`。

正常 ClickMoveTest 宿主启动时加载本地 Godot 音量配置，退出时保存，并
恢复宿主监听器。此格式不直接读写 Unity PlayerPrefs。Master 控制
Godot Master 总线，喷火使用真实 GameplaySoundFX 当前比例，已播放与
下一次租出的声部一起更新；改变 Master 不会覆盖通道值。其余三个通道
保持可读写的配置值，但各自原播放对象没有在此阶段伪造、迁移或验收。
暂停/恢复和子面板弹栈不保存或重置音量。音频测试验证了实际运行参数、
自然播放完成和配置生命周期，不等同实际听感或 Unity 混音对照。

在 `godot/` 下从有锁定提交的 Unity 仓库生成本地启动资料：
```sh
python tools/extract_clickmovetest_pause.py --repo "$UNITY_REPO" --output "$PAUSE_DIR"
python tools/extract_clickmovetest_settings.py --repo "$UNITY_REPO" --output "$PAUSE_DIR/settings-contract.json"
```
在该目录放入用户本地 Unity LFS 检出中的原 `SPS_GUI.png`；程序验证地图集
和字形哈希。保持现有 ClickMoveTest 所需环境变量并设置
`FORMAL_PAUSE_SOURCE="$PAUSE_DIR"` 再 F5。所有这些原素材与生成的图集
留在本地，不加入 Godot 提交。

当 `FORMAL_PAUSE_SOURCE` 私有目录同时包含 settings-contract.json 时，
正常 F5 场景的 Pause → Settings 会挂载实际设置面板。使用以高度匹配
并居中的 1920×1080 固定根面板；
原背景为 SPS_GUI 的 tiled sprite -1443275623。标题 Settings 120 点 TOP，
基线 (788,190)。五行从 (527,440) 开始每行 64，原始 Music 标签末尾
LF 仍保留在合同，按 TMP 末尾空行的规则渲染可见字形。主音量减按钮为默认目标。
页脚 Select 与 Back 字仍保留，默认图标留空。不得使用近似占位面板。

按 Esc 或鼠标右键返回同一个暂停根面板并恢复 Settings 焦点；再按一次才回玩法。
仅迁移原设置的键鼠链，原手柄、其它暂停子菜单、完整效果列表及直接 Unity
像素对照仍不在本验收范围。
