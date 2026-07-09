using System;
using System.Threading.Tasks;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class PlayDialogueLine : IContextualCommand
    {
        [SerializeField] private string m_speaker = string.Empty;
        [TextArea][SerializeField] private string m_line = string.Empty;

        public async Task Execute()
        {
            await Execute(GameCommandContext.Script());
        }

        public async Task Execute(GameCommandContext context)
        {
            await GameManager.DialogueSystem.PlayNow(new DialogueTree(new DialogueNode(StringFormatter.Format(m_line), m_speaker), context));
        }
    }
}

