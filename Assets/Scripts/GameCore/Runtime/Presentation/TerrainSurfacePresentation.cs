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
        [SerializeField] private Tilemap m_resultOverrideTilemap = null;

        private readonly List<Vector3Int> m_runtimeCells = new();
        private readonly Dictionary<Vector3Int, Coroutine> m_signalCoroutines = new();
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

            if (m_resultOverrideTilemap == null)
            {
                Debug.LogError(
                    "TerrainSurfacePresentation 缺少结果覆盖 Tilemap。",
                    this);
                valid = false;
            }

            return valid;
        }

        private void RefreshAllRuntimeCells()
        {
            m_temporaryEffectTilemap.ClearAllTiles();
            m_resultOverrideTilemap.ClearAllTiles();
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
            m_resultOverrideTilemap.ClearAllTiles();
        }

        private void RefreshCell(in TerrainSurfaceSample sample)
        {
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

            if (sample.EffectiveSurface != sample.BaseSurface)
            {
                if (m_config.TryGetSurfaceTile(
                        sample.EffectiveSurface,
                        out TileBase resultTile))
                {
                    m_resultOverrideTilemap.SetTile(sample.Cell, resultTile);
                }
                else
                {
                    m_resultOverrideTilemap.SetTile(sample.Cell, null);
                    ReportMissingMappingOnce($"surface:{sample.EffectiveSurface}");
                }
            }
            else
            {
                m_resultOverrideTilemap.SetTile(sample.Cell, null);
            }
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
