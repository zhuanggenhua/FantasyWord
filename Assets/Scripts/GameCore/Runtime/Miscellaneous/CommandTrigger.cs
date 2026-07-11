using System.Collections;
using UnityEngine;
using MackySoft.SerializeReferenceExtensions;

namespace FantasyWord.GameCore
{
    public class CommandTrigger : MonoBehaviour, IMovableCollisionReceiver, IInteractionReceiver
    {
        public enum EActivationEvent
        {
            OnStart,
            OnEnable,
            OnDisable,
            OnFixedUpdate,
            OnUpdate,
            OnPlayerEnterTrigger,
            OnPlayerExitTrigger,
            OnPlayerCollision,
            OnPlayerInteract,
            OnConditionStateChanged
        }

        [Header("Requirements")]
        [SerializeField] private EActivationEvent m_activationEvent;
        [SerializeReference, SubclassSelector] private ICondition m_condition;

        [Header("Actions")]
        [SerializeReference, SubclassSelector] private ICommand m_toExecute;

        [Header("Settings")]
        [SerializeField] private int m_frameDelay = 0;

        private void OnEnable()
        {
            AttemptExecution(EActivationEvent.OnEnable);

            if (m_activationEvent == EActivationEvent.OnConditionStateChanged)
            {
                m_condition.StartListening(OnConditionStateChanged);
            }
        }

        private void OnDisable()
        {
            AttemptExecution(EActivationEvent.OnDisable);

            if (m_activationEvent == EActivationEvent.OnConditionStateChanged)
            {
                m_condition.StopListening();
            }
        }

        private void OnConditionStateChanged() => AttemptExecution(EActivationEvent.OnConditionStateChanged);

        private void AttemptExecution(EActivationEvent currentEvent)
        {
            AttemptExecution(currentEvent, actor: null, actorRequired: false);
        }

        private void AttemptExecutionForActor(EActivationEvent currentEvent, CharacterBase actor)
        {
            AttemptExecution(currentEvent, actor, actorRequired: true);
        }

        private void AttemptExecution(EActivationEvent currentEvent, CharacterBase actor, bool actorRequired)
        {
            // CommandTrigger 只对当前正式玩家上下文执行，编辑器预览或系统未启动时直接跳过。
            if (GameManager.Exists() && GameManager.TryGetSystem(out PlayerSystem playerSystem))
            {
                CharacterBase currentControlledCharacter = playerSystem.GetCurrentControlledCharacterOrPlayerInstance();
                if (!currentControlledCharacter)
                {
                    return;
                }

                if (actorRequired && actor != currentControlledCharacter)
                {
                    return;
                }

                if (currentEvent == m_activationEvent && (m_condition?.Evaluate() ?? true))
                {
                    GameCommandContext commandContext = actorRequired
                        ? GameCommandContext.LocalPlayer(actor)
                        : GameCommandContext.Script(currentControlledCharacter, nameof(CommandTrigger));

                    if (m_frameDelay <= 0)
                    {
                        Execute(commandContext);
                    }
                    else
                    {
                        StartCoroutine(ExecuteAfterFrameDelay(m_frameDelay, commandContext));
                    }
                }
            }
        }

        private void AttemptTriggerExecution(EActivationEvent currentEvent, Collider2D collider = null)
        {
            CharacterBase actor = collider != null
                ? collider.GetComponentInParent<CharacterBase>()
                : null;
            if (actor == null)
            {
                return;
            }

            AttemptExecutionForActor(currentEvent, actor);
        }

        private void Execute(GameCommandContext context)
        {
            m_toExecute.Execute(context);
        }

        private IEnumerator ExecuteAfterFrameDelay(int frames, GameCommandContext context)
        {
            for (int i = 0; i < frames; ++i)
            {
                yield return null;
            }

            Execute(context);
        }

        private void Start() => AttemptExecution(EActivationEvent.OnStart);
        private void FixedUpdate() => AttemptExecution(EActivationEvent.OnFixedUpdate);
        private void Update() => AttemptExecution(EActivationEvent.OnUpdate);
        private void OnTriggerEnter2D(Collider2D collider) => AttemptTriggerExecution(EActivationEvent.OnPlayerEnterTrigger, collider);
        private void OnTriggerExit2D(Collider2D collider) => AttemptTriggerExecution(EActivationEvent.OnPlayerExitTrigger, collider);
        public void OnMovableCollision(Movable movable) => AttemptExecutionForActor(EActivationEvent.OnPlayerCollision, movable as CharacterBase);
        public void OnInteract(CharacterBase sender) => AttemptExecutionForActor(EActivationEvent.OnPlayerInteract, sender);
    }
}
