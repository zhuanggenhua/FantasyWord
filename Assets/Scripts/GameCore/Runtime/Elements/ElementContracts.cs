using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum EWorldElementKind
    {
        None,
        Fire,
        Water,
        Electricity,
        Oil
    }

    public enum EElementAreaKind
    {
        Point,
        Circle,
        Cone
    }

    public enum ETerrainElementStateKind
    {
        None,
        Wet,
        Burning,
        Oiled,
        Electrified
    }

    public enum ETerrainStateMergePolicy
    {
        RefreshDuration,
        KeepStronger,
        StackIntensity,
        Reject
    }

    public enum ETerrainRuntimePersistencePolicy
    {
        Transient,
        Persistent
    }

    public enum EElementReactionTrigger
    {
        OnElementApplied,
        OnStateExpired
    }

    public enum EElementReactionOperationKind
    {
        AddOrRefreshState,
        RemoveState,
        SetEffectiveSurface,
        ClearEffectiveSurface,
        EmitPresentationSignal
    }

    public enum EElementPresentationSignal
    {
        None,
        Steam
    }

    [Serializable]
    public readonly struct ElementArea
    {
        public ElementArea(EElementAreaKind kind, float radius, float coneHalfAngleDegrees)
        {
            Kind = kind;
            Radius = radius;
            ConeHalfAngleDegrees = coneHalfAngleDegrees;
        }

        public EElementAreaKind Kind { get; }
        public float Radius { get; }
        public float ConeHalfAngleDegrees { get; }

        public bool IsValid =>
            Kind == EElementAreaKind.Point ||
            Radius > 0.0f &&
            (Kind != EElementAreaKind.Cone ||
             ConeHalfAngleDegrees > 0.0f && ConeHalfAngleDegrees <= 180.0f);

        public static ElementArea Point() => new(EElementAreaKind.Point, 0.0f, 0.0f);

        public static ElementArea Circle(float radius) =>
            new(EElementAreaKind.Circle, radius, 0.0f);

        public static ElementArea Cone(float range, float halfAngleDegrees) =>
            new(EElementAreaKind.Cone, range, halfAngleDegrees);
    }

    /// <summary>
    /// 一次世界元素施加的不可变输入。它只描述来源与空间范围，不包含任何地表反应结果。
    /// </summary>
    public readonly struct ElementApplication
    {
        public ElementApplication(
            EWorldElementKind elementKind,
            float intensity,
            float exposureDuration,
            ElementArea area,
            Vector2 origin,
            Vector2 direction,
            UnityEngine.Object sourceEntity = null,
            int sourceAbilityCode = 0)
        {
            ElementKind = elementKind;
            Intensity = Mathf.Clamp01(intensity);
            ExposureDuration = Mathf.Max(0.0f, exposureDuration);
            Area = area;
            Origin = origin;
            Direction = direction.sqrMagnitude > 0.000001f
                ? direction.normalized
                : Vector2.zero;
            SourceEntity = sourceEntity;
            SourceAbilityCode = sourceAbilityCode;
        }

        public EWorldElementKind ElementKind { get; }
        public float Intensity { get; }
        public float ExposureDuration { get; }
        public ElementArea Area { get; }
        public Vector2 Origin { get; }
        public Vector2 Direction { get; }
        public UnityEngine.Object SourceEntity { get; }
        public int SourceAbilityCode { get; }

        public bool IsValid =>
            ElementKind != EWorldElementKind.None &&
            Intensity > 0.0f &&
            Area.IsValid &&
            (Area.Kind != EElementAreaKind.Cone || Direction.sqrMagnitude > 0.0f);
    }

    public readonly struct TerrainElementStateSource
    {
        public TerrainElementStateSource(UnityEngine.Object sourceEntity, int sourceAbilityCode)
        {
            SourceEntity = sourceEntity;
            SourceAbilityCode = sourceAbilityCode;
        }

        public UnityEngine.Object SourceEntity { get; }
        public int SourceAbilityCode { get; }
    }

    public static class TerrainElementStateKindExtensions
    {
        public static ETerrainRuntimeSurfaceState ToRuntimeFlag(this ETerrainElementStateKind stateKind)
        {
            return stateKind switch
            {
                ETerrainElementStateKind.Wet => ETerrainRuntimeSurfaceState.Wet,
                ETerrainElementStateKind.Burning => ETerrainRuntimeSurfaceState.Burning,
                ETerrainElementStateKind.Oiled => ETerrainRuntimeSurfaceState.Oiled,
                ETerrainElementStateKind.Electrified => ETerrainRuntimeSurfaceState.Electrified,
                _ => ETerrainRuntimeSurfaceState.None
            };
        }
    }
}
