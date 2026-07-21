using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// HUD 状态效果条。
    /// 它跟随指定角色或玩家当前控制角色，把有表现配置的持续效果显示为图标。
    /// </summary>
    public class UIHUDEffectBar : MonoBehaviour
    {
        #region Inspector 配置

        [Header("状态图标配置")]
        [SerializeField]
        [LabelText("图标根节点")]
        [Tooltip("状态图标实例挂载的父节点；留空时挂到本物体下。")]
        private Transform m_effectIconRoot = null;

        [SerializeField]
        [LabelText("图标预制体")]
        [Tooltip("HUD 状态图标预制体，必须包含 UIEffectIcon 组件。")]
        private GameObject m_effectIconPrefab = null;

        [SerializeField]
        [LabelText("目标角色")]
        [Tooltip("留空时跟随当前控制角色；只有明确指定时，才固定显示某个角色的状态效果。")]
        private CharacterBase m_character = null;

        [SerializeField, Min(0)]
        [LabelText("图标池容量")]
        [Tooltip("状态图标预制体的对象池预热数量和最大容量。")]
        private int m_effectIconPoolSize = 10;

        #endregion

        private readonly Dictionary<int, UIEffectIcon> m_effectIcons = new();
        private bool m_followCurrentControlledCharacter = false;
        private CharacterBase m_configuredCharacter = null;
        private bool m_currentControlledCharacterListening = false;

        #region 生命周期

        /// <summary>配置图标对象池，并记录初始目标角色绑定模式。</summary>
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

        /// <summary>启用时尝试绑定目标角色。</summary>
        private void OnEnable()
        {
            BindInitialCharacterIfReady();
        }

        /// <summary>补一次初始绑定，覆盖 HUD 早于 PlayerSystem 初始化的场景。</summary>
        private void Start()
        {
            BindInitialCharacterIfReady();
        }

        /// <summary>禁用时停止监听当前控制角色，并解绑状态效果事件。</summary>
        private void OnDisable()
        {
            StopCurrentControlledCharacterListening();
            UnbindCharacter();
        }

        /// <summary>销毁时归还所有图标实例，避免对象池残留旧 HUD 图标。</summary>
        private void OnDestroy()
        {
            StopCurrentControlledCharacterListening();
            UnbindCharacter();
            ReturnAllEffectIcons();
        }

        #endregion

        #region 角色绑定

        /// <summary>根据 Inspector 配置决定跟随当前控制角色，还是绑定固定角色。</summary>
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

        /// <summary>PlayerSystem 可用后监听当前控制角色变化，并立即同步一次当前角色。</summary>
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

        /// <summary>停止监听当前控制角色变化；GameManager 已释放时跳过注销入口。</summary>
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

        /// <summary>当前控制角色变化后重新绑定状态效果事件。</summary>
        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            BindCharacter(character);
        }

        /// <summary>切换绑定角色，并为现有持续效果补建图标。</summary>
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

        /// <summary>解绑当前角色状态效果事件，并归还本 HUD 已租用的图标。</summary>
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

        #endregion

        #region 图标对象池

        /// <summary>持续效果新增时租用图标；没有表现配置或 runtimeKey 已存在时跳过。</summary>
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

        /// <summary>持续效果移除时按 runtimeKey 归还对应图标。</summary>
        private void OnTemporalEffectRemoved(CharacterTemporalEffectPresentationSnapshot effect)
        {
            if (m_effectIcons.TryGetValue(effect.RuntimeKey, out UIEffectIcon effectIcon))
            {
                GameObjectPoolService.Return(effectIcon.gameObject);
                m_effectIcons.Remove(effect.RuntimeKey);
            }
        }

        /// <summary>解析图标挂载根节点；未配置时使用本物体 Transform。</summary>
        private Transform GetEffectIconRoot() => m_effectIconRoot ? m_effectIconRoot : transform;

        /// <summary>按当前容量配置并预热 HUD 状态图标对象池。</summary>
        private void ConfigureEffectIconPool()
        {
            if (m_effectIconPrefab == null)
            {
                return;
            }

            GameObjectPoolService.SetMaxCapacity(m_effectIconPrefab, m_effectIconPoolSize);
            GameObjectPoolService.Prewarm(m_effectIconPrefab, m_effectIconPoolSize);
        }

        /// <summary>归还所有已租用图标，并清空 runtimeKey 到图标的映射。</summary>
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

        #endregion
    }
}
