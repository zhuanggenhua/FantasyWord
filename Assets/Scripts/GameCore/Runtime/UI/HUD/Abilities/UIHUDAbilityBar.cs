using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// HUD 技能栏，跟随玩家当前控制角色展示快捷技能槽。
    /// 它只把角色已解析的装备技能槽写入条目，不处理输入、不判断技能释放条件。
    /// </summary>
    public class UIHUDAbilityBar : MonoBehaviour
    {
        protected UIHUDAbilityBarEntry[] m_abilities = null;
        private CharacterBase m_currentCharacter = null;
        private bool m_isInitialized = false;
        private bool m_currentControlledCharacterListening = false;

        #region 生命周期

        /// <summary>初始化子条目，保证启用前每个槽位都有默认空状态。</summary>
        private void Awake()
        {
            InitializeEntriesIfNeeded();
        }

        /// <summary>启用时初始化条目并尝试监听当前控制角色。</summary>
        private void OnEnable()
        {
            InitializeEntriesIfNeeded();
            StartCurrentControlledCharacterListeningIfReady();
        }

        /// <summary>补一次监听注册，覆盖 HUD 早于 PlayerSystem 初始化的场景。</summary>
        private void Start()
        {
            StartCurrentControlledCharacterListeningIfReady();
        }

        /// <summary>禁用时注销当前控制角色监听，并清空技能栏绑定。</summary>
        private void OnDisable()
        {
            StopCurrentControlledCharacterListening();
            BindCharacter(null);
        }

        /// <summary>销毁时重复清理，避免对象绕过禁用流程时残留角色事件监听。</summary>
        private void OnDestroy()
        {
            StopCurrentControlledCharacterListening();
            BindCharacter(null);
        }

        #endregion

        #region 条目与角色绑定

        /// <summary>缓存所有子技能条目，并先写入空技能槽，避免旧显示残留。</summary>
        private void InitializeEntriesIfNeeded()
        {
            if (m_isInitialized)
            {
                return;
            }

            m_abilities = GetComponentsInChildren<UIHUDAbilityBarEntry>();

            for (int i = 0; i < m_abilities.Length; ++i)
            {
                m_abilities[i].SetAbility(default(CharacterEquippedAbilitySlotView), i);
            }

            m_isInitialized = true;
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

        /// <summary>当前控制角色变化后重新绑定技能槽事件。</summary>
        private void OnCurrentControlledCharacterChanged(CharacterBase character) => BindCharacter(character);

        /// <summary>切换技能栏绑定角色，并维护装备技能变化监听。</summary>
        private void BindCharacter(CharacterBase character)
        {
            if (ReferenceEquals(m_currentCharacter, character))
            {
                return;
            }

            if (m_currentCharacter != null)
            {
                m_currentCharacter.RemoveEquippedAbilitiesChangedListener(OnEquippedAbilitiesChanged);
            }

            m_currentCharacter = character;
            foreach (UIHUDAbilityBarEntry abilityEntry in m_abilities ?? System.Array.Empty<UIHUDAbilityBarEntry>())
            {
                abilityEntry.SetBoundCharacter(m_currentCharacter);
            }

            if (m_currentCharacter != null)
            {
                m_currentCharacter.AddEquippedAbilitiesChangedListener(OnEquippedAbilitiesChanged);
                OnEquippedAbilitiesChanged(m_currentCharacter.GetEquippedAbilitySlotViewSnapshots());
            }
            else
            {
                OnEquippedAbilitiesChanged(System.Array.Empty<CharacterEquippedAbilitySlotView>());
            }
        }

        /// <summary>按角色可装备技能上限刷新 HUD 条目，缺失槽位写入空视图。</summary>
        private void OnEquippedAbilitiesChanged(CharacterEquippedAbilitySlotView[] abilities)
        {
            if (m_abilities == null)
            {
                return;
            }

            int maxEquippableAbilities = GameManager.Exists()
                ? GameManager.Config.maxEquippableAbilities
                : m_abilities.Length;
            for (int i = 0; i < math.min(m_abilities.Length, maxEquippableAbilities); ++i)
            {
                if (abilities.Length > i)
                {
                    m_abilities[i].SetAbility(abilities[i], i);
                }
                else
                {
                    m_abilities[i].SetAbility(default(CharacterEquippedAbilitySlotView), i);
                }
            }
        }

        #endregion
    }
}
