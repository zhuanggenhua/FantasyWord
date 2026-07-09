using System;
using System.Threading.Tasks;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class ConditionalInteraction : IInteraction
    {
        [SerializeReference, SubclassSelector] private ICondition m_condition = null;
        [SerializeReference, SubclassSelector] private IInteraction m_interaction = null;

        public Task<bool> TryExecute(CharacterBase source, IInteractionTarget target)
        {
            if (m_condition?.Evaluate() ?? true)
            {
                return m_interaction.TryExecute(source, target);
            }

            return Task.FromResult(false);
        }
    }
}

