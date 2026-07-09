using System;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 可保存的本地输入门控快照。只保存输入节奏层状态，RPG 数值仍由角色和能力自己的 DataBlock 负责。
    /// </summary>
    [Serializable]
    public struct FormalAbilityInputGateData
    {
        public int currentAmmoLoaded;
    }

    /// <summary>
    /// 正式 GAS 能力的本地输入门控状态机。
    /// 它只负责把本地按键、缓冲、按住释放和本地节奏转换成 EX-GAS Ability 激活请求；
    /// 命中、伤害、效果和表现不在这里结算。
    /// </summary>
    public sealed class FormalAbilityInputGateRuntime
    {
        private readonly FormalAbilityInputGateSettings m_settings;
        private readonly Func<bool> m_canStartUseSequence;

        private EFormalAbilityInputGateState m_state = EFormalAbilityInputGateState.Idle;
        private float m_stateTimer = 0.0f;
        private bool m_triggerHeld = false;
        private bool m_triggerReleasedSinceLastUse = true;
        private bool m_bufferedInput = false;
        private float m_bufferTimer = 0.0f;
        private int m_remainingBurstUses = 0;
        private int m_currentAmmoLoaded = 0;
        private float m_timeScale = 1.0f;

        public EFormalAbilityInputGateState state => m_state;
        public int currentAmmoLoaded => m_currentAmmoLoaded;
        public bool isBusy => m_state != EFormalAbilityInputGateState.Idle &&
            m_state != EFormalAbilityInputGateState.Stop &&
            m_state != EFormalAbilityInputGateState.Interrupted;

        public event Action<EFormalAbilityInputGateState> stateChanged;
        public event Action sequenceStarted;
        public event Action usePerformed;
        public event Action sequenceStopped;
        public event Action reloadNeeded;
        public event Action reloadStarted;
        public event Action reloadCompleted;
        public event Action interrupted;

        public FormalAbilityInputGateRuntime(FormalAbilityInputGateSettings settings, Func<bool> canStartUseSequence = null)
        {
            m_settings = settings ?? throw new ArgumentNullException(nameof(settings));
            m_canStartUseSequence = canStartUseSequence;
            m_currentAmmoLoaded = m_settings.magazineSize;
        }

        public void SetTimeScale(float timeScale)
        {
            m_timeScale = Mathf.Max(0.05f, timeScale);
        }

        /// <summary>
        /// 处理按下攻击输入。返回 false 表示当前状态不接受这次请求。
        /// </summary>
        public bool RequestUse()
        {
            m_triggerHeld = true;

            if (m_settings.triggerMode == EFormalAbilityInputTriggerMode.HoldRelease)
            {
                if (m_state == EFormalAbilityInputGateState.Idle || m_state == EFormalAbilityInputGateState.Stop)
                {
                    return StartUseSequence();
                }

                return false;
            }

            if (m_settings.triggerMode == EFormalAbilityInputTriggerMode.SemiAuto && !m_triggerReleasedSinceLastUse)
            {
                TryBufferInput();
                return false;
            }

            if (m_state == EFormalAbilityInputGateState.Idle || m_state == EFormalAbilityInputGateState.Stop)
            {
                return StartUseSequence();
            }

            TryBufferInput();
            return m_bufferedInput;
        }

        /// <summary>
        /// 处理松开攻击输入。半自动武器依靠这个信号允许下一次开火。
        /// </summary>
        public void ReleaseUse()
        {
            m_triggerHeld = false;
            m_triggerReleasedSinceLastUse = true;

            if (m_state == EFormalAbilityInputGateState.Charging)
            {
                EnterUse();
                return;
            }

            if (m_state == EFormalAbilityInputGateState.DelayBeforeUse && m_settings.delayBeforeUseReleaseInterruption)
            {
                Interrupt();
                return;
            }

            if (m_state == EFormalAbilityInputGateState.DelayBetweenUses && m_settings.timeBetweenUsesReleaseInterruption)
            {
                StopUseSequence();
            }
        }

        /// <summary>
        /// 请求换弹。没有弹匣的能力不会进入换弹状态。
        /// </summary>
        public bool RequestReload()
        {
            if (!m_settings.magazineBased)
            {
                return false;
            }

            if (m_state == EFormalAbilityInputGateState.Reload || m_state == EFormalAbilityInputGateState.ReloadStart)
            {
                return false;
            }

            ChangeState(EFormalAbilityInputGateState.ReloadStart);
            reloadStarted?.Invoke();
            ChangeTimedState(EFormalAbilityInputGateState.Reload, m_settings.reloadTime);
            return true;
        }

        /// <summary>
        /// 由拥有者逐帧推进，保证状态机可测试且不依赖协程生命周期。
        /// </summary>
        public void Tick(float deltaTime)
        {
            deltaTime = Mathf.Max(0.0f, deltaTime) * m_timeScale;
            TickBuffer(deltaTime);

            switch (m_state)
            {
                case EFormalAbilityInputGateState.DelayBeforeUse:
                    TickTimedState(deltaTime, EnterUse);
                    break;
                case EFormalAbilityInputGateState.DelayBetweenUses:
                    TickDelayBetweenUses(deltaTime);
                    break;
                case EFormalAbilityInputGateState.Reload:
                    TickTimedState(deltaTime, CompleteReload);
                    break;
                case EFormalAbilityInputGateState.ReloadStop:
                case EFormalAbilityInputGateState.Stop:
                case EFormalAbilityInputGateState.Interrupted:
                    ChangeState(EFormalAbilityInputGateState.Idle);
                    TryConsumeBufferedInput();
                    break;
            }
        }

        public void Interrupt()
        {
            m_bufferedInput = false;
            m_bufferTimer = 0.0f;
            ChangeState(EFormalAbilityInputGateState.Interrupted);
            interrupted?.Invoke();
            sequenceStopped?.Invoke();
        }

        /// <summary>
        /// 读档后不恢复半段前摇、半段后摇、半段换弹或输入缓冲。
        /// 正式可持续的执行层事实目前只保留弹匣余量；其余忙碌态若没有完整规则生命周期一并恢复，只会制造假继续。
        /// </summary>
        public FormalAbilityInputGateData CreatePersistentData()
        {
            return new FormalAbilityInputGateData
            {
                currentAmmoLoaded = m_currentAmmoLoaded
            };
        }

        /// <summary>
        /// 持久化恢复只接回真正能独立存在的执行层事实。
        /// 若未来要恢复中途施法/换弹，必须先把 GAS active lifecycle、动作锁和回调一并定义成可恢复协议，而不是只回填局部状态机字段。
        /// </summary>
        public void LoadPersistentData(FormalAbilityInputGateData data)
        {
            m_state = EFormalAbilityInputGateState.Idle;
            m_stateTimer = 0.0f;
            m_triggerHeld = false;
            m_triggerReleasedSinceLastUse = true;
            m_bufferedInput = false;
            m_bufferTimer = 0.0f;
            m_remainingBurstUses = 0;
            m_currentAmmoLoaded = Mathf.Clamp(data.currentAmmoLoaded, 0, m_settings.magazineSize);
        }

        private bool StartUseSequence()
        {
            if (!CanStartUseSequence())
            {
                return false;
            }

            if (!HasEnoughAmmo())
            {
                if (m_settings.autoReload)
                {
                    RequestReload();
                    return true;
                }
                else
                {
                    ChangeState(EFormalAbilityInputGateState.ReloadNeeded);
                    reloadNeeded?.Invoke();
                    StopUseSequence();
                }

                return false;
            }

            m_bufferedInput = false;
            m_bufferTimer = 0.0f;
            m_triggerReleasedSinceLastUse = false;
            m_remainingBurstUses = m_settings.useBurstMode ? m_settings.burstLength : 1;
            sequenceStarted?.Invoke();
            ChangeState(EFormalAbilityInputGateState.Start);

            if (m_settings.triggerMode == EFormalAbilityInputTriggerMode.HoldRelease)
            {
                ChangeState(EFormalAbilityInputGateState.Charging);
                return true;
            }

            if (m_settings.delayBeforeUse > 0.0f)
            {
                ChangeTimedState(EFormalAbilityInputGateState.DelayBeforeUse, m_settings.delayBeforeUse);
            }
            else
            {
                EnterUse();
            }

            return true;
        }

        private void EnterUse()
        {
            if (!HasEnoughAmmo())
            {
                StopUseSequence();
                return;
            }

            ConsumeAmmo();
            --m_remainingBurstUses;
            ChangeState(EFormalAbilityInputGateState.Use);
            usePerformed?.Invoke();
            if (m_state != EFormalAbilityInputGateState.Use)
            {
                return;
            }

            float nextDelay = m_remainingBurstUses > 0
                ? m_settings.burstTimeBetweenShots
                : m_settings.timeBetweenUses;

            ChangeTimedState(EFormalAbilityInputGateState.DelayBetweenUses, nextDelay);
        }

        private void TickDelayBetweenUses(float deltaTime)
        {
            TickTimedState(deltaTime, () =>
            {
                if (m_remainingBurstUses > 0)
                {
                    EnterUse();
                    return;
                }

                if (m_settings.noInputReload && m_settings.magazineBased && !HasEnoughAmmo())
                {
                    RequestReload();
                    return;
                }

                if (m_settings.triggerMode == EFormalAbilityInputTriggerMode.Auto && m_triggerHeld)
                {
                    if (StartUseSequence())
                    {
                        return;
                    }
                }

                StopUseSequence();
            });
        }

        private void StopUseSequence()
        {
            if (m_state != EFormalAbilityInputGateState.Idle && m_state != EFormalAbilityInputGateState.Stop)
            {
                ChangeState(EFormalAbilityInputGateState.Stop);
                sequenceStopped?.Invoke();
            }
        }

        private void CompleteReload()
        {
            m_currentAmmoLoaded = m_settings.magazineSize;
            reloadCompleted?.Invoke();
            ChangeState(EFormalAbilityInputGateState.ReloadStop);
        }

        private bool HasEnoughAmmo()
        {
            return !m_settings.magazineBased || m_currentAmmoLoaded >= m_settings.ammoConsumedPerUse;
        }

        private void ConsumeAmmo()
        {
            if (m_settings.magazineBased)
            {
                m_currentAmmoLoaded = Mathf.Max(0, m_currentAmmoLoaded - m_settings.ammoConsumedPerUse);
            }
        }

        private void TryBufferInput()
        {
            if (!m_settings.bufferInput || m_settings.triggerMode == EFormalAbilityInputTriggerMode.HoldRelease)
            {
                return;
            }

            if (!m_bufferedInput || m_settings.newInputExtendsBuffer)
            {
                m_bufferedInput = true;
                m_bufferTimer = m_settings.maximumBufferDuration;
            }
        }

        private void TickBuffer(float deltaTime)
        {
            if (!m_bufferedInput)
            {
                return;
            }

            m_bufferTimer -= deltaTime;
            if (m_bufferTimer <= 0.0f)
            {
                m_bufferedInput = false;
                m_bufferTimer = 0.0f;
            }
        }

        private void TryConsumeBufferedInput()
        {
            if (!m_bufferedInput)
            {
                return;
            }

            if (m_settings.triggerMode == EFormalAbilityInputTriggerMode.HoldRelease)
            {
                m_bufferedInput = false;
                return;
            }

            if (m_settings.triggerMode == EFormalAbilityInputTriggerMode.SemiAuto && !m_triggerReleasedSinceLastUse)
            {
                return;
            }

            m_bufferedInput = false;
            StartUseSequence();
        }

        private bool CanStartUseSequence()
        {
            return m_canStartUseSequence?.Invoke() ?? true;
        }

        private void ChangeTimedState(EFormalAbilityInputGateState nextState, float duration)
        {
            m_stateTimer = Mathf.Max(0.0f, duration);
            ChangeState(nextState);
        }

        private void TickTimedState(float deltaTime, Action onCompleted)
        {
            m_stateTimer -= deltaTime;
            if (m_stateTimer <= 0.0f)
            {
                m_stateTimer = 0.0f;
                onCompleted?.Invoke();
            }
        }

        private void ChangeState(EFormalAbilityInputGateState nextState)
        {
            if (m_state == nextState)
            {
                return;
            }

            m_state = nextState;
            stateChanged?.Invoke(m_state);
        }
    }
}

