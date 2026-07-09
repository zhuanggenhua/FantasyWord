using Unity.Mathematics;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public class UIHUDAbilityBar : MonoBehaviour
    {
        protected UIHUDAbilityBarEntry[] m_abilities = null;
        private CharacterBase m_currentCharacter = null;

        private void Start()
        {
            GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            m_abilities = GetComponentsInChildren<UIHUDAbilityBarEntry>();

            for (int i = 0; i < m_abilities.Length; ++i)
            {
                m_abilities[i].SetAbility(default(CharacterEquippedAbilitySlotView), i);
            }

            OnCurrentControlledCharacterChanged(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance());
        }

        private void OnDestroy()
        {
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }

            BindCharacter(null);
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character) => BindCharacter(character);

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
            foreach (UIHUDAbilityBarEntry abilityEntry in m_abilities)
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

        private void OnEquippedAbilitiesChanged(CharacterEquippedAbilitySlotView[] abilities)
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
