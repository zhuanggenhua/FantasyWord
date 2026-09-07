using System;
using System.Collections.Generic;
using System.Linq;
using Sirenix.OdinInspector;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色装备玩法真相组件。
    /// 负责维护 RPG 装备槽、初始装备、装备属性贡献、装备附加 Formal GAS Ability，以及装备变化事件。
    /// </summary>
    /// <remarks>
    /// 这里是玩法层 owner，不负责 Sprite、Animator 或坐骑外观刷新；表现层通过
    /// <see cref="EquipmentLoadoutChanged"/> 订阅状态变化。背包物品数量和物品转移仍由
    /// <see cref="InventorySystem"/> 管理，装备组件只关心“当前角色槽位上穿着什么”。
    /// </remarks>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(CharacterBase))]
    public sealed class CharacterEquipment : MonoBehaviour
    {
        [SerializeField]
        [LabelText("角色引用"), Tooltip("装备属性和附加能力作用到的角色；通常自动取同物体上的 CharacterBase。")]
        private CharacterBase m_character = null;

        [SerializeField]
        [LabelText("初始装备列表"), Tooltip("角色 Awake 时自动穿上的装备；会刷新属性并通知表现层。")]
        private Equipment[] m_initialEquipment = Array.Empty<Equipment>();

        // 实际槽位容器。单独拆出是为了让装备规则编排和存档快照构建保持清楚的边界。
        private readonly CharacterEquippedItemLoadout m_equipmentLoadout = new();

        // 变形、解除装备效果等临时规则会压制装备带来的属性和 Formal GAS Ability。
        // value 是同一来源叠加次数，避免多个同源规则移除时把别的规则提前释放。
        private readonly Dictionary<CharacterAbilitySourceKey, int> m_alterationEquipmentEffectSuppressions = new();

        /// <summary>装备作用到的角色。</summary>
        public CharacterBase Character => m_character;

        /// <summary>
        /// 装备槽变化事件。
        /// 表现层、UI 或缓存刷新可以监听它，但不能把它当成装备规则的第二真相源。
        /// </summary>
        public event Action EquipmentLoadoutChanged;

        /// <summary>
        /// 创建当前装备属性贡献快照。
        /// 如果当前存在装备效果压制规则，会返回空属性，避免变形等状态继续吃装备加成。
        /// </summary>
        public Stats CreateStatContributionSnapshot()
        {
            return BuildEquipmentStatContribution();
        }

        /// <summary>
        /// 创建装备槽存档快照。
        /// 使用数据库引用保存装备资产，避免存档直接依赖场景对象或临时实例。
        /// </summary>
        public CharacterEquipmentSlotData[] CreateSlotDataSnapshot(DatabaseRegistry databaseRegistry)
        {
            return m_equipmentLoadout.CreateSlotDataSnapshot(databaseRegistry);
        }

        /// <summary>
        /// 从存档槽位数据恢复装备。
        /// 恢复时暂缓每次装备的属性刷新，所有槽位处理完后统一刷新角色属性并通知表现层。
        /// </summary>
        public bool RestoreFromSlotData(
            IEnumerable<CharacterEquipmentSlotData> equipmentSlots,
            Func<DatabaseEntryReference<Equipment>, Equipment> resolveEquipment)
        {
            bool restored = m_equipmentLoadout.RestoreFromSlotData(
                equipmentSlots,
                resolveEquipment,
                item => Equip(item, autoUpdateStats: false));
            if (restored)
            {
                RefreshCharacterStats();
                EquipmentLoadoutChanged?.Invoke();
            }

            return restored;
        }

        /// <summary>
        /// 尝试装备指定装备。
        /// 会校验角色是否允许换装，以及属性变化是否会让生命/法力跌破当前资源规则。
        /// </summary>
        public EEquipmentOperationResult TryEquip(Equipment equipment, out Equipment previousEquipment)
        {
            previousEquipment = null;
            if (!equipment)
            {
                return EEquipmentOperationResult.InvalidTarget;
            }

            return TryApplyEquipmentSlotChange(equipment.type, equipment, out previousEquipment);
        }

        /// <summary>
        /// 尝试卸下指定槽位装备。
        /// </summary>
        public EEquipmentOperationResult TryUnequip(EEquipmentType type, out Equipment previousEquipment)
        {
            return TryApplyEquipmentSlotChange(type, null, out previousEquipment);
        }

        /// <summary>
        /// 查询指定槽位当前装备。
        /// </summary>
        public bool TryGetEquipment(EEquipmentType type, out Equipment equipment)
        {
            return m_equipmentLoadout.TryGet(type, out equipment);
        }

        /// <summary>
        /// 获取当前全部已装备物品快照。
        /// 返回数组快照，避免外部直接修改内部槽位容器。
        /// </summary>
        public Equipment[] GetEquippedItems()
        {
            return m_equipmentLoadout.SnapshotItems();
        }

        /// <summary>
        /// 生命周期流程强制卸下全部装备。
        /// 主要用于死亡、尸体转移或重建装备状态，不走普通玩家换装门禁。
        /// </summary>
        internal Equipment[] ForceUnequipAllEquipmentForLifecycle()
        {
            Equipment[] equippedItems = GetEquippedItems();
            if (equippedItems.Length == 0)
            {
                return Array.Empty<Equipment>();
            }

            List<Equipment> removedEquipment = new(equippedItems.Length);
            foreach (Equipment equipment in equippedItems)
            {
                if (!equipment)
                {
                    continue;
                }

                Equipment previousEquipment = ApplyEquipmentSlotChange(
                    CreateEquipmentSlotChange(equipment.type, null),
                    autoUpdateStats: false);

                if (previousEquipment)
                {
                    removedEquipment.Add(previousEquipment);
                }
            }

            RefreshCharacterStats();
            return removedEquipment.ToArray();
        }

        /// <summary>
        /// 添加装备效果压制规则。
        /// 该规则会临时压制当前装备提供的属性和附加 Formal GAS Ability，来源相同可叠加。
        /// </summary>
        public void ApplyAlterationEquipmentEffectSuppressionRule(CharacterAbilitySourceKey source)
        {
            m_alterationEquipmentEffectSuppressions.TryGetValue(source, out int currentStackCount);
            m_alterationEquipmentEffectSuppressions[source] = currentStackCount + 1;
            ApplyEquipmentBonusFormalGasAbilitySuppressions(GetEquippedEquipmentBonusFormalGasAbilityCodeSnapshot(), source, 1);
            RefreshCharacterStats();
        }

        /// <summary>
        /// 移除一层指定来源的装备效果压制规则。
        /// 只移除一层，避免同来源多次压制被一次释放。
        /// </summary>
        public void RemoveAlterationEquipmentEffectSuppressionRuleStack(CharacterAbilitySourceKey source)
        {
            if (!m_alterationEquipmentEffectSuppressions.TryGetValue(source, out int currentStackCount))
            {
                return;
            }

            RemoveEquipmentBonusFormalGasAbilitySuppressions(GetEquippedEquipmentBonusFormalGasAbilityCodeSnapshot(), source, 1);
            int nextStackCount = currentStackCount - 1;
            if (nextStackCount <= 0)
            {
                m_alterationEquipmentEffectSuppressions.Remove(source);
            }
            else
            {
                m_alterationEquipmentEffectSuppressions[source] = nextStackCount;
            }

            RefreshCharacterStats();
        }

        /// <summary>
        /// 移除指定来源的全部装备效果压制规则。
        /// </summary>
        public void RemoveAllAlterationEquipmentEffectSuppressionRules(CharacterAbilitySourceKey source)
        {
            if (!m_alterationEquipmentEffectSuppressions.TryGetValue(source, out int currentStackCount))
            {
                return;
            }

            RemoveEquipmentBonusFormalGasAbilitySuppressions(GetEquippedEquipmentBonusFormalGasAbilityCodeSnapshot(), source, currentStackCount);
            m_alterationEquipmentEffectSuppressions.Remove(source);
            RefreshCharacterStats();
        }

        /// <summary>
        /// 清空全部装备效果压制规则。
        /// 角色重置或死亡清理时使用，保证装备能力压制不会跨生命周期残留。
        /// </summary>
        internal void ClearAlterationEquipmentEffectSuppressionRules()
        {
            if (m_alterationEquipmentEffectSuppressions.Count == 0)
            {
                return;
            }

            int[] currentEquipmentFormalGasAbilityCodes = GetEquippedEquipmentBonusFormalGasAbilityCodeSnapshot();
            foreach ((CharacterAbilitySourceKey source, int stackCount) in m_alterationEquipmentEffectSuppressions)
            {
                RemoveEquipmentBonusFormalGasAbilitySuppressions(currentEquipmentFormalGasAbilityCodes, source, stackCount);
            }

            m_alterationEquipmentEffectSuppressions.Clear();
            RefreshCharacterStats();
        }

        /// <summary>
        /// 直接应用装备到对应槽位。
        /// 这是内部恢复和初始装备入口，不做玩家换装门禁。
        /// </summary>
        private Equipment Equip(Equipment equipment, bool autoUpdateStats = true)
        {
            return ApplyEquipmentSlotChange(CreateEquipmentSlotChange(equipment.type, equipment), autoUpdateStats);
        }

        /// <summary>
        /// 计算装备提供的属性贡献。
        /// 压制规则生效时返回空属性，让角色属性刷新天然扣掉装备加成。
        /// </summary>
        private Stats BuildEquipmentStatContribution()
        {
            if (HasAlterationEquipmentEffectSuppression())
            {
                return new Stats();
            }

            return m_equipmentLoadout.BuildStatContribution();
        }

        /// <summary>
        /// 尝试应用单槽装备变化。
        /// 这里集中处理换装门禁、资源下限校验、能力增减和属性刷新，避免 UI 或背包系统复制规则。
        /// </summary>
        private EEquipmentOperationResult TryApplyEquipmentSlotChange(
            EEquipmentType type,
            Equipment nextEquipment,
            out Equipment previousEquipment)
        {
            previousEquipment = null;
            if (!m_character)
            {
                return EEquipmentOperationResult.InvalidTarget;
            }

            if (!m_character.Can(EActionFlags.ChangeEquipment))
            {
                return EEquipmentOperationResult.ActionLocked;
            }

            CharacterEquipmentSlotChange change = CreateEquipmentSlotChange(type, nextEquipment);
            Stats effectiveStatDelta = HasAlterationEquipmentEffectSuppression() ? new Stats() : change.StatDelta;

            // 换装可能扣掉生命/法力上限或当前值，先让 CharacterBase 校验资源下限，避免穿脱装备直接造成非法状态。
            EEquipmentOperationResult result = MapEquipmentValidationResult(
                m_character.ValidateCurrentResourceDelta(effectiveStatDelta, minimumHealth: 1));

            if (result == EEquipmentOperationResult.Valid)
            {
                previousEquipment = ApplyEquipmentSlotChange(change, autoUpdateStats: true);
            }

            return result;
        }

        /// <summary>
        /// 创建单槽变化描述。
        /// 预先算出属性差量和 Formal GAS Ability 差量，后续校验与正式应用共用同一份结果。
        /// </summary>
        private CharacterEquipmentSlotChange CreateEquipmentSlotChange(EEquipmentType type, Equipment nextEquipment)
        {
            m_equipmentLoadout.TryGet(type, out Equipment currentEquipment);
            Stats statDelta = new();

            if (currentEquipment)
            {
                statDelta -= currentEquipment.CreateBonusStatsSnapshot();
            }

            if (nextEquipment)
            {
                statDelta += nextEquipment.CreateBonusStatsSnapshot();
            }

            return new CharacterEquipmentSlotChange(
                type,
                currentEquipment,
                nextEquipment,
                statDelta,
                GetEquipmentBonusFormalGasAbilityCodesSnapshot(currentEquipment),
                GetEquipmentBonusFormalGasAbilityCodesSnapshot(nextEquipment));
        }

        /// <summary>
        /// 正式应用装备槽变化。
        /// 顺序是先撤旧能力和旧压制，再写槽位，再加新能力和新压制，最后刷新属性并广播变化。
        /// </summary>
        private Equipment ApplyEquipmentSlotChange(CharacterEquipmentSlotChange change, bool autoUpdateStats)
        {
            bool hasPreviousSource = TryPrepareEquipmentAbilitySource(
                change.PreviousEquipment,
                change.RemovedFormalGasAbilityCodes,
                out CharacterAbilitySourceKey previousSource);
            bool hasNextSource = TryPrepareEquipmentAbilitySource(
                change.NextEquipment,
                change.AddedFormalGasAbilityCodes,
                out CharacterAbilitySourceKey nextSource);

            RemoveEquipmentBonusFormalGasAbilitySuppressions(change.RemovedFormalGasAbilityCodes);
            if (hasPreviousSource)
            {
                ApplyEquipmentBonusFormalGasAbilityCodes(
                    change.RemovedFormalGasAbilityCodes,
                    code => m_character.RemoveBonusFormalGasAbility(code, previousSource));
            }

            m_equipmentLoadout.Set(change.SlotType, change.NextEquipment);
            if (hasNextSource)
            {
                ApplyEquipmentBonusFormalGasAbilityCodes(
                    change.AddedFormalGasAbilityCodes,
                    code => m_character.AddBonusFormalGasAbility(code, nextSource));
            }

            ApplyEquipmentBonusFormalGasAbilitySuppressions(change.AddedFormalGasAbilityCodes);

            if (autoUpdateStats)
            {
                RefreshCharacterStats();
            }

            EquipmentLoadoutChanged?.Invoke();
            return change.PreviousEquipment;
        }

        /// <summary>
        /// 为装备附加能力准备稳定来源。
        /// 装备带来的 Formal GAS Ability 必须带来源 GUID，后续卸装、压制或存档恢复才能精确撤回。
        /// </summary>
        private static bool TryPrepareEquipmentAbilitySource(
            Equipment equipment,
            int[] formalGasAbilityCodes,
            out CharacterAbilitySourceKey source)
        {
            source = default;
            if (formalGasAbilityCodes == null || formalGasAbilityCodes.Length == 0)
            {
                return false;
            }

            if (!equipment)
            {
                throw new InvalidOperationException(
                    $"[{nameof(CharacterEquipment)}] 装备附加能力需要有效装备来源，不能在缺少装备资产时变更能力来源。");
            }

            if (!GameManager.Database.TryCreateReference(equipment, out DatabaseEntryReference<Equipment> reference))
            {
                throw new InvalidOperationException(
                    $"[{nameof(CharacterEquipment)}] 装备 {equipment.name} 未登记到 DatabaseRegistry，不能在装备状态改变后再丢失附加能力来源。");
            }

            source = new CharacterAbilitySourceKey(ECharacterAbilitySourceKind.Equipment, reference.guid);
            return true;
        }

        /// <summary>
        /// 获取单件装备提供的 Formal GAS Ability 编码快照。
        /// </summary>
        private static int[] GetEquipmentBonusFormalGasAbilityCodesSnapshot(Equipment equipment)
        {
            return equipment ? equipment.GetBonusFormalGasAbilityCodes() : Array.Empty<int>();
        }

        /// <summary>
        /// 获取当前全部已装备物品提供的 Formal GAS Ability 编码快照。
        /// 去重后再处理，避免同一能力码被同一轮压制重复应用。
        /// </summary>
        private int[] GetEquippedEquipmentBonusFormalGasAbilityCodeSnapshot()
        {
            return GetEquippedItems()
                .SelectMany(GetEquipmentBonusFormalGasAbilityCodesSnapshot)
                .Where(code => code > 0)
                .Distinct()
                .ToArray();
        }

        /// <summary>
        /// 当前是否存在任何有效装备效果压制规则。
        /// </summary>
        private bool HasAlterationEquipmentEffectSuppression()
        {
            foreach (int stackCount in m_alterationEquipmentEffectSuppressions.Values)
            {
                if (stackCount > 0)
                {
                    return true;
                }
            }

            return false;
        }

        /// <summary>
        /// 把当前所有压制来源应用到指定能力码集合。
        /// </summary>
        private void ApplyEquipmentBonusFormalGasAbilitySuppressions(IEnumerable<int> formalGasAbilityCodes)
        {
            foreach ((CharacterAbilitySourceKey source, int stackCount) in m_alterationEquipmentEffectSuppressions)
            {
                ApplyEquipmentBonusFormalGasAbilitySuppressions(formalGasAbilityCodes, source, stackCount);
            }
        }

        /// <summary>
        /// 为指定来源添加装备附加能力压制。
        /// </summary>
        private void ApplyEquipmentBonusFormalGasAbilitySuppressions(
            IEnumerable<int> formalGasAbilityCodes,
            CharacterAbilitySourceKey source,
            int count)
        {
            ApplyEquipmentBonusFormalGasAbilityCodes(
                formalGasAbilityCodes,
                code => m_character.AddSourcedFormalGasAbilitySuppression(code, source, count));
        }

        /// <summary>
        /// 从指定能力码集合中移除当前所有压制来源。
        /// </summary>
        private void RemoveEquipmentBonusFormalGasAbilitySuppressions(IEnumerable<int> formalGasAbilityCodes)
        {
            foreach ((CharacterAbilitySourceKey source, int stackCount) in m_alterationEquipmentEffectSuppressions)
            {
                RemoveEquipmentBonusFormalGasAbilitySuppressions(formalGasAbilityCodes, source, stackCount);
            }
        }

        /// <summary>
        /// 为指定来源移除装备附加能力压制。
        /// </summary>
        private void RemoveEquipmentBonusFormalGasAbilitySuppressions(
            IEnumerable<int> formalGasAbilityCodes,
            CharacterAbilitySourceKey source,
            int count)
        {
            ApplyEquipmentBonusFormalGasAbilityCodes(
                formalGasAbilityCodes,
                code => m_character.RemoveSourcedFormalGasAbilitySuppression(code, source, count));
        }

        /// <summary>
        /// 对有效 Formal GAS Ability 编码逐个执行操作。
        /// 小于等于 0 的编码视为未配置，直接跳过。
        /// </summary>
        private static void ApplyEquipmentBonusFormalGasAbilityCodes(IEnumerable<int> formalGasAbilityCodes, Action<int> applyAbility)
        {
            foreach (int formalGasAbilityCode in formalGasAbilityCodes)
            {
                if (formalGasAbilityCode > 0)
                {
                    applyAbility(formalGasAbilityCode);
                }
            }
        }

        /// <summary>
        /// 把角色资源校验结果映射成装备操作结果。
        /// </summary>
        private static EEquipmentOperationResult MapEquipmentValidationResult(EResourceValidationResult validationResult)
        {
            return validationResult switch
            {
                EResourceValidationResult.HealthBelowMinimum => EEquipmentOperationResult.NotEnoughHealth,
                EResourceValidationResult.ManaBelowMinimum => EEquipmentOperationResult.NotEnoughMana,
                _ => EEquipmentOperationResult.Valid
            };
        }

        /// <summary>
        /// 刷新角色装备属性解析结果。
        /// </summary>
        private void RefreshCharacterStats()
        {
            m_character?.RefreshResolvedStatsForEquipmentRuntime();
        }

        /// <summary>
        /// 启动时补齐角色引用并应用初始装备。
        /// 初始装备会走内部 Equip，不受玩家换装门禁影响。
        /// </summary>
        private void Awake()
        {
            EnsureCharacterReference();
            ApplyInitialEquipment();
        }

        /// <summary>
        /// 新挂组件或重置 Inspector 时补齐角色引用。
        /// </summary>
        private void Reset()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// Inspector 修改后刷新角色引用。
        /// </summary>
        private void OnValidate()
        {
            EnsureCharacterReference();
        }

        /// <summary>
        /// 只从同物体解析角色，保证装备 owner 和角色生命周期绑定。
        /// </summary>
        private void EnsureCharacterReference()
        {
            if (m_character == null)
            {
                TryGetComponent(out m_character);
            }
        }

        /// <summary>
        /// 应用 Prefab 上配置的初始装备。
        /// 全部装备处理完后统一刷新属性并通知表现层，减少重复刷新。
        /// </summary>
        private void ApplyInitialEquipment()
        {
            if (m_initialEquipment == null || m_initialEquipment.Length == 0)
            {
                return;
            }

            foreach (Equipment equipment in m_initialEquipment)
            {
                if (!equipment)
                {
                    continue;
                }

                Equip(equipment, autoUpdateStats: false);
            }

            RefreshCharacterStats();
            EquipmentLoadoutChanged?.Invoke();
        }
    }
}
