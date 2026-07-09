using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class PlayDialogueSequence : IContextualCommand
    {
        [SerializeField] private DialogueSequence m_dialogueSequence = null;
        [SerializeField] private string m_speaker = string.Empty;

        public Task Execute()
        {
            return Execute(GameCommandContext.Script());
        }

        public Task Execute(GameCommandContext context)
        {
            return m_dialogueSequence != null
                ? GameManager.DialogueSystem.PlayNow(m_dialogueSequence.ToDialogueTree(m_speaker, context))
                : Task.CompletedTask;
        }
    }
}

