using UnityEngine;

namespace FantasyWord.GameCore
{
    public class MeleeAttackAbility : ActiveAbilityBase, IActionInterruptReceiver
    {
        protected override void ExecuteAbilityUse()
        {
        }

        protected override void OnInputGateSequenceStartedInternal()
        {
        }

        protected override void OnInputGateSequenceStoppedInternal()
        {
        }

        protected override void OnInputGateInterruptedInternal()
        {
        }

        protected override FormalAbilityInputGateSettings ResolveFormalAbilityInputGateSettings()
        {
            if (usesFormalGasAbility &&
                FormalGasAbilityTimelineExecutionResolver.TryResolveTimelineExecutionSettings(
                    formalGasAbilityCode,
                    out FormalGasTimelineExecutionSettings timelineSettings))
            {
                return FormalAbilityInputGateSettings.CreateTimelineGate(
                    ResolveFormalInputGateSettings(),
                    timelineSettings.delayBeforeUse,
                    timelineSettings.timeBetweenUses);
            }

            Debug.LogError($"{name} 没有可用的 EX-GAS Timeline 执行配置。MeleeAttackAbility 只作为 EX-GAS 基础攻击运行桥使用。", this);
            return FormalAbilityInputGateSettings.CreateTimelineGate(
                ResolveFormalInputGateSettings(),
                0.0f,
                0.0f);
        }

        private FormalAbilityInputGateConfig ResolveFormalInputGateSettings()
        {
            if (TryGetFormalGasRuntimeConfig(out FormalGasAbilityRuntimeConfig config))
            {
                return config.InputGate;
            }

            Debug.LogWarning($"EX-GAS Ability {formalGasAbilityCode} 已绑定 EX-GAS Timeline，但缺少 exgas.abilityGameCore 输入配置；本次仅使用空输入兜底。");
            return new FormalAbilityInputGateConfig();
        }

        protected override GameplayFeedbackSet ResolveGameplayFeedbacks()
        {
            return new GameplayFeedbackSet();
        }

        public override void Reset()
        {
            base.Reset();
        }

        public override void UpdateCooldowns(float deltaTime)
        {
            base.UpdateCooldowns(deltaTime);
        }

        public void OnActionInterrupted()
        {
            Interrupt();
        }
    }
}

