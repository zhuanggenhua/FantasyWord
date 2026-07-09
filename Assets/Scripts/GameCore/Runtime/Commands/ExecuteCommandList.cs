using System;
using System.Threading.Tasks;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    public enum ECommandListExecutionMode
    {
        Sequential,
        Parallel
    }

    [Serializable]
    public class ExecuteCommandList : IContextualCommand
    {
        [SerializeField] private ECommandListExecutionMode m_executionMode = ECommandListExecutionMode.Sequential;
        [SerializeField] private EActionFlags m_disabledActions = EActionFlags.None;
        [SerializeReference, SubclassSelector] private ICommand[] m_commands = null;

        private async Task ExecuteSequential(GameCommandContext context)
        {
            if (m_commands == null)
            {
                return;
            }

            foreach (ICommand command in m_commands)
            {
                await command.Execute(context);
            }
        }

        private async Task ExecuteParallel(GameCommandContext context)
        {
            if (m_commands == null || m_commands.Length == 0)
            {
                return;
            }

            Task[] tasks = new Task[m_commands.Length];

            for (int i = 0; i < m_commands.Length; i++)
            {
                tasks[i] = m_commands[i].Execute(context);
            }

            await Task.WhenAll(tasks);
        }

        public async Task Execute()
        {
            await Execute(GameCommandContext.Script());
        }

        public async Task Execute(GameCommandContext context)
        {
            CharacterBase actionLockTarget = context.ResolveActorOrCurrentControlledCharacter();
            actionLockTarget?.DisableActions(m_disabledActions);

            try
            {
                if (m_executionMode == ECommandListExecutionMode.Sequential)
                {
                    await ExecuteSequential(context);
                }
                else
                {
                    await ExecuteParallel(context);
                }
            }
            finally
            {
                actionLockTarget?.EnableActions(m_disabledActions);
            }
        }
    }
}

