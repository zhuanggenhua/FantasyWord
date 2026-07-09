using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public enum EMessagePropagationMode
    {
        /// <summary>
        /// 保留原序列化值 3，确保已经登记的动画资源继续命中显式接收者模式。
        /// 旧的 Broadcast/Send/SendUpwards 字符串传播分支已经从正式运行时移除。
        /// </summary>
        RequireExplicitReceiver = 3
    }

    [Serializable]
    public struct MessageData
    {
        public string message;
        public EMessagePropagationMode propagationMode;

        public bool IsValid() => !string.IsNullOrWhiteSpace(message);
    }

    public class StateMessageDispatcher : StateMachineBehaviour
    {
        public MessageData animationStartMessage;
        public MessageData animationEndMessage;


        override public void OnStateEnter(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        {
            if (animationStartMessage.IsValid())
            {
                PropagateMessage(animator, animationStartMessage);
            }
        }

        override public void OnStateExit(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
        {
            if (animationEndMessage.IsValid())
            {
                PropagateMessage(animator, animationEndMessage);
            }
        }

        private void PropagateMessage(Component source, MessageData messageData)
        {
            if (messageData.propagationMode != EMessagePropagationMode.RequireExplicitReceiver)
            {
                Debug.Assert(false, $"Animation message '{messageData.message}' is still configured to use a removed string propagation mode on '{source.name}'.");
                return;
            }

            if (TryPropagateKnownMessage(source, messageData.message))
            {
                return;
            }

            Debug.Assert(false, $"Animation message '{messageData.message}' requires an explicit animation-state receiver contract, but no registered contract handled it.");
        }

        /// <summary>
        /// 当前仓库里已登记的状态机消息必须命中正式接口合同。
        /// 这些消息的资产配置已经全部进入台账；如果没找到接收者，就说明当前接线有误，
        /// 不再悄悄退回旧的字符串传播模式掩盖问题。
        /// </summary>
        private static bool TryPropagateKnownMessage(Component source, string message)
        {
            switch (message)
            {
                case AnimationStateMessageNames.InvincibleAnimationStart:
                    RequireDispatch(source, message, static (ICharacterAnimationStateReceiver receiver) => receiver.OnInvincibleAnimationStart());
                    return true;

                case AnimationStateMessageNames.InvincibleAnimationStop:
                    RequireDispatch(source, message, static (ICharacterAnimationStateReceiver receiver) => receiver.OnInvincibleAnimationStop());
                    return true;

                case AnimationStateMessageNames.DeathAnimationStart:
                    RequireDispatch(source, message, static (ICharacterAnimationStateReceiver receiver) => receiver.OnDeathAnimationStart());
                    return true;

                case AnimationStateMessageNames.DeathAnimationStop:
                    RequireDispatch(source, message, static (ICharacterAnimationStateReceiver receiver) => receiver.OnDeathAnimationStop());
                    return true;

                case AnimationStateMessageNames.FadeInCompleted:
                    RequireDispatch(source, message, static (ITransitionAnimationStateReceiver receiver) => receiver.OnFadeInCompleted());
                    return true;

                case AnimationStateMessageNames.FadeOutCompleted:
                    RequireDispatch(source, message, static (ITransitionAnimationStateReceiver receiver) => receiver.OnFadeOutCompleted());
                    return true;

                case AnimationStateMessageNames.FloatingTextAnimationEnd:
                    RequireDispatch(source, message, static (IFloatingTextAnimationStateReceiver receiver) => receiver.OnFloatingTextAnimationEnd());
                    return true;
            }

            return false;
        }

        private static void RequireDispatch<TReceiver>(Component source, string message, Action<TReceiver> dispatch)
            where TReceiver : class
        {
            TReceiver receiver = source.GetComponentInParent<TReceiver>();
            Debug.Assert(receiver != null, $"Animation message '{message}' requires a parent {typeof(TReceiver).Name} receiver on '{source.name}'.");
            if (receiver != null)
            {
                dispatch(receiver);
            }
        }
    }
}

