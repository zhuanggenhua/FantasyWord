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

## 尚未接入

本轮图只接收已审定的格和边，候选只接收注入的地图坐标转换与路径检查。
没有迁移真实 Tilemap 的规则格、坡道与不同高程边、地表影响代价、格路径到世界路径的转换及镜头；
没有复制原始地图素材。原版的 [地形导航测试](../Assets/Editor/GameCore/Tests/TerrainNavigationMapEditModeTests.cs)
仍是场景与路径验收的依据。Godot 合成夹具用于证明选格与图路径，不是 ClickMoveTest 已可试玩。
