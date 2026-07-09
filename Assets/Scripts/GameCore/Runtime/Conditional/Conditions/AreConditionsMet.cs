using System;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    public enum EGameConditionOperation
    {
        All,
        Any
    }

    [Serializable]
    public class AreConditionMet : ABaseCondition
    {
        [SerializeField]
        private EGameConditionOperation m_operator = EGameConditionOperation.All;

        [SerializeReference, SubclassSelector]
        private ICondition[] m_conditions = null;

        public override bool Evaluate()
        {
            switch (m_operator)
            {
                case EGameConditionOperation.All: return CheckAnd();
                case EGameConditionOperation.Any: return CheckOr();
            }

            return false;
        }

        private bool CheckAnd()
        {
            foreach (ICondition condition in m_conditions)
            {
                if (!(condition?.Evaluate() ?? true))
                {
                    return false;
                }
            }

            return true;
        }

        private bool CheckOr()
        {
            foreach (ICondition condition in m_conditions)
            {
                if (condition?.Evaluate() ?? true)
                {
                    return true;
                }
            }

            return false;
        }

        public override void StartListening(Action action)
        {
            base.StartListening(action);

            foreach (ICondition condition in m_conditions)
            {
                condition?.StartListening(action);
            }
        }

        public override void StopListening()
        {
            base.StopListening();

            foreach (ICondition condition in m_conditions)
            {
                condition?.StopListening();
            }
        }
    }
}

