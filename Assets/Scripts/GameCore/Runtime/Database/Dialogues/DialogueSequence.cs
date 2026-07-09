using System.Collections.Generic;
using MackySoft.SerializeReferenceExtensions;
using UnityEngine;
using UnityEngine.Serialization;

namespace FantasyWord.GameCore
{
    [System.Serializable]
    public struct DialogueSequenceOption
    {
        [SerializeField, FormerlySerializedAs("name")]
        private string m_name;

        [SerializeField, FormerlySerializedAs("sequence")]
        private DialogueSequence m_sequence;

        [SerializeField, FormerlySerializedAs("message")]
        private DialogueMessage m_message;

        public string name => m_name;
        public DialogueSequence sequence => m_sequence;
        public DialogueMessage message => m_message;
    }

    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Dialogues + nameof(DialogueSequence))]
    public class DialogueSequence : DatabaseEntry
    {
        [SerializeField] private string[] m_lines = null;
        [SerializeField] private DialogueSequenceOption[] m_options = null;
        [SerializeReference, SubclassSelector] private ICommand m_toExecuteOnStart = null;
        [SerializeReference, SubclassSelector] private ICommand m_toExecuteOnCompletion = null;

        public int lineCount => m_lines?.Length ?? 0;
        public int optionCount => m_options?.Length ?? 0;
        public string GetLineAt(int index) => index >= 0 && index < lineCount ? m_lines[index] : string.Empty;
        public DialogueSequenceOption GetOptionAt(int index) => index >= 0 && index < optionCount ? m_options[index] : default;
        public DialogueSequenceOption[] GetOptions() => m_options != null ? (DialogueSequenceOption[])m_options.Clone() : System.Array.Empty<DialogueSequenceOption>();

        internal void ApplyLifecycleCommands(DialogueNode node)
        {
            if (node == null)
            {
                return;
            }

            node.ApplyLifecycleCommands(m_toExecuteOnStart, m_toExecuteOnCompletion);
        }

        public DialogueTree ToDialogueTree(string speaker, params string[] args)
        {
            return DialogueUtils.CreateDialogueTree(this, speaker, args);
        }

        public DialogueTree ToDialogueTree(string speaker, GameCommandContext commandContext, params string[] args)
        {
            return DialogueUtils.CreateDialogueTree(this, speaker, commandContext, args);
        }
    }
}
