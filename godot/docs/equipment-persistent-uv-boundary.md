# 持久材质的动作 UV 写入边界

此切片只完成有效动作双 UV 图到已有装备材质的连接，不是正式角色场景、完整换装刷新或截图一致性验收。

## 四项前提

- 对象：同一个 EquipmentRenderer 材质实例中的 Body/Head UV 引用。
- 真相：锁定 Unity 31629d53a110dd4c87d4c85e6ad5a387fbafb931，EquipmentRenderer.cs 的 ApplyAnimationKey、UpdateUVMapTexture、LateUpdate、SyncCurrentSpriteAndRefresh 与 Refresh。
- 入口：云端 Godot 4.7.2，既有 EquipmentFrameRuntime.hooks.bind_uv_maps 显式连接 EquipmentSubsetMaterial.apply_action_uv_maps；不是改写正式 EquipmentSystemDemoCharacter。
- 验收：原生 AnimationPlayer 实际采样 Sprite2D.texture，读取同一 ShaderMaterial 参数和帧刷新次数。合成图、辅助测试纹理不能当正式素材或最终截图。

## 原流程与本轮对应

源动作 owner 变化会立即调用 UpdateUVMapTexture，分别写入两张图。它不重建材质、不修改 SpriteRenderer 的 Sprite，也不自动把整套装备刷新一遍。LateUpdate 之后只在 Sprite 引用改变时同步坐标并刷新；显式同步则允许同一 Sprite 再次刷新。有效 Refresh 内部仍会再次写 UV。

新入口仅写 body_map 和 head_map。不调用 create、不重置普通装备、武器、阴影或乘色，不选择动作，不修改主图，不接管动画时钟。默认本体变体与显式武器变体均保留原着色器和采样器数量。

动作先变而 Sprite 尚未变时，新 UV 与旧主图可以具有不同尺寸。这是两条 owner 更新顺序的真实过渡，不应强制三图同时更换或重新创建材质。测试用 512×128 和 128×128 两组整图覆盖此边界；测试尺寸及空白纹理只证明参数合同，不证明实际作者素材画面。

## 明确未覆盖

新入口仅接受两张有效整图且彼此尺寸相同，调用者须检查返回值。缺 UV、AtlasTexture 作为 UV、不同尺寸双 UV 或未知材质均明确拒绝并不写入，这不是源缺图行为的实现。不能直接把此入口安装为覆盖全部路径的正式渲染器：源缺图路径需要清空旧图、重置层、保留独立武器/序列；其默认纹理采样语义仍需单独验证。

测试内 reset_layers 等其余钩子仅计数或空操作，故不声称完整 Refresh 材质接线。主图显式取自原生播放器当前 Sprite 的整图；普通角色、坐骑、正式装备组合、颜色域、渲染像素及原 Unity GameView 对照仍待验收。
