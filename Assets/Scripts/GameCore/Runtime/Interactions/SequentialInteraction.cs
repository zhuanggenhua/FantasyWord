using System;
using System.Threading.Tasks;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    public enum ESequenceInterruptionPolicy
    {
        OnSuccess,
        OnFailure,
        Never
    }

    [Serializable]
    public class SequentialInteraction : IInteraction
    {
        [SerializeReference, SubclassSelector]
        private IInteraction[] m_interactions;

        [SerializeField] private ESequenceInterruptionPolicy m_interruptionPolicy = ESequenceInterruptionPolicy.OnSuccess;

        public async Task<bool> TryExecute(CharacterBase source, IInteractionTarget target)
        {
            bool sequenceOutcome = true;

            foreach (IInteraction interaction in m_interactions)
            {
                bool interactionOutcome = await interaction.TryExecute(source, target);

                sequenceOutcome &= interactionOutcome;

                if (interactionOutcome && m_interruptionPolicy == ESequenceInterruptionPolicy.OnSuccess)
                {
                    return sequenceOutcome;
                }
                else if (!interactionOutcome && m_interruptionPolicy == ESequenceInterruptionPolicy.OnFailure)
                {
                    return sequenceOutcome;
                }
            }

            return sequenceOutcome;
        }
    }
}

