using System;
using System.Collections.Generic;
using System.Linq;
using GAS.Runtime;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Events;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色能力集：角色系统对 EX-GAS 的封装层
    ///
    /// 设计说明：
    /// - 这不是 EX-GAS 的官方推荐用法，而是项目针对角色系统的自定义封装
    /// - EX-GAS 官方推荐直接使用 AbilitySystemComponent（ASC）
    /// - 本类在 ASC 之上提供了角色特定的能力管理功能
    ///
    /// 职责：
    /// - 持有角色所有的正式技能（FormalGasAbility）实例
    /// - 管理装备栏（快捷技能槽）系统
    /// - 处理技能的激活、停止、冷却查询
    /// - 提供技能状态的存档和恢复
    /// - 桥接角色系统与 EX-GAS 系统
    ///
    /// 与 EX-GAS 的关系：
    /// - 内部持有 CharacterAbilitySetRuntime，其中包含 ASC 的引用
    /// - 将角色特定的技能规则（如装备栏、技能根节点）封装起来
    /// - 不直接暴露 ASC，避免角色系统与 GAS 底层强耦合
    ///
    /// 组件依赖：
    /// - CharacterBase：必需，通过 CharacterBase.RequireComponent 正向依赖
    /// - ASC（AbilitySystemComponent）：由运行时动态创建
    ///
    /// 注意事项：
    /// - 不能反向 RequireComponent<CharacterBase>，否则 Unity 自动补组件时会失败
    /// - ownsAbilityComposition=false 时，该组件只作为占位符存在
    /// </summary>
    // CharacterBase 已经正向要求 CharacterAbilitySet；
    // 这里不能反向 Require 抽象 CharacterBase，否则 Unity 自动补组件时会失败。
    [DisallowMultipleComponent]
    public sealed partial class CharacterAbilitySet : MonoBehaviour
    {
        // EX-GAS 能力系统的内部常量
        private const string FormalRuleLogicTypeName = "FormalAbilityRuleProxyLogic";
        private const int FormalAbilityCodeSeed = 1200000000;  // 正式技能代码起始值
        private const int FormalCooldownTagSeed = 1700000000;  // 冷却标签起始值

        [Header("能力组合")]
        [SerializeField]
        [LabelText("角色主体"), Tooltip("拥有这套能力组合的角色。必须和同对象 CharacterBase 对齐。")]
        private CharacterBase m_character = null;

        /// <summary>
        /// 是否拥有能力组合
        /// false 表示此组件只作为占位符，不实际管理技能
        /// </summary>
        [SerializeField]
        [LabelText("拥有能力组合"), Tooltip("关闭时组件只作为占位符，不创建或管理正式技能实例。")]
        private bool m_ownsAbilityComposition = true;

        // 技能根节点：不同类型的技能挂载到不同的根节点
        [SerializeField]
        [LabelText("静态技能根节点"), Tooltip("无方向技能实例的挂载根节点。为空会让对应技能缺少正式父节点。")]
        private Transform m_staticAbilityRoot = null;
        [SerializeField]
        [LabelText("多向技能根节点"), Tooltip("八方向或多方向技能实例的挂载根节点。")]
        private Transform m_polydirectionalAbilityRoot = null;
        [SerializeField]
        [LabelText("水平技能根节点"), Tooltip("左右水平技能实例的挂载根节点。")]
        private Transform m_horizontalAbilityRoot = null;

        /// <summary>
        /// 额外添加的正式技能代码（补充配置表之外的技能）
        /// </summary>
        [SerializeField]
        [LabelText("额外正式技能代码"), Tooltip("补充配置表之外的正式技能编号。重复或无效编号会在能力解析阶段暴露。")]
        private int[] m_additionalFormalGasAbilityCodes = null;

        // 运行时数据
        private readonly CharacterAbilitySetRuntime m_runtime = new();
        private readonly CharacterEquippedAbilityLoadout m_equippedAbilityLoadout = new(Constants.MaxEquipedAbilityCount);
        private readonly UnityEvent<CharacterEquippedAbilitySlotView[]> m_equippedAbilitiesChanged = new();

        public CharacterBase Character => m_character;
        public bool OwnsAbilityComposition => m_ownsAbilityComposition;
        internal CharacterAbilitySetRuntime Runtime => m_runtime;

        internal CharacterAbilityMenuEntry[] CreateActiveAbilityMenuEntrySnapshot()
        {
            if (!m_ownsAbilityComposition)
            {
                return System.Array.Empty<CharacterAbilityMenuEntry>();
            }

            List<CharacterAbilityMenuEntry> entries = new();
            foreach (int formalGasAbilityCode in m_runtime.GetFormalGasAbilityCodeSnapshots())
            {
                entries.Add(new CharacterAbilityMenuEntry(formalGasAbilityCode));
            }

            return entries.ToArray();
        }

        internal CharacterEquippedAbilitySlotView[] CreateEquippedAbilitySlotViewSnapshot()
        {
            return m_ownsAbilityComposition
                ? m_equippedAbilityLoadout.CreateSlotViewSnapshot()
                : Array.Empty<CharacterEquippedAbilitySlotView>();
        }

        internal bool TryGetFirstTriggerableFormalGasAbilityCode(out int formalGasAbilityCode)
        {
            formalGasAbilityCode = 0;
            if (!m_ownsAbilityComposition)
            {
                return false;
            }

            foreach (int candidateCode in m_runtime.GetFormalGasAbilityCodeSnapshots())
            {
                if (TryGetResolvedFormalGasActiveAbility(candidateCode, out ActiveAbilityBase ability) &&
                    ability.CanFire() == EAbilityFireCheckResult.Valid)
                {
                    formalGasAbilityCode = candidateCode;
                    return true;
                }
            }

            return false;
        }

        /// <summary>
        /// 激活指定的正式 EX-GAS 技能
        /// </summary>
        /// <param name="formalGasAbilityCode">技能代码</param>
        /// <param name="commandContext">命令上下文</param>
        /// <returns>技能激活检查结果</returns>
        internal EAbilityFireCheckResult FireFormalGasAbility(int formalGasAbilityCode, GameCommandContext commandContext)
        {
            if (!m_ownsAbilityComposition ||
                m_character == null ||
                formalGasAbilityCode <= 0 ||
                !TryGetResolvedFormalGasActiveAbility(formalGasAbilityCode, out ActiveAbilityBase ability))
            {
                return EAbilityFireCheckResult.Unknown;
            }

            return FireResolvedAbility(ability, commandContext);
        }

        /// <summary>
        /// 激活装备栏中指定槽位的技能
        /// </summary>
        /// <param name="index">槽位索引（0-based）</param>
        /// <param name="commandContext">命令上下文</param>
        /// <param name="activationContext">激活上下文（可选，包含瞄准方向等信息）</param>
        /// <returns>技能激活结果，包含检查结果和技能代码</returns>
        internal CharacterAbilityFireResult FireEquippedAbilityAtIndex(
            int index,
            GameCommandContext commandContext,
            AbilityActivationContext activationContext = null)
        {
            int formalGasAbilityCode = m_equippedAbilityLoadout.GetFormalGasAbilityCode(index);
            if (formalGasAbilityCode > 0 &&
                TryGetResolvedFormalGasActiveAbility(formalGasAbilityCode, out ActiveAbilityBase formalAbility))
            {
                return new CharacterAbilityFireResult(
                    FireResolvedAbility(formalAbility, commandContext, activationContext),
                    formalGasAbilityCode);
            }

            return new CharacterAbilityFireResult(EAbilityFireCheckResult.Unknown, 0);
        }

        internal bool StopFireFormalGasAbility(int formalGasAbilityCode)
        {
            if (!m_ownsAbilityComposition ||
                formalGasAbilityCode <= 0 ||
                !TryGetResolvedFormalGasActiveAbility(formalGasAbilityCode, out ActiveAbilityBase activeAbility))
            {
                return false;
            }

            activeAbility.StopFire();
            return true;
        }

        internal bool StopFireEquippedAbilityAtIndex(int index)
        {
            int formalGasAbilityCode = m_equippedAbilityLoadout.GetFormalGasAbilityCode(index);
            if (formalGasAbilityCode > 0 &&
                TryGetResolvedFormalGasActiveAbility(formalGasAbilityCode, out ActiveAbilityBase formalAbility))
            {
                formalAbility.StopFire();
                return true;
            }

            return false;
        }

        internal bool TryGetActiveAbilityCooldownSnapshot(
            CharacterEquippedAbilitySlotView slot,
            out CharacterAbilityCooldownSnapshot snapshot)
        {
            snapshot = default;
            if (!m_ownsAbilityComposition)
            {
                return false;
            }

            if (slot.FormalGasAbilityCode > 0 &&
                TryGetResolvedFormalGasActiveAbility(slot.FormalGasAbilityCode, out ActiveAbilityBase activeAbility))
            {
                activeAbility.GetCooldownState(out float remainingCooldown, out float cooldown);
                snapshot = new CharacterAbilityCooldownSnapshot(slot.FormalGasAbilityCode, remainingCooldown, cooldown);
                return true;
            }

            return false;
        }

        internal bool HasOtherAbilityInInputGateState(ActiveAbilityBase ignoredAbility, EFormalAbilityInputGateState[] blockedStates)
        {
            if (!m_ownsAbilityComposition || blockedStates == null || blockedStates.Length == 0)
            {
                return false;
            }

            foreach (KeyValuePair<int, AbilityBase> entry in m_runtime.GetFormalGasAbilityInstanceEntriesSnapshot())
            {
                if (entry.Value is not ActiveAbilityBase ability || ability == ignoredAbility)
                {
                    continue;
                }

                for (int i = 0; i < blockedStates.Length; i++)
                {
                    if (ability.inputGateState == blockedStates[i])
                    {
                        return true;
                    }
                }
            }

            return false;
        }

        internal bool ShouldLockTargetDirectionForInputGate()
        {
            if (!m_ownsAbilityComposition)
            {
                return false;
            }

            foreach (KeyValuePair<int, AbilityBase> entry in m_runtime.GetFormalGasAbilityInstanceEntriesSnapshot())
            {
                if (entry.Value is ActiveAbilityBase ability &&
                    ability.ShouldLockTargetDirectionDuringInputGateForRuntime())
                {
                    return true;
                }
            }

            return false;
        }

        internal bool TryGetFormalGasAbilityRuleCooldownState(
            int formalGasAbilityCode,
            out float remainingCooldown,
            out float cooldown)
        {
            remainingCooldown = 0.0f;
            cooldown = 0.0f;
            return m_ownsAbilityComposition &&
                formalGasAbilityCode > 0 &&
                TryGetFormalAbilityCooldownState(formalGasAbilityCode, out remainingCooldown, out cooldown);
        }

        internal bool TryEvaluateFormalGasAbilityRuleActivation(
            int formalGasAbilityCode,
            out EAbilityFireCheckResult result,
            out bool usesFormalCost)
        {
            result = EAbilityFireCheckResult.Unknown;
            usesFormalCost = false;
            return m_ownsAbilityComposition &&
                formalGasAbilityCode > 0 &&
                TryEvaluateFormalAbilityActivation(formalGasAbilityCode, out result, out usesFormalCost);
        }

        internal bool TryApplyFormalGasAbilityRuleCooldown(int formalGasAbilityCode, float durationOverride = 0.0f)
        {
            return m_ownsAbilityComposition &&
                formalGasAbilityCode > 0 &&
                TryApplyFormalAbilityCooldown(formalGasAbilityCode, durationOverride);
        }

        internal bool TryCommitFormalGasAbilityRuleUse(int formalGasAbilityCode, out EAbilityFireCheckResult result)
        {
            result = EAbilityFireCheckResult.Unknown;
            return m_ownsAbilityComposition &&
                formalGasAbilityCode > 0 &&
                TryCommitFormalAbilityUse(formalGasAbilityCode, true, out result);
        }

        internal bool TryValidateFormalGasAbilityRuleUseAtFirePoint(int formalGasAbilityCode, out EAbilityFireCheckResult result)
        {
            result = EAbilityFireCheckResult.Unknown;
            return m_ownsAbilityComposition &&
                formalGasAbilityCode > 0 &&
                TryValidateFormalAbilityUseAtFirePoint(formalGasAbilityCode, out result);
        }

        internal bool BeginFormalGasAbilityRuleLifecycle(
            int formalGasAbilityCode,
            AbilityActivationContext activationContext)
        {
            return m_ownsAbilityComposition &&
                formalGasAbilityCode > 0 &&
                BeginFormalAbilityRuleLifecycle(formalGasAbilityCode, activationContext);
        }

        internal void EndFormalGasAbilityRuleLifecycle(int formalGasAbilityCode)
        {
            if (m_ownsAbilityComposition && formalGasAbilityCode > 0)
            {
                EndFormalAbilityRuleLifecycle(formalGasAbilityCode);
            }
        }

        internal void CancelFormalGasAbilityRuleLifecycle(int formalGasAbilityCode)
        {
            if (m_ownsAbilityComposition && formalGasAbilityCode > 0)
            {
                CancelFormalAbilityRuleLifecycle(formalGasAbilityCode);
            }
        }

        internal void ClearFormalGasAbilityRuleCooldown(int formalGasAbilityCode)
        {
            if (m_ownsAbilityComposition && formalGasAbilityCode > 0)
            {
                ClearFormalAbilityCooldown(formalGasAbilityCode);
            }
        }

        /// <summary>
        /// 将技能装备到指定槽位
        /// </summary>
        /// <param name="formalGasAbilityCode">要装备的技能代码</param>
        /// <param name="index">目标槽位索引</param>
        /// <returns>装备是否成功</returns>
        internal bool TryEquipFormalGasAbilityCodeToSlot(int formalGasAbilityCode, int index)
        {
            if (!m_ownsAbilityComposition || !CanAssignFormalGasAbilityCode(formalGasAbilityCode, index))
            {
                return false;
            }

            // 如果已经装备了相同技能，直接返回成功
            if (m_equippedAbilityLoadout.GetFormalGasAbilityCode(index) == formalGasAbilityCode)
            {
                return true;
            }

            bool changed = m_equippedAbilityLoadout.TryAssignFormalGasAbilityCodeToSlot(index, formalGasAbilityCode);
            if (changed)
            {
                NotifyEquippedAbilitiesChanged();
            }

            return changed;
        }

        internal bool ClearEquippedAbilitySlot(int index)
        {
            if (!m_ownsAbilityComposition)
            {
                return false;
            }

            bool changed = m_equippedAbilityLoadout.ClearSlot(index);
            if (changed)
            {
                NotifyEquippedAbilitiesChanged();
            }

            return changed;
        }

        internal bool TryAutoEquipOwnedFormalGasAbilityCode(int formalGasAbilityCode)
        {
            if (!m_ownsAbilityComposition || !CanAssignFormalGasAbilityCode(formalGasAbilityCode))
            {
                return false;
            }

            bool changed = m_equippedAbilityLoadout.TryAutoAssignFormalGasAbilityCode(formalGasAbilityCode);
            if (changed)
            {
                NotifyEquippedAbilitiesChanged();
            }

            return changed;
        }

        internal bool RemoveEquippedFormalGasAbilityCodeFromAllSlots(int formalGasAbilityCode)
        {
            if (!m_ownsAbilityComposition)
            {
                return false;
            }

            bool changed = m_equippedAbilityLoadout.RemoveFormalGasAbilityCodeFromAllSlots(formalGasAbilityCode);
            if (changed)
            {
                NotifyEquippedAbilitiesChanged();
            }

            return changed;
        }

        internal CharacterAbilitySlotData[] CreateEquippedAbilitySlotDataSnapshot(DatabaseRegistry databaseRegistry)
        {
            return m_ownsAbilityComposition
                ? m_equippedAbilityLoadout.CreateSlotDataSnapshot(databaseRegistry)
                : Array.Empty<CharacterAbilitySlotData>();
        }

        internal bool RestoreEquippedAbilitiesFromSlotData(
            IEnumerable<CharacterAbilitySlotData> quickAbilitySlots)
        {
            if (!m_ownsAbilityComposition)
            {
                return false;
            }

            bool restored = m_equippedAbilityLoadout.RestoreFromSlotData(quickAbilitySlots);
            NotifyEquippedAbilitiesChanged();
            return restored;
        }

        internal void AddEquippedAbilitiesChangedListener(UnityAction<CharacterEquippedAbilitySlotView[]> listener)
        {
            if (listener == null)
            {
                return;
            }

            m_equippedAbilitiesChanged.AddListener(listener);
        }

        internal void RemoveEquippedAbilitiesChangedListener(UnityAction<CharacterEquippedAbilitySlotView[]> listener)
        {
            if (listener == null)
            {
                return;
            }

            m_equippedAbilitiesChanged.RemoveListener(listener);
        }

        internal int[] CreateInitialFormalGasAbilityCodeSet(IEnumerable<int> sheetFormalGasAbilityCodes)
        {
            if (!m_ownsAbilityComposition)
            {
                return Array.Empty<int>();
            }

            List<int> codes = new();
            AddFormalGasAbilityCodes(codes, sheetFormalGasAbilityCodes);
            AddFormalGasAbilityCodes(codes, m_additionalFormalGasAbilityCodes);

            return codes.ToArray();
        }

        internal bool TryResolveFormalGasAbilityRoot(
            EFormalGasAbilityRootMode rootMode,
            out Transform abilityRoot)
        {
            abilityRoot = null;
            if (!m_ownsAbilityComposition)
            {
                return false;
            }

            abilityRoot = rootMode switch
            {
                EFormalGasAbilityRootMode.Static => m_staticAbilityRoot,
                EFormalGasAbilityRootMode.Polydirectional => m_polydirectionalAbilityRoot,
                EFormalGasAbilityRootMode.Horizontal => m_horizontalAbilityRoot,
                _ => null
            };

            return abilityRoot != null;
        }

        internal CharacterAbilityRuntimeStateData[] CreateAbilityRuntimeStates()
        {
            if (!m_ownsAbilityComposition)
            {
                return Array.Empty<CharacterAbilityRuntimeStateData>();
            }

            return m_runtime.GetFormalGasAbilityInstanceEntriesSnapshot()
                .Select(entry => entry.Value.CreateFormalRuntimeState())
                .Where(state => state != null)
                .ToArray();
        }

        internal void LoadAbilityRuntimeStates(CharacterAbilityRuntimeStateData[] abilityRuntimeStates)
        {
            if (!m_ownsAbilityComposition || abilityRuntimeStates == null)
            {
                return;
            }

            foreach (CharacterAbilityRuntimeStateData abilityRuntimeState in abilityRuntimeStates)
            {
                if (abilityRuntimeState == null)
                {
                    continue;
                }

                if (!TryResolveRuntimeStateAbility(abilityRuntimeState, out AbilityBase ability))
                {
                    continue;
                }

                ability.RestoreFormalRuntimeState(abilityRuntimeState);
            }
        }

        private bool TryResolveRuntimeStateAbility(
            CharacterAbilityRuntimeStateData abilityRuntimeState,
            out AbilityBase ability)
        {
            ability = null;

            if (abilityRuntimeState.formalGasAbilityCode > 0)
            {
                if (m_runtime.TryGetFormalGasAbilityInstance(
                        abilityRuntimeState.formalGasAbilityCode,
                        out ability))
                {
                    return true;
                }

                Debug.LogWarning($"Could not find ability instance matching EX-GAS Ability [{abilityRuntimeState.formalGasAbilityCode}].");
                return false;
            }

            return false;
        }

        /// <summary>
        /// Awake：确保角色引用存在
        /// </summary>
        private void Awake()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// OnEnable：确保角色引用存在（支持运行时动态添加组件）
        /// </summary>
        private void OnEnable()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// Reset：编辑器重置时自动关联角色组件
        /// </summary>
        private void Reset()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// OnValidate：Inspector 值改变时验证引用
        /// </summary>
        private void OnValidate()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 确保 CharacterBase 引用存在
        /// 如果为空，尝试从同一 GameObject 获取
        /// </summary>
        private void EnsureCharacterReference()
        {
            if (m_character == null)
            {
                TryGetComponent(out m_character);
            }
        }

        private static void AddFormalGasAbilityCodes(List<int> codes, IEnumerable<int> formalGasAbilityCodes)
        {
            if (formalGasAbilityCodes == null)
            {
                return;
            }

            foreach (int formalGasAbilityCode in formalGasAbilityCodes)
            {
                AddFormalGasAbilityCode(codes, formalGasAbilityCode);
            }
        }

        private static void AddFormalGasAbilityCode(List<int> codes, int formalGasAbilityCode)
        {
            if (formalGasAbilityCode <= 0 || codes.Contains(formalGasAbilityCode))
            {
                return;
            }

            codes.Add(formalGasAbilityCode);
        }

        private bool TryGetResolvedEquippedActiveAbilityAtIndex(
            int index,
            out ActiveAbilityBase ability)
        {
            ability = null;

            int formalGasAbilityCode = m_equippedAbilityLoadout.GetFormalGasAbilityCode(index);
            if (formalGasAbilityCode > 0)
            {
                return TryGetResolvedFormalGasActiveAbility(formalGasAbilityCode, out ability);
            }

            return false;
        }

        private bool TryGetResolvedFormalGasActiveAbility(
            int formalGasAbilityCode,
            out ActiveAbilityBase ability)
        {
            ability = null;

            if (!m_runtime.TryGetFormalGasAbilityInstance(formalGasAbilityCode, out AbilityBase abilityBase) ||
                abilityBase is not ActiveAbilityBase activeAbility)
            {
                return false;
            }

            ability = activeAbility;
            return true;
        }

        /// <summary>
        /// 激活已解析的技能实例
        /// 处理方向设置、状态管理和技能触发
        /// </summary>
        /// <param name="ability">要激活的技能实例</param>
        /// <param name="commandContext">命令上下文</param>
        /// <param name="activationContext">激活上下文（可选，包含瞄准方向等）</param>
        /// <returns>技能激活检查结果</returns>
        private EAbilityFireCheckResult FireResolvedAbility(
            ActiveAbilityBase ability,
            GameCommandContext commandContext,
            AbilityActivationContext activationContext = null)
        {
            EAbilityFireCheckResult triggerAbilityCheckResult = ability.CanFire();

            if (triggerAbilityCheckResult == EAbilityFireCheckResult.Valid)
            {
                // 处理瞄准方向（如果激活上下文提供了）
                bool hasRequestedDirection = false;
                Vector2 requestedDirection = Vector2.zero;
                if (activationContext != null &&
                    activationContext.TryGetAimDirection(out Vector3 aimDirection))
                {
                    requestedDirection = new Vector2(aimDirection.x, aimDirection.y);
                    if (requestedDirection.sqrMagnitude > 0.0001f)
                    {
                        hasRequestedDirection = true;
                        requestedDirection.Normalize();
                        m_character.SetTargetDirection(requestedDirection);
                    }
                }

                // 更新角色朝向（如果技能需要）
                if (ability.ShouldUpdateLookAtDirectionOnFireForRuntime())
                {
                    Vector2 targetDirection = m_character.GetTargetDirection();
                    if (hasRequestedDirection)
                    {
                        targetDirection = requestedDirection;
                    }

                    if (targetDirection.sqrMagnitude > 0.0001f)
                    {
                        m_character.SetLookAtDirection(targetDirection);
                    }
                }

                // 激活技能（自动状态管理或手动管理）
                if (ability.UsesAutomaticRuntimeStateManagement())
                {
                    // 自动管理：激活 GameObject，技能结束后自动禁用
                    ability.gameObject.SetActive(true);
                    ability.Fire(
                        commandContext,
                        activationContext,
                        () => ability.gameObject.SetActive(false));
                }
                else
                {
                    // 手动管理：由技能自己控制生命周期
                    ability.Fire(commandContext, activationContext, null);
                }
            }

            return triggerAbilityCheckResult;
        }

        private bool CanAssignFormalGasAbilityCode(int formalGasAbilityCode, int targetIndex = -1)
        {
            if (formalGasAbilityCode <= 0)
            {
                return false;
            }

            if (!TryGetResolvedFormalGasActiveAbility(formalGasAbilityCode, out _))
            {
                string targetSuffix = targetIndex >= 0 ? $" 槽位 {targetIndex}" : string.Empty;
                Debug.LogWarning($"[{nameof(CharacterAbilitySet)}] 试图将未拥有的 EX-GAS Ability {formalGasAbilityCode} 装入{targetSuffix}。", this);
                return false;
            }

            return true;
        }

        private void NotifyEquippedAbilitiesChanged()
        {
            m_equippedAbilitiesChanged.Invoke(CreateEquippedAbilitySlotViewSnapshot());
        }

    }
}

