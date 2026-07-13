using System;
using System.Collections.Generic;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public sealed class ElementReactionOperation
    {
        [SerializeField] private EElementReactionOperationKind m_kind =
            EElementReactionOperationKind.AddOrRefreshState;
        [SerializeField] private ETerrainElementStateKind m_stateKind =
            ETerrainElementStateKind.None;
        [Min(0.0f)]
        [SerializeField] private float m_intensityMultiplier = 1.0f;
        [Tooltip("小于等于 0 时使用状态定义的默认持续时间。")]
        [SerializeField] private float m_durationOverride = 0.0f;
        [SerializeField] private ETerrainSurfaceKind m_surfaceKind =
            ETerrainSurfaceKind.None;
        [SerializeField] private ETerrainSurfaceCoverKind m_surfaceCoverKind =
            ETerrainSurfaceCoverKind.None;
        [SerializeField] private EElementPresentationSignal m_presentationSignal =
            EElementPresentationSignal.None;

        public EElementReactionOperationKind Kind => m_kind;
        public ETerrainElementStateKind StateKind => m_stateKind;
        public float IntensityMultiplier => Mathf.Max(0.0f, m_intensityMultiplier);
        public float DurationOverride => m_durationOverride;
        public ETerrainSurfaceKind SurfaceKind => m_surfaceKind;
        public ETerrainSurfaceCoverKind SurfaceCoverKind => m_surfaceCoverKind;
        public EElementPresentationSignal PresentationSignal => m_presentationSignal;
    }

    [CreateAssetMenu(
        fileName = "元素反应-",
        menuName = "FantasyWord/元素/元素反应定义")]
    public sealed class ElementReactionDefinition : DatabaseEntry
    {
        [Header("触发")]
        [SerializeField] private EElementReactionTrigger m_trigger =
            EElementReactionTrigger.OnElementApplied;
        [SerializeField] private EWorldElementKind m_elementKind = EWorldElementKind.None;
        [SerializeField] private ETerrainElementStateKind m_expiredStateKind =
            ETerrainElementStateKind.None;
        [Range(0.0f, 1.0f)]
        [SerializeField] private float m_minimumIntensity = 0.0f;

        [Header("地表条件")]
        [SerializeField] private bool m_requireBaseSurface = false;
        [SerializeField] private ETerrainSurfaceKind m_baseSurface = ETerrainSurfaceKind.None;
        [SerializeField] private bool m_requireEffectiveSurface = false;
        [SerializeField] private ETerrainSurfaceKind m_effectiveSurface = ETerrainSurfaceKind.None;

        [Header("上层地表条件")]
        [SerializeField] private bool m_requireSurfaceCover = false;
        [SerializeField] private ETerrainSurfaceCoverKind m_surfaceCover =
            ETerrainSurfaceCoverKind.None;
        [SerializeField] private ETerrainSurfaceCoverTraits m_requiredSurfaceCoverTraits =
            ETerrainSurfaceCoverTraits.None;
        [SerializeField] private ETerrainSurfaceCoverTraits m_forbiddenSurfaceCoverTraits =
            ETerrainSurfaceCoverTraits.None;

        [Header("状态条件")]
        [SerializeField] private ETerrainRuntimeSurfaceState m_requiredStates =
            ETerrainRuntimeSurfaceState.None;
        [SerializeField] private ETerrainRuntimeSurfaceState m_forbiddenStates =
            ETerrainRuntimeSurfaceState.None;

        [Header("结果")]
        [SerializeField] private int m_priority = 0;
        [SerializeField] private ElementReactionOperation[] m_operations =
            Array.Empty<ElementReactionOperation>();

        public EElementReactionTrigger Trigger => m_trigger;
        public EWorldElementKind ElementKind => m_elementKind;
        public ETerrainElementStateKind ExpiredStateKind => m_expiredStateKind;
        public float MinimumIntensity => m_minimumIntensity;
        public int Priority => m_priority;
        public IReadOnlyList<ElementReactionOperation> Operations => m_operations;

        public bool Matches(in ElementReactionContext context)
        {
            if (m_trigger != context.Trigger)
            {
                return false;
            }

            if (m_trigger == EElementReactionTrigger.OnElementApplied &&
                (m_elementKind != context.Application.ElementKind ||
                 context.Application.Intensity < m_minimumIntensity))
            {
                return false;
            }

            if (m_trigger == EElementReactionTrigger.OnStateExpired &&
                m_expiredStateKind != context.ExpiredStateKind)
            {
                return false;
            }

            if (m_requireBaseSurface && m_baseSurface != context.BaseSurface ||
                m_requireEffectiveSurface && m_effectiveSurface != context.EffectiveSurface)
            {
                return false;
            }

            if (m_requireSurfaceCover && m_surfaceCover != context.SurfaceCover ||
                (context.SurfaceCoverTraits & m_requiredSurfaceCoverTraits) !=
                m_requiredSurfaceCoverTraits ||
                (context.SurfaceCoverTraits & m_forbiddenSurfaceCoverTraits) != 0)
            {
                return false;
            }

            if ((context.RuntimeStates & m_requiredStates) != m_requiredStates ||
                (context.RuntimeStates & m_forbiddenStates) != 0)
            {
                return false;
            }

            return true;
        }

        public bool TryValidate(out string error)
        {
            if (m_trigger == EElementReactionTrigger.OnElementApplied &&
                m_elementKind == EWorldElementKind.None)
            {
                error = "元素施加规则必须配置元素类型。";
                return false;
            }

            if (m_trigger == EElementReactionTrigger.OnStateExpired &&
                m_expiredStateKind == ETerrainElementStateKind.None)
            {
                error = "状态到期规则必须配置到期状态类型。";
                return false;
            }

            if ((m_requiredStates & m_forbiddenStates) != 0)
            {
                error = "同一种运行时状态不能同时出现在 Required 和 Forbidden 条件中。";
                return false;
            }

            if ((m_requiredSurfaceCoverTraits & m_forbiddenSurfaceCoverTraits) != 0)
            {
                error = "同一种上层地表属性不能同时出现在 Required 和 Forbidden 条件中。";
                return false;
            }

            if (m_operations == null || m_operations.Length == 0)
            {
                error = "反应规则必须至少包含一个结果操作。";
                return false;
            }

            error = string.Empty;
            return true;
        }
    }

    public readonly struct ElementReactionContext
    {
        public ElementReactionContext(
            EElementReactionTrigger trigger,
            in ElementApplication application,
            ETerrainElementStateKind expiredStateKind,
            ETerrainSurfaceKind baseSurface,
            ETerrainSurfaceKind effectiveSurface,
            ETerrainSurfaceCoverKind surfaceCover,
            ETerrainSurfaceCoverTraits surfaceCoverTraits,
            ETerrainRuntimeSurfaceState runtimeStates)
        {
            Trigger = trigger;
            Application = application;
            ExpiredStateKind = expiredStateKind;
            BaseSurface = baseSurface;
            EffectiveSurface = effectiveSurface;
            SurfaceCover = surfaceCover;
            SurfaceCoverTraits = surfaceCoverTraits;
            RuntimeStates = runtimeStates;
        }

        public ElementReactionContext(
            EElementReactionTrigger trigger,
            in ElementApplication application,
            ETerrainElementStateKind expiredStateKind,
            ETerrainSurfaceKind baseSurface,
            ETerrainSurfaceKind effectiveSurface,
            ETerrainRuntimeSurfaceState runtimeStates)
            : this(
                trigger,
                application,
                expiredStateKind,
                baseSurface,
                effectiveSurface,
                ETerrainSurfaceCoverKind.None,
                ETerrainSurfaceCoverTraits.None,
                runtimeStates)
        {
        }

        public EElementReactionTrigger Trigger { get; }
        public ElementApplication Application { get; }
        public ETerrainElementStateKind ExpiredStateKind { get; }
        public ETerrainSurfaceKind BaseSurface { get; }
        public ETerrainSurfaceKind EffectiveSurface { get; }
        public ETerrainSurfaceCoverKind SurfaceCover { get; }
        public ETerrainSurfaceCoverTraits SurfaceCoverTraits { get; }
        public ETerrainRuntimeSurfaceState RuntimeStates { get; }
    }
}
