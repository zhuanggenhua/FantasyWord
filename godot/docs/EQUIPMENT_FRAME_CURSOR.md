# 装备帧坐标与缓存

依据锁定 Unity `31629d5` 的 `EquipmentRenderer.SyncFromSprite`、`LateUpdate`、`SyncCurrentSpriteAndRefresh`、`ApplyPreviewDirection` 和 `AnimationData.GetFrame/EnsureFrameLookup`。

这是装备渲染刷新前的一段帧选择合同，不是完整装备渲染。动作解析仍由调用方提供，清单含 `frame_size` 和 `frames`，每帧含 `frame_index`、`row_index`；其余数据原样保留。本模块不从动作标签号推算图集列号，不猜缺失动作、帧或素材。

源 Sprite rect 从底起算，导入为 Godot AtlasTexture 顶起 region 后，列为 floor(x/frameW)，行为 floor(y/frameH)。新纹理引用触发采样；相同纹理对象的 region 原地编辑不触发普通 LateUpdate 重采样。显式刷新会强制采样；空精灵显式刷新仍通知 Refresh，但保留坐标。当前仅支持具有明确区域的 AtlasTexture，不宣称普通 Texture2D 的源 Sprite 契约。

预览行裁剪到 0..3；相同行不刷新。行变化先清帧缓存，再按 auto_refresh 通知。收到 `refresh_requested` 后，外部装备 Refresh 可调用 `refresh_frame`，用当前图集列/行获得对应帧。查表按源动画对象分别缓存，空帧跳过，重复键首项获胜，仅列表长度变化重建；同数量内容替换不会自动失效，这是源行为而非新增缓存规则。

自动验证使用合成 AtlasTexture 和帧列表检查稀疏列、引用变化、预览和缓存边界，不包含原素材。尚未实现动作回退、完整刷新顺序、UV 贴图、外观层、武器或材质输出；测试通过不能算完整换装或画面对照通过。
