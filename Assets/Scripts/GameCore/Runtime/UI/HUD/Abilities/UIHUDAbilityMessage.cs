using System.Collections;
using Sirenix.OdinInspector;
using TMPro;
using Unity.Mathematics;
using UnityEngine;
using YokiFrame;
using azixMcAze.SerializableDictionary;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// HUD 技能失败提示面板。
    /// 它监听本地玩家命令和技能释放失败事件，只负责把失败原因转换成短提示并做淡出表现。
    /// </summary>
    public class UIHUDAbilityMessage : MonoBehaviour
    {
        #region Inspector 配置

        [SerializeField]
        [LabelText("提示文本")]
        [Tooltip("显示技能或本地命令失败原因的 TMP 文本。")]
        protected TextMeshProUGUI m_message = null;

        [SerializeField, Min(0.0f)]
        [LabelText("淡出前停留秒数")]
        [Tooltip("提示显示后等待多久开始淡出。")]
        protected float m_delayBeforeFadeOut = 1.5f;

        [SerializeField, Min(0.0f)]
        [LabelText("淡出时长")]
        [Tooltip("提示从完全可见到隐藏的淡出秒数。")]
        protected float m_fadeOutDuration = 0.5f;

        [SerializeField]
        [LabelText("技能失败文案")]
        [Tooltip("按技能释放检查结果配置的提示文案；未配置时不显示该类技能失败提示。")]
        private SerializableDictionary<EAbilityFireCheckResult, string> m_messages = null;

        #endregion

        private Coroutine m_hideCoroutine = null;

        #region 生命周期

        /// <summary>初始化时清空文本状态，避免编辑器残留文案进入运行时。</summary>
        private void Awake()
        {
            ResetVisualState();
        }

        /// <summary>
        /// 注册本地失败提示事件。
        /// 这是纯 HUD 提示层，不应在 UI 被隐藏或销毁后继续保留全局失败提示监听。
        /// </summary>
        private void OnEnable()
        {
            EventKit.Type.Register<PlayerAbilityFireFailedEvent>(OnPlayerAbilityFireFailed);
            EventKit.Type.Register<LocalPlayerCommandFailedEvent>(OnLocalPlayerCommandFailed);
        }

        /// <summary>注销失败提示事件，并隐藏当前提示。</summary>
        private void OnDisable()
        {
            EventKit.Type.UnRegister<PlayerAbilityFireFailedEvent>(OnPlayerAbilityFireFailed);
            EventKit.Type.UnRegister<LocalPlayerCommandFailedEvent>(OnLocalPlayerCommandFailed);
            Hide();
        }

        /// <summary>销毁时停止淡出协程，避免协程继续访问已销毁文本。</summary>
        private void OnDestroy()
        {
            Hide();
        }

        #endregion

        #region 失败原因解析

        /// <summary>处理技能系统直接返回的释放失败原因。</summary>
        private void OnPlayerAbilityFireFailed(PlayerAbilityFireFailedEvent evt)
        {
            OnPlayerFireFailed(evt.Reason);
        }

        /// <summary>处理本地玩家命令失败，并只显示有明确玩家含义的失败原因。</summary>
        private void OnLocalPlayerCommandFailed(LocalPlayerCommandFailedEvent evt)
        {
            if (TryGetCommandFailureMessage(evt.Result, out string message))
            {
                Show(message);
            }
        }

        /// <summary>按 Inspector 配置把技能释放失败枚举转换成提示文案。</summary>
        private void OnPlayerFireFailed(EAbilityFireCheckResult reason)
        {
            if (m_messages.ContainsKey(reason))
            {
                Show(m_messages[reason]);
                return;
            }
        }

        /// <summary>把本地命令失败合同转换成短提示；无需提示的移动类失败返回 false。</summary>
        private static bool TryGetCommandFailureMessage(PlayerCommandResult result, out string message)
        {
            message = result.FailureReason switch
            {
                EPlayerCommandFailureReason.MissingInputTarget => ResolveNoControlledCharacterMessage(result.Request.Kind),
                EPlayerCommandFailureReason.InvalidControlledCharacter => ResolveNoControlledCharacterMessage(result.Request.Kind),
                EPlayerCommandFailureReason.InvalidTarget => ResolveInvalidTargetMessage(result.Request.Kind),
                EPlayerCommandFailureReason.ActorMismatch => "这个角色不在当前控制组。",
                EPlayerCommandFailureReason.ControlLocked => "我现在不能控制这个角色。",
                EPlayerCommandFailureReason.InteractionLocked => ResolveInteractionLockedMessage(result.Request.Kind),
                EPlayerCommandFailureReason.MissingAbility => ResolveMissingAbilityMessage(result.Request.Kind),
                EPlayerCommandFailureReason.BlockedByState => ResolveBlockedByStateMessage(result.Request.Kind),
                EPlayerCommandFailureReason.NotRunning => ResolveNotRunningMessage(result.Request.Kind),
                _ => null
            };

            return !string.IsNullOrWhiteSpace(message);
        }

        /// <summary>没有当前控制角色时，移动停止类命令保持静默，其他命令提示玩家先选中可控角色。</summary>
        private static string ResolveNoControlledCharacterMessage(EPlayerCommandKind kind)
        {
            return kind switch
            {
                EPlayerCommandKind.StopMove => null,
                EPlayerCommandKind.Move => null,
                _ => "当前没有可控制角色。"
            };
        }

        /// <summary>技能命令缺少槽位能力时显示装备缺失提示。</summary>
        private static string ResolveMissingAbilityMessage(EPlayerCommandKind kind)
        {
            return kind == EPlayerCommandKind.FireAbility
                ? "这个槽位没有装备技能。"
                : null;
        }

        /// <summary>交互锁定只对交互命令显示提示。</summary>
        private static string ResolveInteractionLockedMessage(EPlayerCommandKind kind)
        {
            return kind == EPlayerCommandKind.Interact
                ? "我现在不能交互。"
                : null;
        }

        /// <summary>把状态阻塞转换成玩家能理解的短提示。</summary>
        private static string ResolveBlockedByStateMessage(EPlayerCommandKind kind)
        {
            return kind switch
            {
                EPlayerCommandKind.Interact => "没有可交互对象。",
                EPlayerCommandKind.ClickMove => "我现在不能移动到那里。",
                EPlayerCommandKind.OpenGameMenu => "我现在不能打开这个界面。",
                EPlayerCommandKind.FireAbility => "我现在不能施放技能。",
                _ => null
            };
        }

        /// <summary>无效目标只对点击移动和交互显示提示。</summary>
        private static string ResolveInvalidTargetMessage(EPlayerCommandKind kind)
        {
            return kind switch
            {
                EPlayerCommandKind.ClickMove => "没有可用的移动目标。",
                EPlayerCommandKind.Interact => "没有可交互对象。",
                _ => null
            };
        }

        /// <summary>系统未运行时，只提示玩家主动打开菜单或施放技能这类可感知操作。</summary>
        private static string ResolveNotRunningMessage(EPlayerCommandKind kind)
        {
            return kind switch
            {
                EPlayerCommandKind.OpenGameMenu => "我现在不能打开这个界面。",
                EPlayerCommandKind.FireAbility => "我现在不能施放技能。",
                _ => null
            };
        }

        #endregion

        #region 显示与淡出

        /// <summary>显示一条提示，并重新计算自动淡出的协程。</summary>
        public void Show(string message)
        {
            InterruptPreviousMessage();

            m_message.text = message;
            m_message.enabled = true;
            m_message.alpha = 1.0f;

            m_hideCoroutine = StartCoroutine(FadeOutAfterDelay(Mathf.Max(0.0f, m_delayBeforeFadeOut)));
        }

        /// <summary>中断上一条提示的淡出流程，让新提示完整显示。</summary>
        private void InterruptPreviousMessage()
        {
            StopHideCoroutine();
        }

        /// <summary>停止当前淡出协程，并清空协程句柄。</summary>
        private void StopHideCoroutine()
        {
            if (m_hideCoroutine != null)
            {
                StopCoroutine(m_hideCoroutine);
                m_hideCoroutine = null;
            }
        }

        /// <summary>等待指定时间后淡出提示，完成后重置文本状态。</summary>
        private IEnumerator FadeOutAfterDelay(float delay)
        {
            yield return new WaitForSeconds(delay);
            yield return FadeOut(Mathf.Max(0.0f, m_fadeOutDuration));

            m_hideCoroutine = null;
            ResetVisualState();
        }

        /// <summary>使用 unscaledDeltaTime 淡出，保证暂停菜单或时间缩放下提示仍能正常退场。</summary>
        private IEnumerator FadeOut(float duration)
        {
            float elapsedTime = 0.0f;

            while (elapsedTime < duration)
            {
                m_message.alpha = math.lerp(1.0f, 0.0f, elapsedTime / duration);
                elapsedTime += Time.unscaledDeltaTime;
                yield return null;
            }

            m_message.alpha = 0.0f;
        }

        /// <summary>立即隐藏提示，并停止任何正在进行的淡出协程。</summary>
        private void Hide()
        {
            StopHideCoroutine();
            ResetVisualState();
        }

        /// <summary>清空文本、透明度和启用状态；文本引用缺失时保持安全空操作。</summary>
        private void ResetVisualState()
        {
            if (m_message == null)
            {
                return;
            }

            m_message.text = string.Empty;
            m_message.alpha = 0.0f;
            m_message.enabled = false;
        }

        #endregion
    }
}
