using System;
using System.Threading.Tasks;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class ExecuteCommandIf : IContextualCommand
    {
        [SerializeReference, SubclassSelector] private ICondition m_condition = null;
        [SerializeReference, SubclassSelector] private ICommand m_ifTrue = null;
        [SerializeReference, SubclassSelector] private ICommand m_ifFalse = null;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            if (m_condition?.Evaluate() ?? true)
            {
                return m_ifTrue.Execute(context);
            }
            else
            {
                return m_ifFalse.Execute(context);
            }
        }
    }
}

