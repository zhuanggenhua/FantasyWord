using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 持续效果列表面板。
    /// 它从指定角色或当前控制角色读取效果表现快照，租用条目对象显示图标，并在悬停时驱动详情面板。
    /// </summary>
    public class UIEffectList : MonoBehaviour
    {
        [Header("效果列表配置")]
        [SerializeField]
        [LabelText("增益条目预制体")]
        [Tooltip("用于显示 Buff 类持续效果的列表条目预制体，必须包含 UIEffectListEntry。")]
        private GameObject m_buffEffectEntryPrefab = null;

        [SerializeField]
        [LabelText("减益条目预制体")]
        [Tooltip("用于显示 Debuff 类持续效果的列表条目预制体，必须包含 UIEffectListEntry。")]
        private GameObject m_debuffEffectEntryPrefab = null;

        [SerializeField]
        [LabelText("列表内容根节点")]
        [Tooltip("租用出来的效果条目会挂到这个节点下。")]
        private GameObject m_listContentRoot = null;

        [SerializeField]
        [LabelText("详情面板")]
        [Tooltip("悬停或选中效果条目时显示说明文本的详情面板。")]
        private UIEffectDescription m_effectDescription = null;

        [SerializeField, Min(0)]
        [LabelText("条目池容量")]
        [Tooltip("Buff / Debuff 条目预制体各自预热并限制的对象池容量。")]
        private int m_effectEntryPoolSize = 12;

        [SerializeField]
        [LabelText("目标角色")]
        [Tooltip("留空时显示当前控制角色的效果列表；只有明确指定时，才固定显示某个角色。")]
        private CharacterBase m_target = null;

        private readonly List<GameObject> m_activeEffectEntries = new();

        /// <summary>初始化 Buff / Debuff 条目对象池，避免首次打开列表时集中创建实例。</summary>
        private void Awake()
        {
            ConfigureEffectEntryPools();
        }

        /// <summary>销毁时归还已租用条目，避免对象池中残留旧列表实例。</summary>
        private void OnDestroy()
        {
            ReturnEffectEntries();
        }

        /// <summary>刷新并显示目标角色的持续效果列表；目标缺失时保持空列表。</summary>
        public void Show()
        {
            HideDescriptionPanel();
            ReturnEffectEntries();

            CharacterBase target = m_target != null ? m_target : GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
            if (target == null)
            {
                return;
            }

            foreach (CharacterTemporalEffectPresentationSnapshot temporalEffect in target.GetTemporalEffectPresentationSnapshots())
            {
                RentEffectEntry(temporalEffect);
            }
        }

        /// <summary>隐藏列表时同步隐藏详情面板，并归还所有已租用条目。</summary>
        public void Hide()
        {
            HideDescriptionPanel();
            ReturnEffectEntries();
        }

        /// <summary>显示指定效果的详情面板，Y 坐标来自当前悬停条目。</summary>
        private void ShowDescriptionPanel(CharacterTemporalEffectPresentationSnapshot effect, float positionY) => m_effectDescription?.Show(effect, positionY);

        /// <summary>隐藏效果详情面板；条目本身仍保留在列表中。</summary>
        private void HideDescriptionPanel() => m_effectDescription?.Hide();

        /// <summary>处理条目悬停事件，把效果详情交给详情面板显示。</summary>
        public void HandleEffectHovered(EffectHoveredEvent eventData) => ShowDescriptionPanel(eventData.effect, eventData.listElementY);

        /// <summary>处理条目取消悬停或失焦事件，关闭详情面板。</summary>
        public void HandleEffectNotHovered() => HideDescriptionPanel();

        /// <summary>为一个有效的持续效果快照租用条目实例，并刷新条目显示。</summary>
        private void RentEffectEntry(CharacterTemporalEffectPresentationSnapshot temporalEffect)
        {
            if (!temporalEffect.HasPresentation)
            {
                return;
            }

            GameObject prefab = temporalEffect.EffectType == EEffectType.Buff ?
                m_buffEffectEntryPrefab :
                m_debuffEffectEntryPrefab;
            GameObject instance = GameObjectPoolService.Rent(prefab, m_listContentRoot.transform);
            if (instance == null)
            {
                Debug.LogWarning("没有可用的效果列表条目实例，请检查效果列表对象池容量。", this);
                return;
            }

            if (!instance.TryGetComponent(out UIEffectListEntry effectEntry))
            {
                Debug.LogError("效果列表条目预制体缺少 UIEffectListEntry 组件。", instance);
                GameObjectPoolService.Return(instance);
                return;
            }

            effectEntry.SetEffect(temporalEffect);
            m_activeEffectEntries.Add(instance);
        }

        /// <summary>按当前容量配置 Buff 和 Debuff 两类条目对象池。</summary>
        private void ConfigureEffectEntryPools()
        {
            ConfigureEffectEntryPool(m_buffEffectEntryPrefab);
            ConfigureEffectEntryPool(m_debuffEffectEntryPrefab);
        }

        /// <summary>配置单个条目预制体的容量和预热；预制体缺失时跳过，让打开列表时暴露配置问题。</summary>
        private void ConfigureEffectEntryPool(GameObject prefab)
        {
            if (prefab == null)
            {
                return;
            }

            GameObjectPoolService.SetMaxCapacity(prefab, m_effectEntryPoolSize);
            GameObjectPoolService.Prewarm(prefab, m_effectEntryPoolSize);
        }

        /// <summary>归还所有当前激活条目，并清空本列表的租用记录。</summary>
        private void ReturnEffectEntries()
        {
            foreach (GameObject entry in m_activeEffectEntries)
            {
                if (entry)
                {
                    GameObjectPoolService.Return(entry);
                }
            }

            m_activeEffectEntries.Clear();
        }
    }
}
