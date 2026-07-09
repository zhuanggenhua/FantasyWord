using System;
using System.Collections.Generic;
using MackySoft.SerializeReferenceExtensions;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum EDialogueMessageType
    {
        None,
        Custom,
        Accept,
        Decline
    }

    [System.Serializable]
    public class DialogueMessageFeed
    {
        private readonly HashSet<DialogueMessage> m_messages = new();

        internal void Add(DialogueMessage message)
        {
            m_messages.Add(message);
        }

        public bool Contains(string message)
        {
            return Contains(new DialogueMessage
            {
                type = EDialogueMessageType.Custom,
                customMessage = message
            });
        }

        public bool Contains(EDialogueMessageType type)
        {
            return Contains(new DialogueMessage
            {
                type = type,
                customMessage = string.Empty
            });
        }

        public bool Contains(DialogueMessage message)
        {
            return m_messages.Contains(message);
        }
    }

    [System.Serializable]
    public struct DialogueMessage
    {
        public EDialogueMessageType type;
        public string customMessage;

        public override string ToString()
        {
            switch (type)
            {
                case EDialogueMessageType.None: return string.Empty;
                case EDialogueMessageType.Custom: return customMessage.ToLower();
            }

            return type.ToString().ToLower();
        }

        public override int GetHashCode()
        {
            return ToString().GetHashCode();
        }

        public override bool Equals(object obj)
        {
            return ToString().Equals(obj.ToString());
        }

        public bool Equals(EDialogueMessageType type)
        {
            return Equals(new DialogueMessage { type = type });
        }
    }

    [System.Serializable]
    public struct DialogueNodeOption
    {
        public string name;
        public DialogueNode node;
        public DialogueMessage message;
    }

    public class DialogueNode
    {
        [SerializeReference, SubclassSelector]
        private ICommand m_toExecuteOnStart;

        [SerializeReference, SubclassSelector]
        private ICommand m_toExecuteOnCompletion;

        private string m_text;
        private string m_speaker;
        private DialogueNodeOption[] m_options = Array.Empty<DialogueNodeOption>();

        public string text => m_text;
        public string speaker => m_speaker;
        public int optionCount => m_options?.Length ?? 0;

        public DialogueNode(
            string text = "",
            string speaker = "",
            DialogueNodeOption[] options = null,
            ICommand toExecuteOnStart = null,
            ICommand toExecuteOnCompletion = null)
        {
            SetContent(text, speaker);
            SetOptions(options);
            ApplyLifecycleCommands(toExecuteOnStart, toExecuteOnCompletion);
        }

        public DialogueNode GetNext(int option)
        {
            return TryGetOption(option, out DialogueNodeOption selectedOption)
                ? selectedOption.node
                : null;
        }

        public DialogueNodeOption[] GetOptions()
        {
            return m_options != null
                ? (DialogueNodeOption[])m_options.Clone()
                : Array.Empty<DialogueNodeOption>();
        }

        public bool TryGetOption(int index, out DialogueNodeOption option)
        {
            if (m_options != null && index >= 0 && index < m_options.Length)
            {
                option = m_options[index];
                return true;
            }

            option = default;
            return false;
        }

        internal void SetContent(string text, string speaker)
        {
            m_text = text;
            m_speaker = speaker;
        }

        internal void SetOptions(DialogueNodeOption[] options)
        {
            m_options = options != null
                ? (DialogueNodeOption[])options.Clone()
                : Array.Empty<DialogueNodeOption>();
        }

        internal void ApplyLifecycleCommands(ICommand onStart, ICommand onCompletion)
        {
            m_toExecuteOnStart = onStart;
            m_toExecuteOnCompletion = onCompletion;
        }

        internal void ExecuteStartCommand()
        {
            ExecuteStartCommand(GameCommandContext.Script());
        }

        internal void ExecuteStartCommand(GameCommandContext context)
        {
            m_toExecuteOnStart.Execute(context);
        }

        internal void ExecuteCompletionCommand()
        {
            ExecuteCompletionCommand(GameCommandContext.Script());
        }

        internal void ExecuteCompletionCommand(GameCommandContext context)
        {
            m_toExecuteOnCompletion.Execute(context);
        }
    }
}
