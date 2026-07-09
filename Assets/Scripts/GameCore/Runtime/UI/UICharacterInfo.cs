using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using YokiFrame;

namespace FantasyWord.GameCore
{
    public class UICharacterInfo : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private TextMeshProUGUI m_nameText = null;
        [SerializeField] private Slider m_healthSlider = null;
        [SerializeField] private Slider m_manaSlider = null;
        [SerializeField] private Transform m_effectIconRoot = null;
        [SerializeField] private GameObject m_effectIconPrefab = null;
        [SerializeField] private int m_effectIconPoolSize = 10;
        [SerializeField] private CharacterBase m_target = null;

        private string m_nameAndLevelFormat = string.Empty;

        private readonly Dictionary<int, UIEffectIcon> m_effectIcons = new();

        private void Awake()
        {
            ConfigureEffectIconPool();

            m_target.AddStatsChangedListener(OnStatsChanged);
            m_target.AddCurrentStatsChangedListener(OnStatsChanged);
            m_target.AddTemporalEffectPresentationAddedListener(OnTemporalEffectAdded);
            m_target.AddTemporalEffectPresentationRemovedListener(OnTemporalEffectRemoved);
            m_target.AddLevelUppedListener(OnLevelUpped);
        }

        private void OnDestroy()
        {
            m_target.RemoveStatsChangedListener(OnStatsChanged);
            m_target.RemoveCurrentStatsChangedListener(OnStatsChanged);
            m_target.RemoveTemporalEffectPresentationAddedListener(OnTemporalEffectAdded);
            m_target.RemoveTemporalEffectPresentationRemovedListener(OnTemporalEffectRemoved);
            m_target.RemoveLevelUppedListener(OnLevelUpped);

            ReturnAllEffectIcons();
        }

        private void Start()
        {
            m_nameAndLevelFormat = m_nameText.text;

            UpdateResourceBars();
            UpdateNameAndLevel();

            // Recover any existing effects
            foreach (CharacterTemporalEffectPresentationSnapshot effect in m_target.GetTemporalEffectPresentationSnapshots())
            {
                OnTemporalEffectAdded(effect);
            }
        }

        public void UpdateResourceBars()
        {
            if (m_healthSlider?.isActiveAndEnabled ?? false)
            {
                m_healthSlider.minValue = 0;
                m_healthSlider.maxValue = m_target.GetMaxHealth();
                m_healthSlider.value = m_target.GetCurrentHealth();
            }

            if (m_manaSlider?.isActiveAndEnabled ?? false)
            {
                m_manaSlider.minValue = 0;
                m_manaSlider.maxValue = m_target.GetMaxMana();
                m_manaSlider.value = m_target.GetCurrentMana();
            }
        }

        public void UpdateNameAndLevel()
        {
            if (m_nameText?.isActiveAndEnabled ?? false)
            {
                m_nameText.text = StringFormatter.Format(m_nameAndLevelFormat).Replace("{name}", m_target.characterSheet.displayName).Replace("{level}", m_target.level.ToString());
            }
        }

        private void OnStatsChanged(Stats previous) => UpdateResourceBars();

        private void OnTemporalEffectAdded(CharacterTemporalEffectPresentationSnapshot effect)
        {
            if (!effect.HasPresentation || m_effectIconPrefab == null || m_effectIcons.ContainsKey(effect.RuntimeKey))
            {
                return;
            }

            GameObject instance = GameObjectPoolService.Rent(m_effectIconPrefab, GetEffectIconRoot());
            if (instance == null)
            {
                Debug.LogWarning("没有可用的角色状态图标实例，请检查效果图标对象池容量。", this);
                return;
            }

            if (!instance.TryGetComponent(out UIEffectIcon effectIcon))
            {
                Debug.LogError("角色状态图标预制体缺少 UIEffectIcon 组件。", instance);
                GameObjectPoolService.Return(instance);
                return;
            }

            m_effectIcons[effect.RuntimeKey] = effectIcon;
            effectIcon.Show(effect.Info.Icon);
        }

        private void OnTemporalEffectRemoved(CharacterTemporalEffectPresentationSnapshot effect)
        {
            if (m_effectIcons.TryGetValue(effect.RuntimeKey, out UIEffectIcon effectIcon))
            {
                GameObjectPoolService.Return(effectIcon.gameObject);
                m_effectIcons.Remove(effect.RuntimeKey);
            }
        }

        private void OnLevelUpped(int level) => UpdateNameAndLevel();

        private Transform GetEffectIconRoot() => m_effectIconRoot ? m_effectIconRoot : transform;

        private void ConfigureEffectIconPool()
        {
            if (m_effectIconPrefab == null)
            {
                return;
            }

            GameObjectPoolService.SetMaxCapacity(m_effectIconPrefab, m_effectIconPoolSize);
            GameObjectPoolService.Prewarm(m_effectIconPrefab, m_effectIconPoolSize);
        }

        private void ReturnAllEffectIcons()
        {
            foreach (UIEffectIcon effectIcon in m_effectIcons.Values)
            {
                if (effectIcon)
                {
                    GameObjectPoolService.Return(effectIcon.gameObject);
                }
            }

            m_effectIcons.Clear();
        }
    }
}
