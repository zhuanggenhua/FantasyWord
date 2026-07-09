# TMP 中文文本不显示排查记录

## 适用场景

- UGUI / TextMesh Pro 中文文本在编辑态或 PlayMode 中不显示。
- 同一字体资产、同一段内容在某个 TMP 文本能显示，但另一个 TMP 文本不显示。
- 运行时刷新长中文文案后，文本消失或 `ForceMeshUpdate` 报错。

## 本次案例结论

- 不能先把中文不显示定性为“缺字”。
- 本次 `ClickMoveTest` 的关键症状是 Body 文本即使换成 Title 内容也不显示，说明缺字不是充分解释。
- 真正命中的链路是 TMP 中文换行/网格生成：`TMP Settings.asset` 的中文行首/行尾规则引用缺失，会让 CJK line breaking 路径异常，表现上像文本不可见。

## 必查项

1. 目标 TMP 组件本身能否 `ForceMeshUpdate` 成功。
2. `chars / visible / lines / rendered size` 是否合理。
3. Canvas 层级、遮挡、透明度、裁剪、RectTransform 尺寸是否正常。
4. `Assets/TextMesh Pro/Resources/TMP Settings.asset` 是否引用：
   - `Assets/TextMesh Pro/Resources/LineBreaking Leading Characters.txt`
   - `Assets/TextMesh Pro/Resources/LineBreaking Following Characters.txt`
5. 字体 fallback 和材质只能作为候选项，不能在没有目标 TMP 组件证据时直接定为根因。

## 验收口径

- 编辑态或 PlayMode 下，原始目标 TMP 组件能成功生成网格。
- 原始 UI 位点可见，而不是只证明字体资产存在或截图文件存在。
- 如果只补了 fallback、预生成字形、换材质或压掉报错，但原始目标 TMP 仍不可见，只能称为止血或误判修正。

## 关联文件

- `Assets/Scenes/ClickMoveTest.unity`
- `Assets/Scripts/GameCore/Runtime/Debug/ClickMoveTestControlPanel.cs`
- `Assets/TextMesh Pro/Resources/TMP Settings.asset`
- `Assets/TextMesh Pro/Resources/LineBreaking Leading Characters.txt`
- `Assets/TextMesh Pro/Resources/LineBreaking Following Characters.txt`
