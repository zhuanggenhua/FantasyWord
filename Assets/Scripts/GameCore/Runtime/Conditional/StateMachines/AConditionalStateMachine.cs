using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    public enum EConditionalState
    {
        None,
        Met,
        NotMet
    }

    public abstract class AConditionalStateMachine : MonoBehaviour
    {
        [SerializeReference, SubclassSelector] private ICondition m_condition = null;

        public EConditionalState state => m_state;

        private EConditionalState m_state = EConditionalState.None;

        protected virtual void OnConditionMet() { }
        protected virtual void OnConditionNotMet() { }

        private void Start()
        {
            UpdateState();
            m_condition?.StartListening(UpdateState);
        }

        private void OnDestroy()
        {
            m_condition?.StopListening();
        }

        private void UpdateState()
        {
            EConditionalState newState = (m_condition?.Evaluate() ?? true) ? EConditionalState.Met : EConditionalState.NotMet;

            if (newState != m_state)
            {
                m_state = newState;

                switch (m_state)
                {
                    case EConditionalState.Met:
                        OnConditionMet();
                        break;

                    case EConditionalState.NotMet:
                        OnConditionNotMet();
                        break;
                }
            }
        }
    }
}

