using UnityEngine;

using System.Collections.Generic;
using YokiFrame;

namespace FantasyWord.GameCore
{
    public class UIEffectList : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private GameObject m_buffEffectEntryPrefab = null;
        [SerializeField] private GameObject m_debuffEffectEntryPrefab = null;
        [SerializeField] private GameObject m_listContentRoot = null;
        [SerializeField] private UIEffectDescription m_effectDescription = null;
        [SerializeField] private int m_effectEntryPoolSize = 12;
        [Tooltip("留空时显示当前控制角色的效果列表；只有明确指定时，才固定显示某个角色。")]
        [SerializeField] private CharacterBase m_target = null;

        private readonly List<GameObject> m_activeEffectEntries = new();

        private void Awake()
        {
            ConfigureEffectEntryPools();
        }

        private void OnDestroy()
        {
            ReturnEffectEntries();
        }

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

        public void Hide()
        {
            HideDescriptionPanel();
            ReturnEffectEntries();
        }

        private void ShowDescriptionPanel(CharacterTemporalEffectPresentationSnapshot effect, float positionY) => m_effectDescription?.Show(effect, positionY);
        private void HideDescriptionPanel() => m_effectDescription?.Hide();

        public void HandleEffectHovered(EffectHoveredEvent eventData) => ShowDescriptionPanel(eventData.effect, eventData.listElementY);
        public void HandleEffectNotHovered() => HideDescriptionPanel();

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

        private void ConfigureEffectEntryPools()
        {
            ConfigureEffectEntryPool(m_buffEffectEntryPrefab);
            ConfigureEffectEntryPool(m_debuffEffectEntryPrefab);
        }

        private void ConfigureEffectEntryPool(GameObject prefab)
        {
            if (prefab == null)
            {
                return;
            }

            GameObjectPoolService.SetMaxCapacity(prefab, m_effectEntryPoolSize);
            GameObjectPoolService.Prewarm(prefab, m_effectEntryPoolSize);
        }

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

