using System.Collections.Generic;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Events;

namespace FantasyWord.GameCore
{
    public class AwaitableDialogueTree
    {
        public DialogueTree dialogue { get; set; }
        public TaskCompletionSource<bool> task { get; set; }
    }

    public class DialogueChannel : MonoBehaviour
    {
        private readonly UnityEvent<DialogueTree> m_dialogueStarted = new();
        private readonly UnityEvent<DialogueTree> m_dialogueEnded = new();
        private readonly UnityEvent<DialogueNode> m_dialogueNodeChanged = new();
        private AwaitableDialogueTree m_currentTree = null;
        private DialogueNode m_currentNode = null;
        private readonly Queue<AwaitableDialogueTree> m_dialogueQueue = new();

        public void AddStartedListener(UnityAction<DialogueTree> listener) => m_dialogueStarted.AddListener(listener);
        public void RemoveStartedListener(UnityAction<DialogueTree> listener) => m_dialogueStarted.RemoveListener(listener);
        public void AddEndedListener(UnityAction<DialogueTree> listener) => m_dialogueEnded.AddListener(listener);
        public void RemoveEndedListener(UnityAction<DialogueTree> listener) => m_dialogueEnded.RemoveListener(listener);
        public void AddNodeChangedListener(UnityAction<DialogueNode> listener) => m_dialogueNodeChanged.AddListener(listener);
        public void RemoveNodeChangedListener(UnityAction<DialogueNode> listener) => m_dialogueNodeChanged.RemoveListener(listener);

        public void Interrupt()
        {
            if (m_currentTree != null)
            {
                ClearQueue();
                OnDialogueCompleted();
            }
        }

        public TaskCompletionSource<bool> AddToQueue(DialogueTree dialogue)
        {
            Debug.Assert(dialogue != null, "Cannot enqueue a null dialogue tree.");

            var task = new TaskCompletionSource<bool>();

            m_dialogueQueue.Enqueue(new()
            {
                dialogue = dialogue,
                task = task
            });

            return task;
        }

        public void ClearQueue()
        {
            foreach (var dialogue in m_dialogueQueue)
            {
                if (!dialogue.task.Task.IsCompleted)
                {
                    dialogue.task.SetResult(false);
                }
            }

            m_dialogueQueue.Clear();
        }

        public async Task PlayNow(string line, params object[] args)
        {
            await PlayNow(new DialogueTree(new DialogueNode(StringFormatter.Format(line, args))));
        }

        public async Task PlayNow(DialogueTree dialogue)
        {
            var task = AddToQueue(dialogue);

            if (!IsPlaying())
            {
                await PlayQueue();
            }
            else
            {
                await task.Task;
            }
        }

        public async Task PlayQueue()
        {
            if (!IsPlaying())
            {
                while (m_dialogueQueue.Count > 0)
                {
                    var current = m_dialogueQueue.Dequeue();
                    Play(current);
                    await current.task.Task;
                }
            }
        }

        public bool TrySkipping()
        {
            if (m_currentNode != null && m_currentNode.optionCount < 2)
            {
                Next();
                return true;
            }

            return false;
        }

        public void Next(int option = 0)
        {
            m_currentTree.dialogue.OnNodeExecuted(m_currentNode, option);
            m_currentNode.ExecuteCompletionCommand(m_currentTree.dialogue.CommandContext);
            SetCurrentNode(m_currentNode.GetNext(option));
        }

        public bool IsPlaying() => m_currentTree != null;

        private void Play(AwaitableDialogueTree tree)
        {
            if (tree.dialogue.HasEntryPoint())
            {
                m_currentTree = tree;
                m_dialogueStarted.Invoke(tree.dialogue);
                tree.dialogue.NotifyStarted();
                SetCurrentNode(tree.dialogue.GetEntryPoint());
            }
            else
            {
                Debug.LogError("Cannot start a dialogue with a null entry point node.");
            }
        }

        private void SetCurrentNode(DialogueNode node)
        {
            m_currentNode = node;
            m_dialogueNodeChanged.Invoke(m_currentNode);

            if (m_currentNode == null)
            {
                OnDialogueCompleted();
            }
            else
            {
                m_currentNode.ExecuteStartCommand(m_currentTree.dialogue.CommandContext);
            }
        }

        private void OnDialogueCompleted()
        {
            if (IsPlaying())
            {
                m_currentNode = null;
                m_dialogueEnded.Invoke(m_currentTree.dialogue);
                m_currentTree.dialogue.NotifyEnded();
                var task = m_currentTree.task;
                m_currentTree = null;
                task.SetResult(true);
            }
        }
    }
}
