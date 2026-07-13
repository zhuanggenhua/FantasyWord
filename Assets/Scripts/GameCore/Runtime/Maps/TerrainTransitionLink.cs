using System;
using System.Collections.Generic;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public sealed class TerrainTransitionLink
    {
        [Header("端点")]
        [InspectorName("起点层 ID")]
        [SerializeField] private int m_fromLayerId = TerrainNodeKey.DefaultLayerId;

        [InspectorName("起点格")]
        [SerializeField] private Vector3Int m_fromCell;

        [InspectorName("终点层 ID")]
        [SerializeField] private int m_toLayerId = TerrainNodeKey.DefaultLayerId;

        [InspectorName("终点格")]
        [SerializeField] private Vector3Int m_toCell;

        [Header("过渡")]
        [InspectorName("过渡类型")]
        [SerializeField] private ETerrainTransitionLinkKind m_kind = ETerrainTransitionLinkKind.Ramp;

        [InspectorName("允许反向")]
        [SerializeField] private bool m_bidirectional = true;

        [InspectorName("附加代价")]
        [Min(0.01f)]
        [SerializeField] private float m_traversalCost = 1.0f;

        [InspectorName("连续路径点")]
        [SerializeField] private Vector2[] m_worldWaypoints = Array.Empty<Vector2>();

        [InspectorName("切层提交点")]
        [SerializeField] private Vector2 m_commitPoint;

        public TerrainNodeKey FromNode => new(m_fromLayerId, m_fromCell);
        public TerrainNodeKey ToNode => new(m_toLayerId, m_toCell);
        public ETerrainTransitionLinkKind Kind => m_kind;
        public bool Bidirectional => m_bidirectional;
        public float TraversalCost => Mathf.Max(0.01f, m_traversalCost);
        public IReadOnlyList<Vector2> WorldWaypoints => m_worldWaypoints ?? Array.Empty<Vector2>();
        public Vector2 CommitPoint => m_commitPoint;
        public bool IsValid => FromNode != ToNode && m_kind != ETerrainTransitionLinkKind.None;

        internal TerrainTransitionLink(
            in TerrainNodeKey fromNode,
            in TerrainNodeKey toNode,
            ETerrainTransitionLinkKind kind,
            bool bidirectional,
            float traversalCost,
            Vector2[] worldWaypoints,
            Vector2 commitPoint)
        {
            m_fromLayerId = fromNode.LayerId;
            m_fromCell = fromNode.Cell;
            m_toLayerId = toNode.LayerId;
            m_toCell = toNode.Cell;
            m_kind = kind;
            m_bidirectional = bidirectional;
            m_traversalCost = Mathf.Max(0.01f, traversalCost);
            m_worldWaypoints = worldWaypoints ?? Array.Empty<Vector2>();
            m_commitPoint = commitPoint;
        }
    }

    public enum ETerrainTransitionLinkKind
    {
        None = 0,
        Ramp = 1,
        Stairs = 2,
        Ladder = 3,
        Drop = 4
    }
}
