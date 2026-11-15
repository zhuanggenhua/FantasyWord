# 本地地图拼接实验

地图：`map/frontier-world.tmx`。当前是新生成的商路驿站与东侧荒野两个图块，合成尺寸 **3008×941**。模型实际返回每块1672×941，没有伪称4K或放大补数。

本轮Python独立实现本地拼接工具，参考FrameRonin邻接重叠上下文的工作原理，没有复制其源码。所有地图操作由CLI完成；AI生图由当前会话的内置image_gen执行，无需把GPT Key放入FrameRonin网站。Python命令本身不包含模型，也不会自动获得当前会话的生图工具。

## 编辑

用Tiled打开`map/frontier-world.tmx`。地图图块组下有seed、east两个独立图像层，可以移动、显隐；地图为同一连续坐标空间。碰撞标注、地标与入口是供后续编辑的对象层，当前为空。

TMX是唯一地图作者源；job.json、context.png、unknown-mask.png、world-preview.png均为派生产物。Tiled保存手改后，重新prepare即可按最新图层坐标继续扩展；过期作业提交会拒绝执行。图像层不透明度必须1且不设置调色/混合，遮罩通过PNG的透明通道表达。图层偏移使用整数像素；本工程扩图位置按8px网格对齐。

本次图片中的屋顶、建筑、树和地面仍烘焙在图块里，没有自动拆成逐个可编辑瓦片、单独屋顶或室内地板。新地图尚没有导航、真实碰撞、人物遮挡或原地揭顶；没有运行Unity。原有连续室内小镇保留在`artifacts/ai-town-seamless-20261028/map`，其可行走验证不能用于证明本次图片已经可玩。

## CLI

在FantasyWord工程根运行，依赖当前Python的Pillow。工具文件是`scripts/ai-map-experiment/map_stitch.py`，交付ZIP中另附相同脚本。

独立解包时，把以下命令中的脚本改为`scripts/map_stitch.py`，地图改为`map/frontier-world.tmx`；init仅用于另建新地图。

```powershell
# 新工程：仅在目标TMX不存在时运行。
python -X utf8 scripts/ai-map-experiment/map_stitch.py init --map my-world/world.tmx --image seed.png

# 为东侧邻接块准备输入；也支持west/north/south。
python -X utf8 scripts/ai-map-experiment/map_stitch.py prepare --map artifacts/ai-map-local-20261030/map/frontier-world.tmx --anchor east --direction east --job next-east-job --name east-2 --brief "延续主商路和溪流，增加疏林荒野"

# 将该作业的context.png交给当前会话生图工具，使用prompt.txt进行补全。
# 模型返回图必须与作业尺寸完全相同且未知区域已不透明，不自动拉伸或模糊接缝。
python -X utf8 scripts/ai-map-experiment/map_stitch.py commit --job next-east-job/job.json --image generated-east.png

# 依据最新TMX重新渲染预览。
python -X utf8 scripts/ai-map-experiment/map_stitch.py render --map artifacts/ai-map-local-20261030/map/frontier-world.tmx --output artifacts/ai-map-local-20261030/map/world-preview.png
```

一块一块串行完成；提交一块后重做下一块prepare。工具将模型返回图的已知区剔除，旧地图像素保持原样；这避免模型改坏已有地图，但接缝的美术连续性仍须看图判断。PNG路径相对TMX保存，移动完整map目录仍可读。

## 证据与范围

`verification.json`记录：原像素完全保留；Tiled1.12.2原生重读像素一致；四方向prepare坐标；错误尺寸及过期作业无修改拒绝；TMX图组移动8px后新作业坐标同步。

`visual-review.json`只评价当前合成图的视觉接缝和布局，不证明碰撞、玩家移动、室内、流式加载或Unity效果。新图风格比MiniFantasy更细密，并未保持原素材的8px视觉规格。

`design.md`记录参考职责、来源版本和独立实现边界，`generation-prompts.json`保留实际生成提示词，`inputs/`保留未裁剪的两张模型输出。`east-job/commit-report.json`记录模型重画已知区域的偏差及最终固定旧像素的结果。
