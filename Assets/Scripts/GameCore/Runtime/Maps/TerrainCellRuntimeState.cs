using System;
using System.Collections.Generic;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public readonly struct TerrainNodeKey : IEquatable<TerrainNodeKey>
    {
        public const int DefaultLayerId = 0;

        public TerrainNodeKey(int layerId, Vector3Int cell)
        {
            LayerId = layerId;
            Cell = cell;
        }

        public int LayerId { get; }
        public Vector3Int Cell { get; }
        public bool IsDefaultLayer => LayerId == DefaultLayerId;

        public static TerrainNodeKey Default(Vector3Int cell)
        {
            return new TerrainNodeKey(DefaultLayerId, cell);
        }

        public bool Equals(TerrainNodeKey other)
        {
            return LayerId == other.LayerId && Cell == other.Cell;
        }

        public override bool Equals(object obj)
        {
            return obj is TerrainNodeKey other && Equals(other);
        }

        public override int GetHashCode()
        {
            unchecked
            {
                return (LayerId * 397) ^ Cell.GetHashCode();
            }
        }

        public override string ToString()
        {
            return $"Layer={LayerId}, Cell={Cell}";
        }

        public static bool operator ==(TerrainNodeKey left, TerrainNodeKey right)
        {
            return left.Equals(right);
        }

        public static bool operator !=(TerrainNodeKey left, TerrainNodeKey right)
        {
            return !left.Equals(right);
        }
    }

    public readonly struct TerrainElementStateSnapshot
    {
        public TerrainElementStateSnapshot(TerrainElementStateInstance state)
        {
            StateKind = state.StateKind;
            StateDefinitionId = state.StateDefinitionId;
            Intensity = state.Intensity;
            RemainingDuration = state.RemainingDuration;
            SourceEntity = state.SourceEntity;
            SourceAbilityCode = state.SourceAbilityCode;
            AppliedRuleId = state.AppliedRuleId;
        }

        public ETerrainElementStateKind StateKind { get; }
        public string StateDefinitionId { get; }
        public float Intensity { get; }
        public float RemainingDuration { get; }
        public UnityEngine.Object SourceEntity { get; }
        public int SourceAbilityCode { get; }
        public string AppliedRuleId { get; }
    }

    public readonly struct TerrainCellRuntimeStateSnapshot
    {
        public TerrainCellRuntimeStateSnapshot(
            bool hasEffectiveSurfaceOverride,
            ETerrainSurfaceKind effectiveSurface,
            bool hasSurfaceCoverOverride,
            ETerrainSurfaceCoverKind effectiveSurfaceCover,
            ETerrainSurfaceCoverLifecycle surfaceCoverLifecycle,
            ETerrainRuntimeSurfaceState runtimeStateFlags,
            ETerrainRuntimePersistencePolicy persistencePolicy,
            int revision,
            TerrainElementStateSnapshot[] activeStates)
        {
            HasEffectiveSurfaceOverride = hasEffectiveSurfaceOverride;
            EffectiveSurface = effectiveSurface;
            HasSurfaceCoverOverride = hasSurfaceCoverOverride;
            EffectiveSurfaceCover = effectiveSurfaceCover;
            SurfaceCoverLifecycle = surfaceCoverLifecycle;
            RuntimeStateFlags = runtimeStateFlags;
            PersistencePolicy = persistencePolicy;
            Revision = revision;
            ActiveStates = activeStates ?? Array.Empty<TerrainElementStateSnapshot>();
        }

        public bool HasEffectiveSurfaceOverride { get; }
        public ETerrainSurfaceKind EffectiveSurface { get; }
        public bool HasSurfaceCoverOverride { get; }
        public ETerrainSurfaceCoverKind EffectiveSurfaceCover { get; }
        public ETerrainSurfaceCoverLifecycle SurfaceCoverLifecycle { get; }
        public ETerrainRuntimeSurfaceState RuntimeStateFlags { get; }
        public ETerrainRuntimePersistencePolicy PersistencePolicy { get; }
        public int Revision { get; }
        public IReadOnlyList<TerrainElementStateSnapshot> ActiveStates { get; }

        public static TerrainCellRuntimeStateSnapshot Empty(ETerrainSurfaceKind baseSurface)
        {
            return Empty(baseSurface, ETerrainSurfaceCoverKind.None);
        }

        public static TerrainCellRuntimeStateSnapshot Empty(
            ETerrainSurfaceKind baseSurface,
            ETerrainSurfaceCoverKind baseSurfaceCover)
        {
            return new TerrainCellRuntimeStateSnapshot(
                false,
                baseSurface,
                false,
                baseSurfaceCover,
                baseSurfaceCover == ETerrainSurfaceCoverKind.None
                    ? ETerrainSurfaceCoverLifecycle.None
                    : ETerrainSurfaceCoverLifecycle.Alive,
                ETerrainRuntimeSurfaceState.None,
                ETerrainRuntimePersistencePolicy.Transient,
                0,
                Array.Empty<TerrainElementStateSnapshot>());
        }
    }

    public readonly struct TerrainCellStateChange
    {
        public TerrainCellStateChange(
            TerrainNavigationMap map,
            in TerrainNodeKey nodeKey,
            in TerrainSurfaceSample previous,
            in TerrainSurfaceSample current,
            EElementPresentationSignal presentationSignal)
        {
            Map = map;
            NodeKey = nodeKey;
            Previous = previous;
            Current = current;
            PresentationSignal = presentationSignal;
        }

        public TerrainNavigationMap Map { get; }
        public TerrainNodeKey NodeKey { get; }
        public Vector3Int Cell => NodeKey.Cell;
        public TerrainSurfaceSample Previous { get; }
        public TerrainSurfaceSample Current { get; }
        public EElementPresentationSignal PresentationSignal { get; }
    }

    [Serializable]
    public sealed class TerrainElementStateInstance
    {
        [SerializeField] private ETerrainElementStateKind m_stateKind;
        [SerializeField] private string m_stateDefinitionId;
        [SerializeField] private float m_intensity;
        [SerializeField] private float m_remainingDuration;
        [SerializeField] private UnityEngine.Object m_sourceEntity;
        [SerializeField] private int m_sourceAbilityCode;
        [SerializeField] private string m_appliedRuleId;

        public TerrainElementStateInstance(
            ETerrainElementStateKind stateKind,
            float intensity,
            float remainingDuration,
            in TerrainElementStateSource source,
            string appliedRuleId,
            string stateDefinitionId = "")
        {
            m_stateKind = stateKind;
            m_stateDefinitionId = stateDefinitionId ?? string.Empty;
            m_intensity = Mathf.Clamp01(intensity);
            m_remainingDuration = Mathf.Max(0.0f, remainingDuration);
            m_sourceEntity = source.SourceEntity;
            m_sourceAbilityCode = source.SourceAbilityCode;
            m_appliedRuleId = appliedRuleId ?? string.Empty;
        }

        public ETerrainElementStateKind StateKind => m_stateKind;
        public string StateDefinitionId => m_stateDefinitionId;
        public float Intensity => m_intensity;
        public float RemainingDuration => m_remainingDuration;
        public UnityEngine.Object SourceEntity => m_sourceEntity;
        public int SourceAbilityCode => m_sourceAbilityCode;
        public string AppliedRuleId => m_appliedRuleId;

        internal bool Merge(
            float intensity,
            float duration,
            in TerrainElementStateSource source,
            string appliedRuleId,
            ETerrainStateMergePolicy mergePolicy,
            string stateDefinitionId)
        {
            float nextIntensity = m_intensity;
            float nextDuration = m_remainingDuration;

            switch (mergePolicy)
            {
                case ETerrainStateMergePolicy.RefreshDuration:
                    nextIntensity = Mathf.Max(m_intensity, Mathf.Clamp01(intensity));
                    nextDuration = Mathf.Max(m_remainingDuration, Mathf.Max(0.0f, duration));
                    break;
                case ETerrainStateMergePolicy.KeepStronger:
                    if (intensity <= m_intensity)
                    {
                        return false;
                    }

                    nextIntensity = Mathf.Clamp01(intensity);
                    nextDuration = Mathf.Max(m_remainingDuration, Mathf.Max(0.0f, duration));
                    break;
                case ETerrainStateMergePolicy.StackIntensity:
                    nextIntensity = Mathf.Clamp01(m_intensity + Mathf.Max(0.0f, intensity));
                    nextDuration = Mathf.Max(m_remainingDuration, Mathf.Max(0.0f, duration));
                    break;
                case ETerrainStateMergePolicy.Reject:
                    return false;
                default:
                    throw new ArgumentOutOfRangeException(nameof(mergePolicy), mergePolicy, null);
            }

            if (Mathf.Approximately(nextIntensity, m_intensity) &&
                Mathf.Approximately(nextDuration, m_remainingDuration))
            {
                return false;
            }

            m_intensity = nextIntensity;
            m_remainingDuration = nextDuration;
            m_sourceEntity = source.SourceEntity;
            m_sourceAbilityCode = source.SourceAbilityCode;
            m_appliedRuleId = appliedRuleId ?? string.Empty;
            m_stateDefinitionId = stateDefinitionId ?? string.Empty;
            return true;
        }

        internal bool Advance(float deltaTime)
        {
            if (deltaTime <= 0.0f || m_remainingDuration <= 0.0f)
            {
                return false;
            }

            m_remainingDuration = Mathf.Max(0.0f, m_remainingDuration - deltaTime);
            return true;
        }
    }

    [Serializable]
    public sealed class TerrainCellRuntimeState
    {
        [SerializeField] private bool m_hasEffectiveSurfaceOverride;
        [SerializeField] private ETerrainSurfaceKind m_effectiveSurfaceOverride;
        [SerializeField] private bool m_hasSurfaceCoverOverride;
        [SerializeField] private ETerrainSurfaceCoverKind m_surfaceCoverOverride =
            ETerrainSurfaceCoverKind.None;
        [SerializeField] private ETerrainSurfaceCoverLifecycle m_surfaceCoverLifecycle =
            ETerrainSurfaceCoverLifecycle.None;
        [SerializeField] private List<TerrainElementStateInstance> m_activeStates = new();
        [SerializeField] private ETerrainRuntimePersistencePolicy m_persistencePolicy =
            ETerrainRuntimePersistencePolicy.Transient;
        [SerializeField] private int m_revision;

        public bool HasEffectiveSurfaceOverride => m_hasEffectiveSurfaceOverride;
        public ETerrainSurfaceKind EffectiveSurfaceOverride => m_effectiveSurfaceOverride;
        public bool HasSurfaceCoverOverride => m_hasSurfaceCoverOverride;
        public ETerrainSurfaceCoverKind SurfaceCoverOverride => m_surfaceCoverOverride;
        public ETerrainSurfaceCoverLifecycle SurfaceCoverLifecycle => m_surfaceCoverLifecycle;
        public IReadOnlyList<TerrainElementStateInstance> ActiveStates => m_activeStates;
        public ETerrainRuntimePersistencePolicy PersistencePolicy
        {
            get => m_persistencePolicy;
            set
            {
                if (m_persistencePolicy == value)
                {
                    return;
                }

                m_persistencePolicy = value;
                m_revision++;
            }
        }

        public int Revision => m_revision;
        public bool HasTimedStates
        {
            get
            {
                for (int i = 0; i < m_activeStates.Count; i++)
                {
                    if (m_activeStates[i].RemainingDuration > 0.0f)
                    {
                        return true;
                    }
                }

                return false;
            }
        }

        public bool IsEmpty =>
            !m_hasEffectiveSurfaceOverride &&
            !m_hasSurfaceCoverOverride &&
            m_activeStates.Count == 0;

        public ETerrainRuntimeSurfaceState RuntimeStateFlags
        {
            get
            {
                ETerrainRuntimeSurfaceState flags = ETerrainRuntimeSurfaceState.None;
                for (int i = 0; i < m_activeStates.Count; i++)
                {
                    flags |= m_activeStates[i].StateKind.ToRuntimeFlag();
                }

                return flags;
            }
        }

        public ETerrainSurfaceKind GetEffectiveSurface(ETerrainSurfaceKind baseSurface)
        {
            return m_hasEffectiveSurfaceOverride ? m_effectiveSurfaceOverride : baseSurface;
        }

        public ETerrainSurfaceCoverKind GetEffectiveSurfaceCover(
            ETerrainSurfaceCoverKind baseSurfaceCover)
        {
            return m_hasSurfaceCoverOverride ? m_surfaceCoverOverride : baseSurfaceCover;
        }

        public ETerrainSurfaceCoverLifecycle GetSurfaceCoverLifecycle(
            ETerrainSurfaceCoverKind baseSurfaceCover)
        {
            if (m_hasSurfaceCoverOverride)
            {
                return m_surfaceCoverLifecycle;
            }

            return baseSurfaceCover == ETerrainSurfaceCoverKind.None
                ? ETerrainSurfaceCoverLifecycle.None
                : ETerrainSurfaceCoverLifecycle.Alive;
        }

        public bool TryGetState(
            ETerrainElementStateKind stateKind,
            out TerrainElementStateInstance state)
        {
            for (int i = 0; i < m_activeStates.Count; i++)
            {
                if (m_activeStates[i].StateKind == stateKind)
                {
                    state = m_activeStates[i];
                    return true;
                }
            }

            state = null;
            return false;
        }

        public bool ApplyOrMergeState(
            ETerrainElementStateKind stateKind,
            float intensity,
            float duration,
            in TerrainElementStateSource source,
            string appliedRuleId,
            ETerrainStateMergePolicy mergePolicy,
            string stateDefinitionId = "")
        {
            if (stateKind == ETerrainElementStateKind.None)
            {
                return false;
            }

            if (TryGetState(stateKind, out TerrainElementStateInstance existingState))
            {
                if (!existingState.Merge(
                        intensity,
                        duration,
                        source,
                        appliedRuleId,
                        mergePolicy,
                        stateDefinitionId))
                {
                    return false;
                }
            }
            else
            {
                m_activeStates.Add(new TerrainElementStateInstance(
                    stateKind,
                    intensity,
                    duration,
                    source,
                    appliedRuleId,
                    stateDefinitionId));
            }

            m_revision++;
            return true;
        }

        public bool RemoveState(ETerrainElementStateKind stateKind)
        {
            for (int i = 0; i < m_activeStates.Count; i++)
            {
                if (m_activeStates[i].StateKind != stateKind)
                {
                    continue;
                }

                m_activeStates.RemoveAt(i);
                m_revision++;
                return true;
            }

            return false;
        }

        public bool SetEffectiveSurface(ETerrainSurfaceKind surfaceKind)
        {
            if (surfaceKind == ETerrainSurfaceKind.None)
            {
                return ClearEffectiveSurface();
            }

            if (m_hasEffectiveSurfaceOverride && m_effectiveSurfaceOverride == surfaceKind)
            {
                return false;
            }

            m_hasEffectiveSurfaceOverride = true;
            m_effectiveSurfaceOverride = surfaceKind;
            m_revision++;
            return true;
        }

        public bool ClearEffectiveSurface()
        {
            if (!m_hasEffectiveSurfaceOverride)
            {
                return false;
            }

            m_hasEffectiveSurfaceOverride = false;
            m_effectiveSurfaceOverride = ETerrainSurfaceKind.None;
            m_revision++;
            return true;
        }

        public bool SetSurfaceCover(
            ETerrainSurfaceCoverKind coverKind,
            ETerrainSurfaceCoverLifecycle lifecycle = ETerrainSurfaceCoverLifecycle.Alive)
        {
            if (coverKind == ETerrainSurfaceCoverKind.None)
            {
                return RemoveSurfaceCover();
            }

            ETerrainSurfaceCoverLifecycle normalizedLifecycle =
                lifecycle == ETerrainSurfaceCoverLifecycle.None ||
                lifecycle == ETerrainSurfaceCoverLifecycle.Removed
                    ? ETerrainSurfaceCoverLifecycle.Alive
                    : lifecycle;
            if (m_hasSurfaceCoverOverride &&
                m_surfaceCoverOverride == coverKind &&
                m_surfaceCoverLifecycle == normalizedLifecycle)
            {
                return false;
            }

            m_hasSurfaceCoverOverride = true;
            m_surfaceCoverOverride = coverKind;
            m_surfaceCoverLifecycle = normalizedLifecycle;
            m_revision++;
            return true;
        }

        public bool RemoveSurfaceCover()
        {
            if (m_hasSurfaceCoverOverride &&
                m_surfaceCoverOverride == ETerrainSurfaceCoverKind.None &&
                m_surfaceCoverLifecycle == ETerrainSurfaceCoverLifecycle.Removed)
            {
                return false;
            }

            m_hasSurfaceCoverOverride = true;
            m_surfaceCoverOverride = ETerrainSurfaceCoverKind.None;
            m_surfaceCoverLifecycle = ETerrainSurfaceCoverLifecycle.Removed;
            m_revision++;
            return true;
        }

        public bool ClearSurfaceCoverOverride()
        {
            if (!m_hasSurfaceCoverOverride)
            {
                return false;
            }

            m_hasSurfaceCoverOverride = false;
            m_surfaceCoverOverride = ETerrainSurfaceCoverKind.None;
            m_surfaceCoverLifecycle = ETerrainSurfaceCoverLifecycle.None;
            m_revision++;
            return true;
        }

        public bool ClearStates()
        {
            if (m_activeStates.Count == 0)
            {
                return false;
            }

            m_activeStates.Clear();
            m_revision++;
            return true;
        }

        public bool ReplaceCompatibilityFlags(ETerrainRuntimeSurfaceState flags)
        {
            ETerrainRuntimeSurfaceState currentFlags = RuntimeStateFlags;
            if (currentFlags == flags)
            {
                return false;
            }

            m_activeStates.Clear();
            TerrainElementStateSource source = new(null, 0);
            AddCompatibilityState(flags, ETerrainRuntimeSurfaceState.Wet, ETerrainElementStateKind.Wet, source);
            AddCompatibilityState(
                flags,
                ETerrainRuntimeSurfaceState.Burning,
                ETerrainElementStateKind.Burning,
                source);
            AddCompatibilityState(
                flags,
                ETerrainRuntimeSurfaceState.Oiled,
                ETerrainElementStateKind.Oiled,
                source);
            AddCompatibilityState(
                flags,
                ETerrainRuntimeSurfaceState.Electrified,
                ETerrainElementStateKind.Electrified,
                source);
            m_revision++;
            return true;
        }

        public TerrainCellRuntimeStateSnapshot CreateSnapshot(ETerrainSurfaceKind baseSurface)
        {
            return CreateSnapshot(baseSurface, ETerrainSurfaceCoverKind.None);
        }

        public TerrainCellRuntimeStateSnapshot CreateSnapshot(
            ETerrainSurfaceKind baseSurface,
            ETerrainSurfaceCoverKind baseSurfaceCover)
        {
            TerrainElementStateSnapshot[] stateSnapshots =
                new TerrainElementStateSnapshot[m_activeStates.Count];
            for (int i = 0; i < m_activeStates.Count; i++)
            {
                stateSnapshots[i] = new TerrainElementStateSnapshot(m_activeStates[i]);
            }

            return new TerrainCellRuntimeStateSnapshot(
                m_hasEffectiveSurfaceOverride,
                GetEffectiveSurface(baseSurface),
                m_hasSurfaceCoverOverride,
                GetEffectiveSurfaceCover(baseSurfaceCover),
                GetSurfaceCoverLifecycle(baseSurfaceCover),
                RuntimeStateFlags,
                m_persistencePolicy,
                m_revision,
                stateSnapshots);
        }

        public void AdvanceDurations(
            float deltaTime,
            List<ETerrainElementStateKind> expiredStates)
        {
            if (expiredStates == null)
            {
                throw new ArgumentNullException(nameof(expiredStates));
            }

            expiredStates.Clear();
            if (deltaTime <= 0.0f)
            {
                return;
            }

            bool changed = false;
            for (int i = 0; i < m_activeStates.Count; i++)
            {
                TerrainElementStateInstance state = m_activeStates[i];
                float previousDuration = state.RemainingDuration;
                if (!state.Advance(deltaTime))
                {
                    continue;
                }

                changed = true;
                if (previousDuration > 0.0f && state.RemainingDuration <= 0.0f)
                {
                    expiredStates.Add(state.StateKind);
                }
            }

            if (changed)
            {
                m_revision++;
            }
        }

        private void AddCompatibilityState(
            ETerrainRuntimeSurfaceState flags,
            ETerrainRuntimeSurfaceState expectedFlag,
            ETerrainElementStateKind stateKind,
            in TerrainElementStateSource source)
        {
            if ((flags & expectedFlag) == 0)
            {
                return;
            }

            m_activeStates.Add(new TerrainElementStateInstance(
                stateKind,
                1.0f,
                0.0f,
                source,
                "legacy-runtime-flags"));
        }
    }
}
