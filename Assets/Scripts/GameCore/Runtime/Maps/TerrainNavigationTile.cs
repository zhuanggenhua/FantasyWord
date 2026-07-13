using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 地图作者在规则 Tilemap 上绘制的单格玩法数据。
    /// 它不负责显示地形，只提供可行走、地形层级、坡道和基础地表真相。
    /// </summary>
    [CreateAssetMenu(fileName = "地形规则-", menuName = "FantasyWord/地图/地形导航瓦片")]
    public sealed class TerrainNavigationTile : Tile
    {
        [Header("移动规则")]
        [InspectorName("可行走")]
        [Tooltip("关闭后该格不会进入路径数据。悬崖正面、深水和实体阻挡应使用不可行走格。")]
        [SerializeField] private bool m_walkable = true;

        [InspectorName("地形层级")]
        [Min(0)]
        [Tooltip("低地通常为 0，高台依次增加。它只参与玩法查询，不改变角色的连续世界坐标。")]
        [SerializeField] private int m_elevation = 0;

        [InspectorName("过渡类型")]
        [Tooltip("不同地形层级之间只有坡道格允许连接；阻挡格即使误开可行走也会被拒绝。")]
        [SerializeField] private ETerrainTransitionKind m_transitionKind = ETerrainTransitionKind.Ground;

        [InspectorName("坡道上坡方向")]
        [Tooltip("从低层指向高层的视觉方向。坡道未配置方向时不能承担跨层连接，普通地面会忽略该值。")]
        [SerializeField] private ETerrainRampDirection m_rampDirection = ETerrainRampDirection.None;

        [Header("地表规则")]
        [InspectorName("基础地表")]
        [Tooltip("后续移动代价、脚步声和元素地表反应都从这里查询，不从视觉 Sprite 名称推断。")]
        [SerializeField] private ETerrainSurfaceKind m_surfaceKind = ETerrainSurfaceKind.Grass;

        [InspectorName("通行代价")]
        [Min(0.01f)]
        [Tooltip("A* 进入该格的相对代价。1 为普通地面，更高的值会让单位优先绕行。")]
        [SerializeField] private float m_traversalCost = 1.0f;

        public bool Walkable => m_walkable && m_transitionKind != ETerrainTransitionKind.Blocked;
        public int Elevation => Mathf.Max(0, m_elevation);
        public ETerrainTransitionKind TransitionKind => m_transitionKind;
        public ETerrainRampDirection RampDirection =>
            m_transitionKind == ETerrainTransitionKind.Ramp
                ? m_rampDirection
                : ETerrainRampDirection.None;
        public ETerrainSurfaceKind SurfaceKind => m_surfaceKind;
        public float TraversalCost => Mathf.Max(0.01f, m_traversalCost);
    }

    public enum ETerrainTransitionKind
    {
        Ground,
        Ramp,
        Blocked
    }

    /// <summary>
    /// 坡道从低层到高层的视觉方向。
    /// 该方向同时约束跨层连接，并用于把正交格路径投影为连续坡道中心线。
    /// </summary>
    public enum ETerrainRampDirection
    {
        None = 0,
        NorthEast = 1,
        NorthWest = 2,
        SouthEast = 3,
        SouthWest = 4
    }

    public enum ETerrainSurfaceKind
    {
        None,
        Grass,
        Dirt,
        Stone,
        ShallowWater,
        Mud,
        ScorchedDirt
    }

    public enum ETerrainSurfaceCoverKind
    {
        None,
        Grass,
        Snow,
        Moss,
        Leaves,
        Flowers,
        RoadCover
    }

    [Flags]
    public enum ETerrainSurfaceCoverTraits
    {
        None = 0,
        Flammable = 1 << 0,
        Destructible = 1 << 1,
        Regrowable = 1 << 2
    }

    public enum ETerrainSurfaceCoverLifecycle
    {
        None,
        Alive,
        Burning,
        Removed,
        Regrowing
    }

    [Serializable]
    public sealed class TerrainSurfaceCoverTileMapping
    {
        [SerializeField] private TileBase m_tile = null;
        [SerializeField] private ETerrainSurfaceCoverKind m_coverKind =
            ETerrainSurfaceCoverKind.None;
        [SerializeField] private ETerrainSurfaceCoverTraits m_traits =
            ETerrainSurfaceCoverTraits.None;

        public TileBase Tile => m_tile;
        public ETerrainSurfaceCoverKind CoverKind => m_coverKind;
        public ETerrainSurfaceCoverTraits Traits => m_traits;
        public bool IsValid => m_tile != null && m_coverKind != ETerrainSurfaceCoverKind.None;
    }

    [Flags]
    public enum ETerrainRuntimeSurfaceState
    {
        None = 0,
        Wet = 1 << 0,
        Burning = 1 << 1,
        Oiled = 1 << 2,
        Electrified = 1 << 3
    }

    /// <summary>
    /// 世界规则查询得到的地形快照。
    /// 基础地表来自规则 Tile 资产，运行时状态来自地图实例，二者不会互相改写。
    /// </summary>
    public readonly struct TerrainSurfaceSample
    {
        public TerrainSurfaceSample(
            Vector3Int cell,
            int elevation,
            ETerrainSurfaceKind baseSurface,
            ETerrainSurfaceKind effectiveSurface,
            ETerrainSurfaceCoverKind baseSurfaceCover,
            ETerrainSurfaceCoverKind effectiveSurfaceCover,
            ETerrainSurfaceCoverTraits surfaceCoverTraits,
            ETerrainSurfaceCoverLifecycle surfaceCoverLifecycle,
            float baseTraversalCost,
            float effectiveTraversalCost,
            in TerrainCellRuntimeStateSnapshot runtimeStateSnapshot)
            : this(
                TerrainNodeKey.Default(cell),
                elevation,
                baseSurface,
                effectiveSurface,
                baseSurfaceCover,
                effectiveSurfaceCover,
                surfaceCoverTraits,
                surfaceCoverLifecycle,
                baseTraversalCost,
                effectiveTraversalCost,
                runtimeStateSnapshot)
        {
        }

        public TerrainSurfaceSample(
            in TerrainNodeKey nodeKey,
            int elevation,
            ETerrainSurfaceKind baseSurface,
            ETerrainSurfaceKind effectiveSurface,
            ETerrainSurfaceCoverKind baseSurfaceCover,
            ETerrainSurfaceCoverKind effectiveSurfaceCover,
            ETerrainSurfaceCoverTraits surfaceCoverTraits,
            ETerrainSurfaceCoverLifecycle surfaceCoverLifecycle,
            float baseTraversalCost,
            float effectiveTraversalCost,
            in TerrainCellRuntimeStateSnapshot runtimeStateSnapshot)
        {
            NodeKey = nodeKey;
            Elevation = elevation;
            BaseSurface = baseSurface;
            EffectiveSurface = effectiveSurface;
            BaseSurfaceCover = baseSurfaceCover;
            EffectiveSurfaceCover = effectiveSurfaceCover;
            SurfaceCoverTraits = surfaceCoverTraits;
            SurfaceCoverLifecycle = surfaceCoverLifecycle;
            BaseTraversalCost = baseTraversalCost;
            EffectiveTraversalCost = effectiveTraversalCost;
            RuntimeStateSnapshot = runtimeStateSnapshot;
        }

        public TerrainNodeKey NodeKey { get; }
        public Vector3Int Cell => NodeKey.Cell;
        public int Elevation { get; }
        public ETerrainSurfaceKind BaseSurface { get; }
        public ETerrainSurfaceKind EffectiveSurface { get; }
        public ETerrainSurfaceCoverKind BaseSurfaceCover { get; }
        public ETerrainSurfaceCoverKind EffectiveSurfaceCover { get; }
        public ETerrainSurfaceCoverTraits SurfaceCoverTraits { get; }
        public ETerrainSurfaceCoverLifecycle SurfaceCoverLifecycle { get; }
        public float BaseTraversalCost { get; }
        public float EffectiveTraversalCost { get; }
        public TerrainCellRuntimeStateSnapshot RuntimeStateSnapshot { get; }

        public float TraversalCost => EffectiveTraversalCost;
        public bool HasSurfaceCover =>
            EffectiveSurfaceCover != ETerrainSurfaceCoverKind.None;
        public bool IsSurfaceCoverFlammable =>
            (SurfaceCoverTraits & ETerrainSurfaceCoverTraits.Flammable) != 0;
        public ETerrainRuntimeSurfaceState RuntimeState => RuntimeStateSnapshot.RuntimeStateFlags;
        public IReadOnlyList<TerrainElementStateSnapshot> ActiveStates =>
            RuntimeStateSnapshot.ActiveStates;
    }
}
