using System.Collections.Generic;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    public class UIHUDEffectBar : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Transform m_effectIconRoot = null;
        [SerializeField] private GameObject m_effectIconPrefab = null;
        [Tooltip("留空时跟随当前控制角色；只有明确指定时，才固定显示某个角色的状态效果。")]
        [SerializeField] private CharacterBase m_character = null;

        [Header("Settings")]
        [SerializeField] private int m_effectIconPoolSize = 10;

        private readonly Dictionary<int, UIEffectIcon> m_effectIcons = new();
        private bool m_followCurrentControlledCharacter = false;
        private CharacterBase m_configuredCharacter = null;
        private bool m_currentControlledCharacterListening = false;

        private void Awake()
        {
            ConfigureEffectIconPool();
            m_followCurrentControlledCharacter = m_character == null;
            if (!m_followCurrentControlledCharacter)
            {
                m_configuredCharacter = m_character;
                m_character = null;
            }
        }

        private void OnEnable()
        {
            BindInitialCharacterIfReady();
        }

        private void Start()
        {
            BindInitialCharacterIfReady();
        }

        private void OnDisable()
        {
            StopCurrentControlledCharacterListening();
            UnbindCharacter();
        }

        private void OnDestroy()
        {
            StopCurrentControlledCharacterListening();
            UnbindCharacter();
            ReturnAllEffectIcons();
        }

        private void BindInitialCharacterIfReady()
        {
            if (m_followCurrentControlledCharacter)
            {
                StartCurrentControlledCharacterListeningIfReady();
            }
            else
            {
                BindCharacter(m_configuredCharacter);
            }
        }

        private void StartCurrentControlledCharacterListeningIfReady()
        {
            if (m_currentControlledCharacterListening)
            {
                return;
            }

            if (!GameManager.Exists() || !GameManager.HasSystem<PlayerSystem>())
            {
                return;
            }

            m_currentControlledCharacterListening = true;
            GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            OnCurrentControlledCharacterChanged(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance());
        }

        private void StopCurrentControlledCharacterListening()
        {
            if (!m_currentControlledCharacterListening)
            {
                return;
            }

            m_currentControlledCharacterListening = false;
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            BindCharacter(character);
        }

        private void OnTemporalEffectAdded(CharacterTemporalEffectPresentationSnapshot effect)
        {
            if (!effect.HasPresentation || m_effectIconPrefab == null || m_effectIcons.ContainsKey(effect.RuntimeKey))
            {
                return;
            }

            GameObject instance = GameObjectPoolService.Rent(m_effectIconPrefab, GetEffectIconRoot());
            if (instance == null)
            {
                Debug.LogWarning("没有可用的 HUD 状态图标实例，请检查效果栏对象池容量。", this);
                return;
            }

            if (!instance.TryGetComponent(out UIEffectIcon effectIcon))
            {
                Debug.LogError("HUD 状态图标预制体缺少 UIEffectIcon 组件。", instance);
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

        private Transform GetEffectIconRoot() => m_effectIconRoot ? m_effectIconRoot : transform;

        private void BindCharacter(CharacterBase character)
        {
            if (ReferenceEquals(m_character, character))
            {
                return;
            }

            UnbindCharacter();
            m_character = character;

            if (m_character == null)
            {
                return;
            }

            m_character.AddTemporalEffectPresentationAddedListener(OnTemporalEffectAdded);
            m_character.AddTemporalEffectPresentationRemovedListener(OnTemporalEffectRemoved);

            foreach (CharacterTemporalEffectPresentationSnapshot effect in m_character.GetTemporalEffectPresentationSnapshots())
            {
                OnTemporalEffectAdded(effect);
            }
        }

        private void UnbindCharacter()
        {
            if (m_character != null)
            {
                m_character.RemoveTemporalEffectPresentationAddedListener(OnTemporalEffectAdded);
                m_character.RemoveTemporalEffectPresentationRemovedListener(OnTemporalEffectRemoved);
            }

            m_character = null;
            ReturnAllEffectIcons();
        }

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
