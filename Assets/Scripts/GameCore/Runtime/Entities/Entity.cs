using System;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Events;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class EntityDataBlock : PersistableDataBlock
    {
        public Vector3 position;
        public Quaternion rotation;
        public Vector3 scale;
    }

    public class Entity : Persistable, IInteractionTarget
    {
        [Header("Entity Settings")]
        [SerializeField] private UIFloatingIcon m_floatingIcon = null;
        [SerializeReference, SubclassSelector] private IInteraction m_interaction = null;

        [Header("Feedbacks")]
        [SerializeField]
        [Tooltip("实体交互成功或拒绝时的表现反馈。交互规则仍由 IInteraction/ICommand 负责。")]
        private GameplayFeedbackSet m_feedbacks = new();

        public virtual string GetSpeakerName() => string.Empty;

        public void SetFloatingIcon(EFloatingIcon icon, float? duration = null) => m_floatingIcon?.SetIcon(icon, duration);

        public virtual async Task Say(DialogueSequence sequence, UnityAction<DialogueMessageFeed> onDialogueEnded = null, params string[] args)
        {
            await Say(sequence, GameCommandContext.Script(), onDialogueEnded, args);
        }

        public virtual async Task Say(DialogueSequence sequence, CharacterBase source, UnityAction<DialogueMessageFeed> onDialogueEnded = null, params string[] args)
        {
            await Say(sequence, ResolveDialogueCommandContext(source), onDialogueEnded, args);
        }

        private async Task Say(DialogueSequence sequence, GameCommandContext commandContext, UnityAction<DialogueMessageFeed> onDialogueEnded = null, params string[] args)
        {
            string speaker = GetSpeakerName();

            DialogueTree dialogueTree = sequence.ToDialogueTree(speaker, commandContext, args);

            if (onDialogueEnded != null)
            {
                dialogueTree.AddEndedListener(onDialogueEnded);
            }

            await GameManager.DialogueSystem.PlayNow(dialogueTree);
        }

        private static GameCommandContext ResolveDialogueCommandContext(CharacterBase source)
        {
            return GameCommandContext.ResolveForActor(source);
        }

        public virtual void OnInteract(CharacterBase sender)
        {
            _ = ExecuteInteraction(sender);
        }

        private async Task ExecuteInteraction(CharacterBase sender)
        {
            if (m_interaction == null)
            {
                m_feedbacks.PlayInteractionDenied(transform.position);
                GameRuntimeEvents.NotifyInteractionPresentation(new InteractionPresentationContext(transform.position, sender, this, false));
                return;
            }

            bool executed = await m_interaction.TryExecute(sender, this);
            if (executed)
            {
                m_feedbacks.PlayInteractionActivation(transform.position);
                GameRuntimeEvents.NotifyInteractionPresentation(new InteractionPresentationContext(transform.position, sender, this, true));
            }
            else
            {
                m_feedbacks.PlayInteractionDenied(transform.position);
                GameRuntimeEvents.NotifyInteractionPresentation(new InteractionPresentationContext(transform.position, sender, this, false));
            }
        }

        protected override Type GetDataBlockType() => typeof(EntityDataBlock);

        protected override void OnSave(PersistableDataBlock block)
        {
            base.OnSave(block);
            block.As<EntityDataBlock>().position = transform.position;
            block.As<EntityDataBlock>().rotation = transform.rotation;
            block.As<EntityDataBlock>().scale = transform.localScale;
        }

        protected override void OnLoad(PersistableDataBlock block)
        {
            base.OnLoad(block);
            transform.position = block.As<EntityDataBlock>().position;
            transform.rotation = block.As<EntityDataBlock>().rotation;
            transform.localScale = block.As<EntityDataBlock>().scale;
        }
    }
}

