# 点击寻路：候选目标与节点路径

基线为 Unity 提交 `31629d5`。
[TerrainDestinationResolver](../Assets/Scripts/GameCore/Runtime/Maps/TerrainDestinationResolver.cs) 负责选唯一目标，
[TerrainNavigationGraph](../Assets/Scripts/GameCore/Runtime/Maps/TerrainNavigationGraph.cs) 负责有向节点路径；
[TerrainNavigationMap](../Assets/Scripts/GameCore/Runtime/Maps/TerrainNavigationMap.cs) 负责场景坐标、图生成和世界路径。
这三层不互相替代。

## 目标选择

- 起点只在当前层找。落在有效格时保留原点击点；否则按方形外圈逐圈找，找到首个有候选的圈就停止。
  圈内用格中心的平方距离，按原来的阈值和 Unity 格坐标的先 Y 后 X 判断近似平局。
- 跨层收集时先默认层，再按配置顺序访问各规则层；只要有一个精确格，就先丢弃全部吸附候选，
  再检查图可达性。精确格若不可达，不会退回可达的吸附格；首圈最优格也不会因不可达改搜第二圈。
- 当前层可达时优先当前层；否则接受唯一可达层，多个可达层判歧义。没有候选与候选不可达是不同失败。

## 节点路径

节点键保留原 `(LayerId, Cell.x, Cell.y, Cell.z)`，包括不参与启发估价的 Z。
同层的方向边与显式跨层连接分开，保留有向和重复边规则、代价最小值 0.01。
图的 A* 使用 XY 曼哈顿估价与换层惩罚，同分保留开放集合中先入的节点。
当前实现不把这套已锁定规则改成引擎默认的最近点、默认 A* 或通用最优性承诺。

## ClickMoveTest 的实际规则图

只读锁定 Git 提交中的 ClickMoveTest 规则 Tilemap：单位矩形格、原点 (0, 0)、Y 向上，
和可视化 Tilemap、装饰表层与正式物理形状分开。原版这张规则图是默认层，没有显式跨层连接。
构图按 Y/X 排序入节点，邻接顺序固定右、左、上、下；按目标格代价计边。
同高程可走；跨一个高程要求坡道方向与低到高的步子匹配；跨多级、无坡或坡向冲突都拒绝。
运行时地表效果计算仍独立，已知有效代价可由调用方显式传入后重建。

可选的原数据检查需要 Python 的 PyYAML 和能读取锁定提交的本地 Unity 仓库。
从迁移分支仓库根目录执行，输出选一个**已存在目录中的全新绝对路径**，放在所有 Git 工作树之外：

```sh
python3 godot/tools/extract_clickmovetest_rules.py \
  --unity-checkout /path/to/unity-repo --output /private/clickmovetest-rules.json
"${GODOT:-godot}" --headless --path godot --script res://tools/check_clickmovetest_rules.gd \
  -- /private/clickmovetest-rules.json
```

只在本地输出规则值，不复制原场景、贴图、地形文件或表层数据，不上传输出文件。
实际原数据加载得到 900 格、9 类规则、649 个可行走节点、2,226 条有向边；
联测通过原转角验证器的首选路段与一条平地控制路径。平地样本不是相机投影后的原生点击。
原编辑器仍未运行对照，实际节点图不代表撞墙、坡道画面或世界路径已验收。

## 尚未接入

世界路径仍须把格路径按原规则采样为连续路径，保留坡道端点与点击落点；
真实地图渲染和碰撞形状、运行时地表代价、角色场景与镜头还未接入。
[原地形导航测试](../Assets/Editor/GameCore/Tests/TerrainNavigationMapEditModeTests.cs)
仍是路点和场景验收的依据。当前不是 ClickMoveTest 已可试玩。
