using System;
using System.Collections.Generic;
using AStar;
using UnityEngine;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 当前场景的 Tilemap 地形规则和路径查询入口。
    /// 它把规则 Tilemap 投影成 A* 输入，但不接管角色移动，也不从视觉 Tilemap 猜玩法数据。
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class TerrainNavigationMap : MonoBehaviour
    {
        [Header("规则入口")]
        [InspectorName("兼容默认规则 Tilemap")]
        [Tooltip("旧单层地图的兼容入口。多层地图应改用下方规则层来源列表。")]
        [SerializeField] private Tilemap m_ruleTilemap = null;

        [InspectorName("规则层来源")]
        [Tooltip("同一个地形导航入口管理的多个逻辑规则层。为空时自动使用兼容默认规则 Tilemap。")]
        [SerializeField] private TerrainNavigationLayerSource[] m_layerSources = Array.Empty<TerrainNavigationLayerSource>();

        [Header("路径设置")]
        [InspectorName("最近可行走格搜索半径")]
        [Min(0)]
        [Tooltip("点击点落在阻挡边缘时，允许在该格半径内寻找最近合法目标。找不到时命令明确失败。")]
        [SerializeField] private int m_nearestWalkableSearchRadius = 2;

        [Header("编辑器调试")]
        [InspectorName("绘制最近导航路径")]
        [Tooltip("在 Scene 视图中绘制最近一次点击寻路的起点、目标和实际路径。需要开启 Scene 视图的 Gizmos。")]
        [SerializeField] private bool m_drawLastNavigationPath = true;

        [InspectorName("路径标记半径")]
        [Min(0.01f)]
        [SerializeField] private float m_debugMarkerRadius = 0.12f;

        [InspectorName("成功路径颜色")]
        [SerializeField] private Color m_debugPathColor = new(0.0f, 0.85f, 1.0f, 1.0f);

        [InspectorName("失败目标颜色")]
        [SerializeField] private Color m_debugFailureColor = new(1.0f, 0.25f, 0.2f, 1.0f);

        private static readonly Vector3Int[] CardinalNeighborOffsets =
        {
            Vector3Int.right,
            Vector3Int.left,
            Vector3Int.up,
            Vector3Int.down
        };

        private readonly Dictionary<TerrainNodeKey, TerrainCellRuntimeState> m_runtimeSurfaceStates = new();
        private readonly Dictionary<TerrainNodeKey, float> m_runtimeTraversalCostMultipliers = new();
        private readonly Queue<Vector3Int> m_areaTraversalQueue = new();
        private readonly HashSet<Vector3Int> m_areaVisitedCells = new();
        private readonly List<TerrainNodeKey> m_areaNodeScratch = new();

        private BoundsInt m_cachedBounds;
        private TerrainNavigationTile[,] m_cachedTiles;
        private float[,] m_cachedCostMap;
        private Vector2 m_lastDebugStart;
        private Vector2 m_lastDebugDestination;
        private Vector2[] m_lastDebugWorldPath = Array.Empty<Vector2>();
        private bool m_hasDebugPathRequest;
        private bool m_lastDebugPathSucceeded;

        public Tilemap RuleTilemap => ActiveRuleTilemap;
        public IReadOnlyList<TerrainNavigationLayerSource> LayerSources => m_layerSources;
        public int RuntimeStateCount => m_runtimeSurfaceStates.Count;

        private Tilemap ActiveRuleTilemap
        {
            get
            {
                TerrainNavigationLayerSource defaultLayer = DefaultLayerSource;
                return defaultLayer != null && defaultLayer.IsValid
                    ? defaultLayer.RuleTilemap
                    : m_ruleTilemap;
            }
        }

        private TerrainNavigationLayerSource DefaultLayerSource
        {
            get
            {
                if (m_layerSources == null)
                {
                    return null;
                }

                for (int i = 0; i < m_layerSources.Length; i++)
                {
                    TerrainNavigationLayerSource source = m_layerSources[i];
                    if (source != null &&
                        source.LayerId == TerrainNodeKey.DefaultLayerId &&
                        source.IsValid)
                    {
                        return source;
                    }
                }

                return null;
            }
        }

        public event Action<TerrainCellStateChange> CellStateChanged;
        public event Action RuntimeSurfaceStatesCleared;

        private void OnEnable()
        {
            RefreshNavigationData();
        }

        /// <summary>
        /// 重新读取规则 Tilemap。地图作者修改规则格或运行时替换规则后必须调用一次。
        /// </summary>
        public void RefreshNavigationData()
        {
            Tilemap activeRuleTilemap = ActiveRuleTilemap;
            if (activeRuleTilemap == null)
            {
                m_cachedBounds = default;
                m_cachedTiles = null;
                m_cachedCostMap = null;
                return;
            }

            m_cachedBounds = activeRuleTilemap.cellBounds;
            int width = m_cachedBounds.size.x;
            int height = m_cachedBounds.size.y;
            if (width <= 0 || height <= 0)
            {
                m_cachedTiles = null;
                m_cachedCostMap = null;
                return;
            }

            m_cachedTiles = new TerrainNavigationTile[height, width];
            m_cachedCostMap = new float[height, width];

            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    Vector3Int cell = IndexToCell(x, y);
                    TerrainNavigationTile tile = activeRuleTilemap.GetTile<TerrainNavigationTile>(cell);
                    m_cachedTiles[y, x] = tile;
                    m_cachedCostMap[y, x] = tile != null && tile.Walkable ? tile.TraversalCost : -1.0f;
                }
            }

            foreach (KeyValuePair<TerrainNodeKey, float> runtimeCost in m_runtimeTraversalCostMultipliers)
            {
                UpdateCachedTraversalCost(runtimeCost.Key.Cell, runtimeCost.Value);
            }
        }

        /// <summary>
        /// 为即时点击移动生成连续世界路径点。
        /// 返回 false 表示当前规则地图不存在合法路线，调用方不得回退成穿越悬崖的直线命令。
        /// </summary>
        public bool TryBuildWorldPath(Vector2 startWorld, Vector2 destinationWorld, out Vector2[] worldPath)
        {
            worldPath = Array.Empty<Vector2>();
            m_hasDebugPathRequest = true;
            m_lastDebugStart = startWorld;
            m_lastDebugDestination = destinationWorld;
            m_lastDebugWorldPath = Array.Empty<Vector2>();
            m_lastDebugPathSucceeded = false;

            if (!EnsureNavigationData())
            {
                Debug.LogError($"地形导航组件 '{name}' 缺少有效的规则 Tilemap，无法计算路径。", this);
                return false;
            }

            Tilemap activeRuleTilemap = ActiveRuleTilemap;
            Vector3Int requestedStart = activeRuleTilemap.WorldToCell(startWorld);
            Vector3Int requestedGoal = activeRuleTilemap.WorldToCell(destinationWorld);
            if (!TryResolveWalkableCell(requestedStart, out Vector3Int startCell) ||
                !TryResolveWalkableCell(requestedGoal, out Vector3Int goalCell))
            {
                return false;
            }

            (int startX, int startY) = CellToIndex(startCell);
            (int goalX, int goalY) = CellToIndex(goalCell);
            (int x, int y)[] gridPath = AStarPathfinding.GeneratePathSync(
                startX,
                startY,
                goalX,
                goalY,
                m_cachedCostMap,
                manhattanHeuristic: false,
                walkableDiagonals: false);

            gridPath = ExpandDiagonalSteps(gridPath);
            if (gridPath.Length == 0 || !ValidateElevationTransitions(gridPath))
            {
                return false;
            }

            worldPath = ConvertToWorldPath(gridPath, requestedGoal == goalCell, destinationWorld);
            m_lastDebugWorldPath = worldPath;
            m_lastDebugPathSucceeded = worldPath.Length > 0;
            return m_lastDebugPathSucceeded;
        }

        /// <summary>
        /// 查询世界坐标下的正式地形规则。
        /// </summary>
        public bool TryGetSurfaceSample(Vector2 worldPosition, out TerrainSurfaceSample sample)
        {
            if (!EnsureNavigationData())
            {
                sample = default;
                return false;
            }

            Vector3Int cell = ActiveRuleTilemap.WorldToCell(worldPosition);
            return TryGetSurfaceSample(cell, out sample);
        }

        public bool TryGetSurfaceSample(Vector3Int cell, out TerrainSurfaceSample sample)
        {
            return TryGetSurfaceSample(TerrainNodeKey.Default(cell), out sample);
        }

        public bool TryGetSurfaceSample(
            in TerrainNodeKey nodeKey,
            out TerrainSurfaceSample sample)
        {
            sample = default;
            if (!IsSupportedNode(nodeKey) || !EnsureNavigationData())
            {
                return false;
            }

            Vector3Int cell = nodeKey.Cell;
            if (!TryGetTile(cell, out TerrainNavigationTile tile))
            {
                return false;
            }

            TerrainCellRuntimeStateSnapshot runtimeStateSnapshot;
            ETerrainSurfaceKind effectiveSurface;
            if (m_runtimeSurfaceStates.TryGetValue(
                    nodeKey,
                    out TerrainCellRuntimeState runtimeState))
            {
                runtimeStateSnapshot = runtimeState.CreateSnapshot(tile.SurfaceKind);
                effectiveSurface = runtimeStateSnapshot.EffectiveSurface;
            }
            else
            {
                runtimeStateSnapshot = TerrainCellRuntimeStateSnapshot.Empty(tile.SurfaceKind);
                effectiveSurface = tile.SurfaceKind;
            }

            (int x, int y) = CellToIndex(cell);
            sample = new TerrainSurfaceSample(
                nodeKey,
                tile.Elevation,
                tile.SurfaceKind,
                effectiveSurface,
                tile.TraversalCost,
                m_cachedCostMap[y, x],
                runtimeStateSnapshot);
            return true;
        }

        public bool TryGetRuntimeState(
            Vector3Int cell,
            out TerrainCellRuntimeState runtimeState)
        {
            return TryGetRuntimeNodeState(
                TerrainNodeKey.Default(cell),
                out runtimeState);
        }

        public bool TryGetRuntimeNodeState(
            in TerrainNodeKey nodeKey,
            out TerrainCellRuntimeState runtimeState)
        {
            if (!IsSupportedNode(nodeKey))
            {
                runtimeState = null;
                return false;
            }

            return m_runtimeSurfaceStates.TryGetValue(nodeKey, out runtimeState);
        }

        /// <summary>
        /// 设置地图实例上的临时地表状态，不修改共享的规则 Tile 资产。
        /// </summary>
        public bool SetRuntimeSurfaceState(Vector2 worldPosition, ETerrainRuntimeSurfaceState state)
        {
            if (!EnsureNavigationData())
            {
                return false;
            }

            Vector3Int cell = ActiveRuleTilemap.WorldToCell(worldPosition);
            if (!TryGetSurfaceSample(cell, out TerrainSurfaceSample previousSample))
            {
                return false;
            }

            TerrainNodeKey nodeKey = TerrainNodeKey.Default(cell);
            m_runtimeSurfaceStates.TryGetValue(
                nodeKey,
                out TerrainCellRuntimeState existingState);
            if (state == ETerrainRuntimeSurfaceState.None && existingState == null)
            {
                return true;
            }

            TerrainCellRuntimeState runtimeState = existingState;
            if (runtimeState == null &&
                !TryGetOrCreateRuntimeNodeState(nodeKey, out runtimeState))
            {
                return false;
            }

            if (!runtimeState.ReplaceCompatibilityFlags(state))
            {
                return true;
            }

            return CommitRuntimeNodeState(
                nodeKey,
                previousSample,
                1.0f,
                EElementPresentationSignal.None);
        }

        public void ClearRuntimeSurfaceStates()
        {
            if (m_runtimeSurfaceStates.Count == 0 &&
                m_runtimeTraversalCostMultipliers.Count == 0)
            {
                return;
            }

            m_runtimeSurfaceStates.Clear();
            m_runtimeTraversalCostMultipliers.Clear();
            RefreshNavigationData();
            RuntimeSurfaceStatesCleared?.Invoke();
        }

        /// <summary>
        /// 把世界元素范围转换为规则格，并沿合法同层/坡道连接展开。
        /// 视觉重叠不能绕过悬崖、阻挡或缺失规则格。
        /// </summary>
        public bool TryCollectAffectedCells(
            in ElementApplication application,
            List<Vector3Int> affectedCells)
        {
            if (affectedCells == null)
            {
                throw new ArgumentNullException(nameof(affectedCells));
            }

            affectedCells.Clear();
            m_areaNodeScratch.Clear();
            if (!TryCollectAffectedNodes(application, m_areaNodeScratch))
            {
                return false;
            }

            for (int i = 0; i < m_areaNodeScratch.Count; i++)
            {
                affectedCells.Add(m_areaNodeScratch[i].Cell);
            }

            return affectedCells.Count > 0;
        }

        public bool TryCollectAffectedNodes(
            in ElementApplication application,
            List<TerrainNodeKey> affectedNodes)
        {
            if (affectedNodes == null)
            {
                throw new ArgumentNullException(nameof(affectedNodes));
            }

            affectedNodes.Clear();
            if (!application.IsValid || !EnsureNavigationData())
            {
                return false;
            }

            Vector3Int originCell = ActiveRuleTilemap.WorldToCell(application.Origin);
            if (!TryGetTile(originCell, out TerrainNavigationTile originTile) ||
                !originTile.Walkable)
            {
                return false;
            }

            m_areaTraversalQueue.Clear();
            m_areaVisitedCells.Clear();
            m_areaTraversalQueue.Enqueue(originCell);
            m_areaVisitedCells.Add(originCell);

            while (m_areaTraversalQueue.Count > 0)
            {
                Vector3Int currentCell = m_areaTraversalQueue.Dequeue();
                if (IsInsideElementArea(currentCell, application))
                {
                    affectedNodes.Add(TerrainNodeKey.Default(currentCell));
                }

                if (application.Area.Kind == EElementAreaKind.Point)
                {
                    continue;
                }

                for (int i = 0; i < CardinalNeighborOffsets.Length; i++)
                {
                    Vector3Int neighborCell = currentCell + CardinalNeighborOffsets[i];
                    if (m_areaVisitedCells.Contains(neighborCell) ||
                        !IsInsideElementArea(neighborCell, application) ||
                        !CanTraverseCardinalCells(currentCell, neighborCell))
                    {
                        continue;
                    }

                    m_areaVisitedCells.Add(neighborCell);
                    m_areaTraversalQueue.Enqueue(neighborCell);
                }
            }

            return affectedNodes.Count > 0;
        }

        internal bool TryGetOrCreateRuntimeState(
            Vector3Int cell,
            out TerrainCellRuntimeState runtimeState)
        {
            return TryGetOrCreateRuntimeNodeState(
                TerrainNodeKey.Default(cell),
                out runtimeState);
        }

        internal bool TryGetOrCreateRuntimeNodeState(
            in TerrainNodeKey nodeKey,
            out TerrainCellRuntimeState runtimeState)
        {
            if (!IsSupportedNode(nodeKey) ||
                !EnsureNavigationData() ||
                !TryGetTile(nodeKey.Cell, out _))
            {
                runtimeState = null;
                return false;
            }

            if (!m_runtimeSurfaceStates.TryGetValue(nodeKey, out runtimeState))
            {
                runtimeState = new TerrainCellRuntimeState();
                m_runtimeSurfaceStates.Add(nodeKey, runtimeState);
            }

            return true;
        }

        internal void CollectTimedRuntimeStateCells(List<Vector3Int> cells)
        {
            if (cells == null)
            {
                throw new ArgumentNullException(nameof(cells));
            }

            cells.Clear();
            foreach (KeyValuePair<TerrainNodeKey, TerrainCellRuntimeState> pair in m_runtimeSurfaceStates)
            {
                if (pair.Value != null && pair.Value.HasTimedStates)
                {
                    cells.Add(pair.Key.Cell);
                }
            }
        }

        internal void CollectTimedRuntimeStateNodes(List<TerrainNodeKey> nodes)
        {
            if (nodes == null)
            {
                throw new ArgumentNullException(nameof(nodes));
            }

            nodes.Clear();
            foreach (KeyValuePair<TerrainNodeKey, TerrainCellRuntimeState> pair in m_runtimeSurfaceStates)
            {
                if (pair.Value != null && pair.Value.HasTimedStates)
                {
                    nodes.Add(pair.Key);
                }
            }
        }

        internal void CollectRuntimeStateCells(List<Vector3Int> cells)
        {
            if (cells == null)
            {
                throw new ArgumentNullException(nameof(cells));
            }

            cells.Clear();
            foreach (TerrainNodeKey nodeKey in m_runtimeSurfaceStates.Keys)
            {
                cells.Add(nodeKey.Cell);
            }
        }

        internal void CollectRuntimeStateNodes(List<TerrainNodeKey> nodes)
        {
            if (nodes == null)
            {
                throw new ArgumentNullException(nameof(nodes));
            }

            nodes.Clear();
            foreach (TerrainNodeKey nodeKey in m_runtimeSurfaceStates.Keys)
            {
                nodes.Add(nodeKey);
            }
        }

        internal bool CommitRuntimeState(
            Vector3Int cell,
            in TerrainSurfaceSample previousSample,
            float traversalCostMultiplier,
            EElementPresentationSignal presentationSignal)
        {
            return CommitRuntimeNodeState(
                TerrainNodeKey.Default(cell),
                previousSample,
                traversalCostMultiplier,
                presentationSignal);
        }

        internal bool CommitRuntimeNodeState(
            in TerrainNodeKey nodeKey,
            in TerrainSurfaceSample previousSample,
            float traversalCostMultiplier,
            EElementPresentationSignal presentationSignal)
        {
            if (!IsSupportedNode(nodeKey) ||
                !EnsureNavigationData() ||
                !m_runtimeSurfaceStates.TryGetValue(
                    nodeKey,
                    out TerrainCellRuntimeState runtimeState))
            {
                return false;
            }

            if (runtimeState.IsEmpty)
            {
                m_runtimeSurfaceStates.Remove(nodeKey);
                m_runtimeTraversalCostMultipliers.Remove(nodeKey);
                UpdateCachedTraversalCost(nodeKey.Cell, 1.0f);
            }
            else
            {
                float normalizedMultiplier = Mathf.Max(0.01f, traversalCostMultiplier);
                m_runtimeTraversalCostMultipliers[nodeKey] = normalizedMultiplier;
                UpdateCachedTraversalCost(nodeKey.Cell, normalizedMultiplier);
            }

            if (!TryGetSurfaceSample(nodeKey, out TerrainSurfaceSample currentSample))
            {
                return false;
            }

            CellStateChanged?.Invoke(new TerrainCellStateChange(
                this,
                nodeKey,
                previousSample,
                currentSample,
                presentationSignal));
            return true;
        }

        private bool EnsureNavigationData()
        {
            if (m_cachedTiles == null || m_cachedCostMap == null)
            {
                RefreshNavigationData();
            }

            return ActiveRuleTilemap != null && m_cachedTiles != null && m_cachedCostMap != null;
        }

        private static bool IsSupportedNode(in TerrainNodeKey nodeKey)
        {
            return nodeKey.IsDefaultLayer;
        }

        private bool TryResolveWalkableCell(Vector3Int requestedCell, out Vector3Int resolvedCell)
        {
            if (IsWalkable(requestedCell))
            {
                resolvedCell = requestedCell;
                return true;
            }

            for (int radius = 1; radius <= m_nearestWalkableSearchRadius; radius++)
            {
                for (int y = -radius; y <= radius; y++)
                {
                    for (int x = -radius; x <= radius; x++)
                    {
                        if (Mathf.Abs(x) != radius && Mathf.Abs(y) != radius)
                        {
                            continue;
                        }

                        Vector3Int candidate = requestedCell + new Vector3Int(x, y);
                        if (IsWalkable(candidate))
                        {
                            resolvedCell = candidate;
                            return true;
                        }
                    }
                }
            }

            resolvedCell = default;
            return false;
        }

        /// <summary>
        /// 第三方 A* 在 walkableDiagonals=false 时仍会返回“至少一侧正交格可走”的斜邻步。
        /// 连续移动角色有碰撞体积，直接连斜线会擦进另一侧悬崖角，因此这里把斜步展开为两个合法正交步。
        /// </summary>
        private (int x, int y)[] ExpandDiagonalSteps((int x, int y)[] gridPath)
        {
            if (gridPath == null || gridPath.Length == 0)
            {
                return Array.Empty<(int x, int y)>();
            }

            List<(int x, int y)> expandedPath = new() { gridPath[0] };
            for (int i = 1; i < gridPath.Length; i++)
            {
                (int x, int y) previous = expandedPath[^1];
                (int x, int y) current = gridPath[i];
                int deltaX = current.x - previous.x;
                int deltaY = current.y - previous.y;
                if (Mathf.Abs(deltaX) > 1 || Mathf.Abs(deltaY) > 1)
                {
                    return Array.Empty<(int x, int y)>();
                }

                if (deltaX != 0 && deltaY != 0)
                {
                    (int x, int y) horizontalBridge = (current.x, previous.y);
                    (int x, int y) verticalBridge = (previous.x, current.y);
                    bool canUseHorizontalBridge =
                        IsLegalCardinalStep(previous, horizontalBridge) &&
                        IsLegalCardinalStep(horizontalBridge, current);
                    bool canUseVerticalBridge =
                        IsLegalCardinalStep(previous, verticalBridge) &&
                        IsLegalCardinalStep(verticalBridge, current);

                    if (!canUseHorizontalBridge && !canUseVerticalBridge)
                    {
                        return Array.Empty<(int x, int y)>();
                    }

                    (int x, int y) bridge = canUseHorizontalBridge && canUseVerticalBridge
                        ? GetTraversalCost(horizontalBridge) <= GetTraversalCost(verticalBridge)
                            ? horizontalBridge
                            : verticalBridge
                        : canUseHorizontalBridge
                            ? horizontalBridge
                            : verticalBridge;
                    expandedPath.Add(bridge);
                }

                expandedPath.Add(current);
            }

            return expandedPath.ToArray();
        }

        private bool ValidateElevationTransitions((int x, int y)[] gridPath)
        {
            for (int i = 1; i < gridPath.Length; i++)
            {
                Vector3Int previousCell = IndexToCell(gridPath[i - 1].x, gridPath[i - 1].y);
                Vector3Int currentCell = IndexToCell(gridPath[i].x, gridPath[i].y);
                if (!TryGetTile(previousCell, out TerrainNavigationTile previousTile) ||
                    !TryGetTile(currentCell, out TerrainNavigationTile currentTile))
                {
                    return false;
                }

                if (!CanTraverseElevation(previousCell, previousTile, currentCell, currentTile))
                {
                    return false;
                }
            }

            return true;
        }

        private bool IsLegalCardinalStep((int x, int y) from, (int x, int y) to)
        {
            if (Mathf.Abs(to.x - from.x) + Mathf.Abs(to.y - from.y) != 1)
            {
                return false;
            }

            Vector3Int fromCell = IndexToCell(from.x, from.y);
            Vector3Int toCell = IndexToCell(to.x, to.y);
            return CanTraverseCardinalCells(fromCell, toCell);
        }

        private float GetTraversalCost((int x, int y) index)
        {
            return m_cachedCostMap[index.y, index.x];
        }

        private bool CanTraverseCardinalCells(Vector3Int fromCell, Vector3Int toCell)
        {
            if (Mathf.Abs(toCell.x - fromCell.x) + Mathf.Abs(toCell.y - fromCell.y) != 1)
            {
                return false;
            }

            return TryGetTile(fromCell, out TerrainNavigationTile fromTile) &&
                TryGetTile(toCell, out TerrainNavigationTile toTile) &&
                fromTile.Walkable &&
                toTile.Walkable &&
                CanTraverseElevation(fromCell, fromTile, toCell, toTile);
        }

        private bool IsInsideElementArea(
            Vector3Int cell,
            in ElementApplication application)
        {
            if (application.Area.Kind == EElementAreaKind.Point)
            {
                return cell == ActiveRuleTilemap.WorldToCell(application.Origin);
            }

            Vector2 cellCenter = ActiveRuleTilemap.GetCellCenterWorld(cell);
            Vector2 offset = cellCenter - application.Origin;
            float radius = application.Area.Radius;
            if (offset.sqrMagnitude > radius * radius + 0.0001f)
            {
                return false;
            }

            if (application.Area.Kind == EElementAreaKind.Circle ||
                offset.sqrMagnitude <= 0.000001f)
            {
                return true;
            }

            float minimumDot = Mathf.Cos(
                application.Area.ConeHalfAngleDegrees * Mathf.Deg2Rad);
            return Vector2.Dot(offset.normalized, application.Direction) >= minimumDot;
        }

        private void UpdateCachedTraversalCost(Vector3Int cell, float stateMultiplier)
        {
            if (!TryGetTile(cell, out TerrainNavigationTile tile) ||
                !TryCellToIndex(cell, out int x, out int y))
            {
                return;
            }

            m_cachedCostMap[y, x] = tile.Walkable
                ? tile.TraversalCost * Mathf.Max(0.01f, stateMultiplier)
                : -1.0f;
        }

        private static bool CanTraverseElevation(
            Vector3Int previousCell,
            TerrainNavigationTile previousTile,
            Vector3Int currentCell,
            TerrainNavigationTile currentTile)
        {
            int elevationDifference = Mathf.Abs(previousTile.Elevation - currentTile.Elevation);
            if (elevationDifference == 0)
            {
                return true;
            }

            if (elevationDifference > 1 ||
                !TryResolveRampDirection(previousTile, currentTile, out ETerrainRampDirection rampDirection))
            {
                return false;
            }

            Vector3Int lowCell = previousTile.Elevation < currentTile.Elevation
                ? previousCell
                : currentCell;
            Vector3Int highCell = previousTile.Elevation < currentTile.Elevation
                ? currentCell
                : previousCell;
            Vector2Int lowToHighStep = new(
                highCell.x - lowCell.x,
                highCell.y - lowCell.y);
            return IsStepTowardRampDirection(lowToHighStep, rampDirection);
        }

        private static bool TryResolveRampDirection(
            TerrainNavigationTile firstTile,
            TerrainNavigationTile secondTile,
            out ETerrainRampDirection rampDirection)
        {
            rampDirection = ETerrainRampDirection.None;
            if (!TryMergeRampDirection(firstTile, ref rampDirection) ||
                !TryMergeRampDirection(secondTile, ref rampDirection))
            {
                return false;
            }

            return rampDirection != ETerrainRampDirection.None;
        }

        private static bool TryMergeRampDirection(
            TerrainNavigationTile tile,
            ref ETerrainRampDirection rampDirection)
        {
            if (tile.TransitionKind != ETerrainTransitionKind.Ramp)
            {
                return true;
            }

            if (tile.RampDirection == ETerrainRampDirection.None ||
                rampDirection != ETerrainRampDirection.None &&
                rampDirection != tile.RampDirection)
            {
                return false;
            }

            rampDirection = tile.RampDirection;
            return true;
        }

        private static bool IsStepTowardRampDirection(
            Vector2Int lowToHighStep,
            ETerrainRampDirection rampDirection)
        {
            if (Mathf.Abs(lowToHighStep.x) + Mathf.Abs(lowToHighStep.y) != 1)
            {
                return false;
            }

            return rampDirection switch
            {
                ETerrainRampDirection.NorthEast =>
                    lowToHighStep == Vector2Int.up || lowToHighStep == Vector2Int.right,
                ETerrainRampDirection.NorthWest =>
                    lowToHighStep == Vector2Int.up || lowToHighStep == Vector2Int.left,
                ETerrainRampDirection.SouthEast =>
                    lowToHighStep == Vector2Int.down || lowToHighStep == Vector2Int.right,
                ETerrainRampDirection.SouthWest =>
                    lowToHighStep == Vector2Int.down || lowToHighStep == Vector2Int.left,
                _ => false
            };
        }

        private Vector2[] ConvertToWorldPath(
            (int x, int y)[] gridPath,
            bool useRequestedDestination,
            Vector2 requestedDestination)
        {
            if (gridPath.Length == 1)
            {
                Vector3Int onlyCell = IndexToCell(gridPath[0].x, gridPath[0].y);
                return new[]
                {
                    useRequestedDestination
                        ? requestedDestination
                        : (Vector2)ActiveRuleTilemap.GetCellCenterWorld(onlyCell)
                };
            }

            List<Vector2> sampledPoints = new();
            List<bool> preservedPoints = new();
            AppendWorldPoint(
                sampledPoints,
                preservedPoints,
                ActiveRuleTilemap.GetCellCenterWorld(IndexToCell(gridPath[0].x, gridPath[0].y)),
                preserve: false);

            int pathIndex = 1;
            while (pathIndex < gridPath.Length)
            {
                if (TryAppendRampCenterLine(
                    gridPath,
                    pathIndex,
                    sampledPoints,
                    preservedPoints,
                    out int nextPathIndex))
                {
                    pathIndex = nextPathIndex;
                    continue;
                }

                Vector3Int cell = IndexToCell(gridPath[pathIndex].x, gridPath[pathIndex].y);
                AppendWorldPoint(
                    sampledPoints,
                    preservedPoints,
                    ActiveRuleTilemap.GetCellCenterWorld(cell),
                    preserve: false);
                pathIndex++;
            }

            if (useRequestedDestination)
            {
                sampledPoints[^1] = requestedDestination;
                preservedPoints[^1] = true;
            }

            List<Vector2> compressedPoints = CompressWorldPoints(sampledPoints, preservedPoints);
            compressedPoints.RemoveAt(0);
            return compressedPoints.ToArray();
        }

        /// <summary>
        /// Godot 楼梯示例通过逐帧修正速度让角色沿斜线移动。
        /// 本项目把同一思想上移到路径层：坡道格仍供 A* 选路，但所有单位最终共享作者指定的中心线。
        /// </summary>
        private bool TryAppendRampCenterLine(
            (int x, int y)[] gridPath,
            int startIndex,
            List<Vector2> sampledPoints,
            List<bool> preservedPoints,
            out int nextPathIndex)
        {
            nextPathIndex = startIndex + 1;
            Vector3Int startCell = IndexToCell(gridPath[startIndex].x, gridPath[startIndex].y);
            if (!TryGetTile(startCell, out TerrainNavigationTile startTile) ||
                startTile.TransitionKind != ETerrainTransitionKind.Ramp ||
                startTile.RampDirection == ETerrainRampDirection.None)
            {
                return false;
            }

            int endIndex = startIndex;
            int minimumElevation = startTile.Elevation;
            int maximumElevation = startTile.Elevation;
            while (endIndex + 1 < gridPath.Length)
            {
                Vector3Int candidateCell = IndexToCell(
                    gridPath[endIndex + 1].x,
                    gridPath[endIndex + 1].y);
                if (!TryGetTile(candidateCell, out TerrainNavigationTile candidateTile) ||
                    candidateTile.TransitionKind != ETerrainTransitionKind.Ramp ||
                    candidateTile.RampDirection != startTile.RampDirection)
                {
                    break;
                }

                endIndex++;
                minimumElevation = Mathf.Min(minimumElevation, candidateTile.Elevation);
                maximumElevation = Mathf.Max(maximumElevation, candidateTile.Elevation);
            }

            if (endIndex == startIndex || minimumElevation == maximumElevation)
            {
                return false;
            }

            Vector3Int endCell = IndexToCell(gridPath[endIndex].x, gridPath[endIndex].y);
            Vector2Int runDelta = new(endCell.x - startCell.x, endCell.y - startCell.y);
            Vector2Int authoredDirection = GetRampDiagonalDirection(startTile.RampDirection);
            if (!IsRampRunAligned(runDelta, authoredDirection))
            {
                return false;
            }

            Vector2 entrance = ActiveRuleTilemap.GetCellCenterWorld(startCell);
            Vector2 exit = ActiveRuleTilemap.GetCellCenterWorld(endCell);
            AppendWorldPoint(sampledPoints, preservedPoints, entrance, preserve: true);
            AppendWorldPoint(
                sampledPoints,
                preservedPoints,
                (entrance + exit) * 0.5f,
                preserve: true);
            AppendWorldPoint(sampledPoints, preservedPoints, exit, preserve: true);
            nextPathIndex = endIndex + 1;
            return true;
        }

        private static bool IsRampRunAligned(Vector2Int runDelta, Vector2Int authoredDirection)
        {
            if (runDelta.x == 0 || runDelta.y == 0 ||
                Mathf.Abs(runDelta.x) != Mathf.Abs(runDelta.y))
            {
                return false;
            }

            Vector2Int runDirection = new(Math.Sign(runDelta.x), Math.Sign(runDelta.y));
            return runDirection == authoredDirection || runDirection == -authoredDirection;
        }

        private static Vector2Int GetRampDiagonalDirection(ETerrainRampDirection rampDirection)
        {
            return rampDirection switch
            {
                ETerrainRampDirection.NorthEast => new Vector2Int(1, 1),
                ETerrainRampDirection.NorthWest => new Vector2Int(-1, 1),
                ETerrainRampDirection.SouthEast => new Vector2Int(1, -1),
                ETerrainRampDirection.SouthWest => new Vector2Int(-1, -1),
                _ => Vector2Int.zero
            };
        }

        private static void AppendWorldPoint(
            List<Vector2> points,
            List<bool> preservedPoints,
            Vector2 point,
            bool preserve)
        {
            if (points.Count > 0 && (points[^1] - point).sqrMagnitude <= 0.000001f)
            {
                preservedPoints[^1] |= preserve;
                return;
            }

            points.Add(point);
            preservedPoints.Add(preserve);
        }

        private static List<Vector2> CompressWorldPoints(
            IReadOnlyList<Vector2> sampledPoints,
            IReadOnlyList<bool> preservedPoints)
        {
            List<Vector2> compressedPoints = new(sampledPoints.Count) { sampledPoints[0] };
            for (int i = 1; i < sampledPoints.Count - 1; i++)
            {
                if (preservedPoints[i] ||
                    !AreCollinearInSameDirection(
                        compressedPoints[^1],
                        sampledPoints[i],
                        sampledPoints[i + 1]))
                {
                    compressedPoints.Add(sampledPoints[i]);
                }
            }

            compressedPoints.Add(sampledPoints[^1]);
            return compressedPoints;
        }

        private static bool AreCollinearInSameDirection(
            Vector2 previous,
            Vector2 current,
            Vector2 next)
        {
            Vector2 firstSegment = current - previous;
            Vector2 secondSegment = next - current;
            float cross = firstSegment.x * secondSegment.y - firstSegment.y * secondSegment.x;
            return Mathf.Abs(cross) <= 0.0001f &&
                Vector2.Dot(firstSegment, secondSegment) > 0.0f;
        }

        private bool IsWalkable(Vector3Int cell)
        {
            return TryGetTile(cell, out TerrainNavigationTile tile) && tile.Walkable;
        }

        private bool TryGetTile(Vector3Int cell, out TerrainNavigationTile tile)
        {
            tile = null;
            if (!TryCellToIndex(cell, out int x, out int y))
            {
                return false;
            }

            tile = m_cachedTiles[y, x];
            return tile != null;
        }

        private bool TryCellToIndex(Vector3Int cell, out int x, out int y)
        {
            x = cell.x - m_cachedBounds.xMin;
            y = cell.y - m_cachedBounds.yMin;
            return x >= 0 && y >= 0 &&
                x < m_cachedBounds.size.x &&
                y < m_cachedBounds.size.y;
        }

        private (int x, int y) CellToIndex(Vector3Int cell)
        {
            return (cell.x - m_cachedBounds.xMin, cell.y - m_cachedBounds.yMin);
        }

        private Vector3Int IndexToCell(int x, int y)
        {
            return new Vector3Int(m_cachedBounds.xMin + x, m_cachedBounds.yMin + y);
        }

        private void OnDrawGizmos()
        {
            if (!m_drawLastNavigationPath || !m_hasDebugPathRequest)
            {
                return;
            }

            Tilemap activeRuleTilemap = ActiveRuleTilemap;
            float z = (activeRuleTilemap != null ? activeRuleTilemap.transform.position.z : transform.position.z) - 0.05f;
            Vector3 start = ToDebugPosition(m_lastDebugStart, z);
            Vector3 destination = ToDebugPosition(m_lastDebugDestination, z);

            Gizmos.color = Color.yellow;
            Gizmos.DrawWireSphere(start, m_debugMarkerRadius);

            if (!m_lastDebugPathSucceeded)
            {
                Gizmos.color = m_debugFailureColor;
                Gizmos.DrawWireSphere(destination, m_debugMarkerRadius);
                DrawFailureCross(destination);
                return;
            }

            Gizmos.color = m_debugPathColor;
            Gizmos.DrawWireSphere(destination, m_debugMarkerRadius);
            Vector3 previous = start;
            for (int i = 0; i < m_lastDebugWorldPath.Length; i++)
            {
                Vector3 waypoint = ToDebugPosition(m_lastDebugWorldPath[i], z);
                Gizmos.DrawLine(previous, waypoint);
                Gizmos.DrawWireSphere(waypoint, m_debugMarkerRadius * 0.65f);
                previous = waypoint;
            }

            Gizmos.DrawSphere(previous, m_debugMarkerRadius * 0.45f);
        }

        private void DrawFailureCross(Vector3 destination)
        {
            float radius = m_debugMarkerRadius * 0.75f;
            Gizmos.DrawLine(
                destination + new Vector3(-radius, -radius, 0.0f),
                destination + new Vector3(radius, radius, 0.0f));
            Gizmos.DrawLine(
                destination + new Vector3(-radius, radius, 0.0f),
                destination + new Vector3(radius, -radius, 0.0f));
        }

        private static Vector3 ToDebugPosition(Vector2 position, float z)
        {
            return new Vector3(position.x, position.y, z);
        }
    }
}
