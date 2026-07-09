using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class AddOrRemoveMoney : IContextualCommand
    {
        [SerializeField] private EAction m_action = EAction.Add;
        [SerializeField][Min(0)] private int m_amount = 0;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            Debug.Assert(m_amount != 0, "Invalid quantity! Expected != 0");

            switch (m_action)
            {
                case EAction.Add:
                    GameManager.InventorySystem.AddMoney(m_amount);
                    break;

                case EAction.Remove:
                    GameManager.InventorySystem.RemoveMoney(m_amount);
                    break;
            }

            return Task.CompletedTask;
        }
    }
}

