using System;
using UnityEngine;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore
{
    [Serializable]
    public sealed class TerrainStateTileMapping
    {
        [SerializeField] private ETerrainElementStateKind m_stateKind =
            ETerrainElementStateKind.None;
        [SerializeField] private TileBase m_tile = null;
        [SerializeField] private int m_priority = 0;

        public ETerrainElementStateKind StateKind => m_stateKind;
        public TileBase Tile => m_tile;
        public int Priority => m_priority;
    }

    [Serializable]
    public sealed class TerrainSurfaceTileMapping
    {
        [SerializeField] private ETerrainSurfaceKind m_surfaceKind =
            ETerrainSurfaceKind.None;
        [SerializeField] private TileBase m_tile = null;

        public ETerrainSurfaceKind SurfaceKind => m_surfaceKind;
        public TileBase Tile => m_tile;
    }

    [Serializable]
    public sealed class TerrainSignalTileMapping
    {
        [SerializeField] private EElementPresentationSignal m_signal =
            EElementPresentationSignal.None;
        [SerializeField] private TileBase m_tile = null;
        [Min(0.01f)]
        [SerializeField] private float m_duration = 0.35f;

        public EElementPresentationSignal Signal => m_signal;
        public TileBase Tile => m_tile;
        public float Duration => Mathf.Max(0.01f, m_duration);
    }

    [CreateAssetMenu(
        fileName = "地表元素表现-",
        menuName = "FantasyWord/元素/地表元素表现配置")]
    public sealed class TerrainSurfacePresentationConfig : DatabaseEntry
    {
        [SerializeField] private TerrainStateTileMapping[] m_stateTiles =
            Array.Empty<TerrainStateTileMapping>();
        [SerializeField] private TerrainSurfaceTileMapping[] m_surfaceTiles =
            Array.Empty<TerrainSurfaceTileMapping>();
        [SerializeField] private TerrainSignalTileMapping[] m_signalTiles =
            Array.Empty<TerrainSignalTileMapping>();

        public bool TryGetTemporaryStateTile(
            in TerrainCellRuntimeStateSnapshot snapshot,
            out TileBase tile)
        {
            tile = null;
            int selectedPriority = int.MinValue;
            for (int stateIndex = 0; stateIndex < snapshot.ActiveStates.Count; stateIndex++)
            {
                ETerrainElementStateKind stateKind =
                    snapshot.ActiveStates[stateIndex].StateKind;
                for (int mappingIndex = 0;
                     mappingIndex < m_stateTiles.Length;
                     mappingIndex++)
                {
                    TerrainStateTileMapping mapping = m_stateTiles[mappingIndex];
                    if (mapping != null &&
                        mapping.StateKind == stateKind &&
                        mapping.Tile != null &&
                        mapping.Priority >= selectedPriority)
                    {
                        selectedPriority = mapping.Priority;
                        tile = mapping.Tile;
                    }
                }
            }

            return tile != null;
        }

        public bool TryGetSurfaceTile(
            ETerrainSurfaceKind surfaceKind,
            out TileBase tile)
        {
            for (int i = 0; i < m_surfaceTiles.Length; i++)
            {
                TerrainSurfaceTileMapping mapping = m_surfaceTiles[i];
                if (mapping != null &&
                    mapping.SurfaceKind == surfaceKind &&
                    mapping.Tile != null)
                {
                    tile = mapping.Tile;
                    return true;
                }
            }

            tile = null;
            return false;
        }

        public bool TryGetSignalTile(
            EElementPresentationSignal signal,
            out TileBase tile,
            out float duration)
        {
            for (int i = 0; i < m_signalTiles.Length; i++)
            {
                TerrainSignalTileMapping mapping = m_signalTiles[i];
                if (mapping != null &&
                    mapping.Signal == signal &&
                    mapping.Tile != null)
                {
                    tile = mapping.Tile;
                    duration = mapping.Duration;
                    return true;
                }
            }

            tile = null;
            duration = 0.0f;
            return false;
        }
    }
}
