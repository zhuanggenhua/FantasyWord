using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public class UIAbilityBar : MonoBehaviour
    {
        protected UIAbilityBarEntry[] m_abilities = null;
        private CharacterBase m_currentCharacter = null;
        private bool m_isInitialized = false;
        private bool m_followCurrentControlledCharacter = true;

        public void Init()
        {
            if (m_isInitialized)
            {
                return;
            }

            m_abilities = GetComponentsInChildren<UIAbilityBarEntry>();

            for (int i = 0; i < m_abilities.Length; ++i)
            {
                m_abilities[i].SetAbility(default(CharacterEquippedAbilitySlotView), i);
            }

            GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            OnCurrentControlledCharacterChanged(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance());
            m_isInitialized = true;
        }

        private void OnDestroy()
        {
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }

            BindCharacter(null);
        }

        public void SelectFirstElement()
        {
            if (m_abilities.Length > 0)
            {
                m_abilities[0].ForceSelection();
            }
        }

        public void UpdateUI()
        {
            if (m_currentCharacter != null)
            {
                FillAbilityBar(m_currentCharacter.GetEquippedAbilitySlotViewSnapshots());
            }
            else
            {
                FillAbilityBar(System.Array.Empty<CharacterEquippedAbilitySlotView>());
            }
        }

        public void FollowCurrentControlledCharacter()
        {
            m_followCurrentControlledCharacter = true;
            BindCharacter(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance());
        }

        public void PresentCharacter(CharacterBase character)
        {
            m_followCurrentControlledCharacter = false;
            BindCharacter(character);
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character)
        {
            if (m_followCurrentControlledCharacter)
            {
                BindCharacter(character);
            }
        }

        private void BindCharacter(CharacterBase character)
        {
            if (ReferenceEquals(m_currentCharacter, character))
            {
                return;
            }

            if (m_currentCharacter != null)
            {
                m_currentCharacter.RemoveEquippedAbilitiesChangedListener(FillAbilityBar);
            }

            m_currentCharacter = character;

            if (m_currentCharacter != null)
            {
                m_currentCharacter.AddEquippedAbilitiesChangedListener(FillAbilityBar);
                FillAbilityBar(m_currentCharacter.GetEquippedAbilitySlotViewSnapshots());
            }
            else
            {
                FillAbilityBar(System.Array.Empty<CharacterEquippedAbilitySlotView>());
            }
        }

        private void FillAbilityBar(CharacterEquippedAbilitySlotView[] abilities)
        {
            for (int i = 0; i < math.min(m_abilities.Length, GameManager.Config.maxEquippableAbilities); ++i)
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
    }
}
