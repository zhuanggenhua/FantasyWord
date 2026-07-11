using UnityEngine;

namespace FantasyWord.GameCore
{
    [CreateAssetMenu(
        fileName = "地表元素状态-",
        menuName = "FantasyWord/元素/地表元素状态定义")]
    public sealed class TerrainElementStateDefinition : DatabaseEntry
    {
        [Header("状态")]
        [SerializeField] private ETerrainElementStateKind m_stateKind = ETerrainElementStateKind.None;

        [Min(0.01f)]
        [SerializeField] private float m_defaultDuration = 1.0f;

        [SerializeField] private ETerrainStateMergePolicy m_mergePolicy =
            ETerrainStateMergePolicy.RefreshDuration;

        [Header("导航")]
        [Min(0.01f)]
        [SerializeField] private float m_traversalCostMultiplier = 1.0f;

        public ETerrainElementStateKind StateKind => m_stateKind;
        public float DefaultDuration => m_defaultDuration;
        public ETerrainStateMergePolicy MergePolicy => m_mergePolicy;
        public float TraversalCostMultiplier => m_traversalCostMultiplier;

        public bool TryValidate(out string error)
        {
            if (m_stateKind == ETerrainElementStateKind.None)
            {
                error = "状态类型不能为 None。";
                return false;
            }

            if (m_defaultDuration <= 0.0f)
            {
                error = $"状态 {m_stateKind} 的默认持续时间必须大于 0。";
                return false;
            }

            if (m_traversalCostMultiplier <= 0.0f)
            {
                error = $"状态 {m_stateKind} 的通行代价倍率必须大于 0。";
                return false;
            }

            error = string.Empty;
            return true;
        }
    }
}
