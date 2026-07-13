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
        [SerializeField] private Tilemap m_surfaceCoverTilemap = null;

        private readonly List<Vector3Int> m_runtimeCells = new();
        private readonly Dictionary<Vector3Int, Coroutine> m_signalCoroutines = new();
        private readonly HashSet<Vector3Int> m_hiddenSurfaceCoverCells = new();
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
            if (m_surfaceCoverTilemap == null ||
                sample.BaseSurfaceCover == ETerrainSurfaceCoverKind.None)
            {
                return;
            }

            bool shouldHide =
                sample.EffectiveSurfaceCover == ETerrainSurfaceCoverKind.None ||
                sample.SurfaceCoverLifecycle == ETerrainSurfaceCoverLifecycle.Removed;
            if (shouldHide)
            {
                HideSurfaceCoverCell(sample.Cell);
            }
            else
            {
                RestoreSurfaceCoverCell(sample.Cell);
            }
        }

        private void HideSurfaceCoverCell(Vector3Int cell)
        {
            if (m_hiddenSurfaceCoverCells.Add(cell))
            {
                m_surfaceCoverTilemap.SetTileFlags(cell, TileFlags.None);
            }

            Color color = m_surfaceCoverTilemap.GetColor(cell);
            if (!Mathf.Approximately(color.a, 0.0f))
            {
                color.a = 0.0f;
                m_surfaceCoverTilemap.SetColor(cell, color);
            }
        }

        private void RestoreSurfaceCoverCell(Vector3Int cell)
        {
            if (!m_hiddenSurfaceCoverCells.Remove(cell) ||
                m_surfaceCoverTilemap == null)
            {
                return;
            }

            Color color = m_surfaceCoverTilemap.GetColor(cell);
            if (!Mathf.Approximately(color.a, 1.0f))
            {
                color.a = 1.0f;
                m_surfaceCoverTilemap.SetColor(cell, color);
            }
        }

        private void RestoreAllSurfaceCoverCells()
        {
            if (m_surfaceCoverTilemap != null)
            {
                foreach (Vector3Int cell in m_hiddenSurfaceCoverCells)
                {
                    Color color = m_surfaceCoverTilemap.GetColor(cell);
                    color.a = 1.0f;
                    m_surfaceCoverTilemap.SetColor(cell, color);
                }
            }

            m_hiddenSurfaceCoverCells.Clear();
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
    }
}
