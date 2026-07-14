using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Tilemaps;

namespace FantasyWord.GameCore
{
    [DisallowMultipleComponent]
    public sealed class TerrainSurfacePresentation : MonoBehaviour
    {
        [Header("状态来源")]
        [SerializeField] private TerrainNavigationMap m_navigationMap = null;
        [SerializeField] private TerrainSurfacePresentationConfig m_config = null;

        [Header("表现层")]
        [SerializeField] private Tilemap m_temporaryEffectTilemap = null;

        private readonly List<Vector3Int> m_runtimeCells = new();
        private readonly Dictionary<Vector3Int, Coroutine> m_signalCoroutines = new();
        private readonly Dictionary<int, HiddenSurfaceCoverSource> m_hiddenSurfaceCoverSources =
            new();
        private readonly HashSet<string> m_reportedMissingMappings = new();

        private void OnEnable()
        {
            if (!ValidateReferences())
            {
                return;
            }

            m_navigationMap.CellStateChanged += OnCellStateChanged;
            m_navigationMap.RuntimeSurfaceStatesCleared += OnRuntimeSurfaceStatesCleared;
            RefreshAllRuntimeCells();
        }

        private void OnDisable()
        {
            if (m_navigationMap != null)
            {
                m_navigationMap.CellStateChanged -= OnCellStateChanged;
                m_navigationMap.RuntimeSurfaceStatesCleared -= OnRuntimeSurfaceStatesCleared;
            }

            StopAllSignalCoroutines();
            RestoreAllSurfaceCoverCells();
        }

        private bool ValidateReferences()
        {
            bool valid = true;
            if (m_navigationMap == null)
            {
                Debug.LogError(
                    "TerrainSurfacePresentation 缺少 TerrainNavigationMap 引用。",
                    this);
                valid = false;
            }

            if (m_config == null)
            {
                Debug.LogError(
                    "TerrainSurfacePresentation 缺少地表元素表现配置。",
                    this);
                valid = false;
            }

            if (m_temporaryEffectTilemap == null)
            {
                Debug.LogError(
                    "TerrainSurfacePresentation 缺少临时效果 Tilemap。",
                    this);
                valid = false;
            }

            return valid;
        }

        private void RefreshAllRuntimeCells()
        {
            m_temporaryEffectTilemap.ClearAllTiles();
            RestoreAllSurfaceCoverCells();
            m_navigationMap.CollectRuntimeStateCells(m_runtimeCells);
            for (int i = 0; i < m_runtimeCells.Count; i++)
            {
                if (m_navigationMap.TryGetSurfaceSample(
                        m_runtimeCells[i],
                        out TerrainSurfaceSample sample))
                {
                    RefreshCell(sample);
                }
            }
        }

        private void OnCellStateChanged(TerrainCellStateChange change)
        {
            RefreshCell(change.Current);

            if (change.PresentationSignal != EElementPresentationSignal.None)
            {
                PlaySignal(change.Cell, change.PresentationSignal);
            }
        }

        private void OnRuntimeSurfaceStatesCleared()
        {
            StopAllSignalCoroutines();
            m_temporaryEffectTilemap.ClearAllTiles();
            RestoreAllSurfaceCoverCells();
        }

        private void RefreshCell(in TerrainSurfaceSample sample)
        {
            RefreshSurfaceCoverCell(sample);

            if (m_config.TryGetTemporaryStateTile(
                    sample.RuntimeStateSnapshot,
                    out TileBase temporaryTile))
            {
                m_temporaryEffectTilemap.SetTile(sample.Cell, temporaryTile);
            }
            else
            {
                m_temporaryEffectTilemap.SetTile(sample.Cell, null);
                if (sample.ActiveStates.Count > 0)
                {
                    ReportMissingMappingOnce($"state:{sample.RuntimeState}");
                }
            }

            // 燃尽后的“露出土壤”不是盖一张结果 Tile，而是由正式地图层移除草覆盖后露出底层土壤。
            // 这里仍只负责临时元素效果；永久/持久地貌变化必须走后续世界地形变更链路。
        }

        private void RefreshSurfaceCoverCell(in TerrainSurfaceSample sample)
        {
            if (sample.BaseSurfaceCover == ETerrainSurfaceCoverKind.None ||
                !sample.SurfaceCoverSource.IsValid)
            {
                return;
            }

            if (!m_navigationMap.TryGetSurfaceCoverTilemap(
                    sample.SurfaceCoverSource,
                    out Tilemap surfaceTilemap))
            {
                ReportMissingMappingOnce($"surface-source:{sample.SurfaceCoverSource.SourceId}");
                return;
            }

            bool shouldHide =
                sample.EffectiveSurfaceCover == ETerrainSurfaceCoverKind.None ||
                sample.SurfaceCoverLifecycle == ETerrainSurfaceCoverLifecycle.Removed;
            if (shouldHide)
            {
                HideSurfaceCoverCell(
                    sample.SurfaceCoverSource,
                    surfaceTilemap,
                    sample.Cell);
            }
            else
            {
                RestoreSurfaceCoverCell(
                    sample.SurfaceCoverSource,
                    surfaceTilemap,
                    sample.Cell);
            }
        }

        private void HideSurfaceCoverCell(
            in TerrainSurfaceCoverSourceReference sourceReference,
            Tilemap surfaceTilemap,
            Vector3Int cell)
        {
            if (!m_hiddenSurfaceCoverSources.TryGetValue(
                    sourceReference.SourceId,
                    out HiddenSurfaceCoverSource hiddenSource))
            {
                hiddenSource = new HiddenSurfaceCoverSource(sourceReference);
                m_hiddenSurfaceCoverSources.Add(sourceReference.SourceId, hiddenSource);
            }

            if (hiddenSource.Cells.Add(cell))
            {
                surfaceTilemap.SetTileFlags(cell, TileFlags.None);
            }

            Color color = surfaceTilemap.GetColor(cell);
            if (!Mathf.Approximately(color.a, 0.0f))
            {
                color.a = 0.0f;
                surfaceTilemap.SetColor(cell, color);
            }
        }

        private void RestoreSurfaceCoverCell(
            in TerrainSurfaceCoverSourceReference sourceReference,
            Tilemap surfaceTilemap,
            Vector3Int cell)
        {
            if (!m_hiddenSurfaceCoverSources.TryGetValue(
                    sourceReference.SourceId,
                    out HiddenSurfaceCoverSource hiddenSource) ||
                !hiddenSource.Cells.Remove(cell))
            {
                return;
            }

            Color color = surfaceTilemap.GetColor(cell);
            if (!Mathf.Approximately(color.a, 1.0f))
            {
                color.a = 1.0f;
                surfaceTilemap.SetColor(cell, color);
            }

            if (hiddenSource.Cells.Count == 0)
            {
                m_hiddenSurfaceCoverSources.Remove(sourceReference.SourceId);
            }
        }

        private void RestoreAllSurfaceCoverCells()
        {
            foreach (HiddenSurfaceCoverSource hiddenSource in m_hiddenSurfaceCoverSources.Values)
            {
                if (!m_navigationMap.TryGetSurfaceCoverTilemap(
                        hiddenSource.SourceReference,
                        out Tilemap surfaceTilemap))
                {
                    continue;
                }

                foreach (Vector3Int cell in hiddenSource.Cells)
                {
                    Color color = surfaceTilemap.GetColor(cell);
                    color.a = 1.0f;
                    surfaceTilemap.SetColor(cell, color);
                }
            }

            m_hiddenSurfaceCoverSources.Clear();
        }

        private void PlaySignal(
            Vector3Int cell,
            EElementPresentationSignal signal)
        {
            if (!m_config.TryGetSignalTile(signal, out TileBase tile, out float duration))
            {
                ReportMissingMappingOnce($"signal:{signal}");
                if (m_navigationMap.TryGetSurfaceSample(cell, out TerrainSurfaceSample sample))
                {
                    RefreshCell(sample);
                }

                return;
            }

            if (m_signalCoroutines.TryGetValue(cell, out Coroutine activeCoroutine))
            {
                StopCoroutine(activeCoroutine);
            }

            m_temporaryEffectTilemap.SetTile(cell, tile);
            m_signalCoroutines[cell] = StartCoroutine(
                RestoreTemporaryStateAfterSignal(cell, duration));
        }

        private IEnumerator RestoreTemporaryStateAfterSignal(
            Vector3Int cell,
            float duration)
        {
            yield return new WaitForSeconds(duration);
            m_signalCoroutines.Remove(cell);
            if (m_navigationMap.TryGetSurfaceSample(cell, out TerrainSurfaceSample sample))
            {
                RefreshCell(sample);
            }
            else
            {
                m_temporaryEffectTilemap.SetTile(cell, null);
            }
        }

        private void StopAllSignalCoroutines()
        {
            foreach (Coroutine coroutine in m_signalCoroutines.Values)
            {
                if (coroutine != null)
                {
                    StopCoroutine(coroutine);
                }
            }

            m_signalCoroutines.Clear();
        }

        private void ReportMissingMappingOnce(string key)
        {
            if (m_reportedMissingMappings.Add(key))
            {
                Debug.LogWarning(
                    $"地表元素状态有效，但表现配置缺少映射：{key}。",
                    this);
            }
        }

        private sealed class HiddenSurfaceCoverSource
        {
            public HiddenSurfaceCoverSource(
                in TerrainSurfaceCoverSourceReference sourceReference)
            {
                SourceReference = sourceReference;
            }

            public TerrainSurfaceCoverSourceReference SourceReference { get; }
            public HashSet<Vector3Int> Cells { get; } = new();
        }
    }
}
