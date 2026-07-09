using System;
using UnityEngine;
using YokiFrame;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class IsAbilityUnlocked : ABaseCondition
    {
        [SerializeField] private int m_formalGasAbilityCode = 0;

        public override bool Evaluate()
        {
            CharacterBase currentCharacter = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
            if (currentCharacter == null)
            {
                return false;
            }

            if (m_formalGasAbilityCode <= 0)
            {
                return false;
            }

            return currentCharacter.HasFormalGasAbility(m_formalGasAbilityCode);
        }

        protected override void OnStartListening()
        {
            EventKit.Type.Register<CharacterAbilityAddedEvent>(OnAbilityAdded);
            EventKit.Type.Register<CharacterAbilityRemovedEvent>(OnAbilityRemoved);
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.AddCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        protected override void OnStopListening()
        {
            EventKit.Type.UnRegister<CharacterAbilityAddedEvent>(OnAbilityAdded);
            EventKit.Type.UnRegister<CharacterAbilityRemovedEvent>(OnAbilityRemoved);
            if (GameManager.Exists() && GameManager.HasSystem<PlayerSystem>())
            {
                GameManager.PlayerSystem.RemoveCurrentControlledCharacterChangedListener(OnCurrentControlledCharacterChanged);
            }
        }

        private void OnAbilityAdded(CharacterAbilityAddedEvent abilityAddedEvent)
        {
            if (ShouldRefreshFor(
                    abilityAddedEvent.Character,
                    abilityAddedEvent.FormalGasAbilityCode))
            {
                NotifyStateChange();
            }
        }

        private void OnAbilityRemoved(CharacterAbilityRemovedEvent abilityRemovedEvent)
        {
            if (ShouldRefreshFor(
                    abilityRemovedEvent.Character,
                    abilityRemovedEvent.FormalGasAbilityCode))
            {
                NotifyStateChange();
            }
        }

        private void OnCurrentControlledCharacterChanged(CharacterBase character) => NotifyStateChange();

        private bool ShouldRefreshFor(CharacterBase character, int formalGasAbilityCode)
        {
            if (m_formalGasAbilityCode <= 0)
            {
                return false;
            }

            return character != null &&
                formalGasAbilityCode == m_formalGasAbilityCode &&
                GameManager.Exists() &&
                GameManager.HasSystem<PlayerSystem>() &&
                character == GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
        }

    }
}
