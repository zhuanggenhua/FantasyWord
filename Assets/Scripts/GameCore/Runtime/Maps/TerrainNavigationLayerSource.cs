using System;
using UnityEngine;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 一个逻辑地形层的作者来源。当前阶段先承载规则 Tilemap，
    /// 后续会继续扩展碰撞带、表现带和点击选择遮罩。
    /// </summary>
    [Serializable]
    public sealed class TerrainNavigationLayerSource
    {
        [InspectorName("地形层 ID")]
        [Tooltip("逻辑地形层稳定 ID。0 是旧地图兼容的默认层。")]
        [SerializeField] private int m_layerId = TerrainNodeKey.DefaultLayerId;

        [InspectorName("规则 Tilemap")]
        [Tooltip("该逻辑层的可行走、地表、层级和通行代价作者数据。")]
        [SerializeField] private Tilemap m_ruleTilemap = null;

        [InspectorName("玩法高度")]
        [Tooltip("该层相对玩法高度，用于多层调试和过渡校验。")]
        [SerializeField] private int m_elevation = 0;

        [InspectorName("碰撞带")]
        [Tooltip("少量可复用地形碰撞带编号。首期只登记数据，不直接切换物理层。")]
        [Min(0)]
        [SerializeField] private int m_collisionBand = 0;

        [InspectorName("表现排序带")]
        [Tooltip("该层实体渲染排序基带。首期只登记数据，不直接改表现入口。")]
        [SerializeField] private int m_presentationBand = 0;

        public int LayerId => m_layerId;
        public Tilemap RuleTilemap => m_ruleTilemap;
        public int Elevation => m_elevation;
        public int CollisionBand => Mathf.Max(0, m_collisionBand);
        public int PresentationBand => m_presentationBand;
        public bool IsValid => m_ruleTilemap != null;

        public TerrainNodeKey CreateNodeKey(Vector3Int cell)
        {
            return new TerrainNodeKey(m_layerId, cell);
        }
    }
}
