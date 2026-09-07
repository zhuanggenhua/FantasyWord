using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 角色能力集合运行时容器。
    /// 当前由 CharacterAbilitySet 持有，CharacterBase 不再保留第二套能力实例仓库。
    /// </summary>
    internal sealed class CharacterAbilitySetRuntime
    {
        // 永久解锁的正式能力集合。它表示角色自身已经拥有该能力，不受装备、状态效果等临时来源退场影响。
        private readonly HashSet<RuntimeAbilityKey> m_unlockedAbilities = new();
        // 临时授予能力来源表：能力编号 -> 来源键 -> 叠层数。
        // 来源键让装备、状态效果、变身和脚本授予可以分别撤回，避免只按能力编号粗暴删除。
        private readonly Dictionary<RuntimeAbilityKey, Dictionary<CharacterAbilitySourceKey, int>> m_bonusAbilitySources = new();
        // 临时压制能力来源表：能力编号 -> 来源键 -> 叠层数。
        // 压制只影响释放/展示资格，不销毁能力实例本身，撤回后可继续使用原实例状态。
        private readonly Dictionary<RuntimeAbilityKey, Dictionary<CharacterAbilitySourceKey, int>> m_suppressedAbilitySources = new();
        // 当前真正存活的能力实例。永久解锁和临时授予共享同一实例，避免 CharacterBase 维护第二套实例仓库。
        private readonly Dictionary<RuntimeAbilityKey, AbilityBase> m_instances = new();

        /// <summary>
        /// 为角色永久解锁一个正式 EX-GAS 能力。
        /// 只有第一次加入集合且没有现存实例时才创建 AbilityBase；创建失败会回滚解锁集合。
        /// </summary>
        public bool TryAddUnlockedFormalGasAbility(
            int formalGasAbilityCode,
            Func<int, AbilityBase> createInstance,
            Action<int> onAdded = null)
        {
            if (formalGasAbilityCode <= 0 || createInstance == null)
            {
                return false;
            }

            RuntimeAbilityKey key = RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode);
            bool requiresNewInstance = !m_instances.ContainsKey(key);
            bool wasAdded = m_unlockedAbilities.Add(key);

            if (wasAdded && requiresNewInstance)
            {
                AbilityBase instance = createInstance(formalGasAbilityCode);
                if (instance == null)
                {
                    m_unlockedAbilities.Remove(key);
                    return false;
                }

                m_instances[key] = instance;
                onAdded?.Invoke(formalGasAbilityCode);
            }

            return wasAdded;
        }

        /// <summary>
        /// 从指定来源临时授予一个正式能力。
        /// 返回值表示本次是否创建了新的能力实例；来源叠层增加本身不一定返回 true。
        /// </summary>
        public bool TryRegisterBonusFormalGasAbility(
            int formalGasAbilityCode,
            CharacterAbilitySourceKey source,
            Func<int, AbilityBase> createInstance,
            int count = 1,
            Action<int> onAdded = null)
        {
            if (formalGasAbilityCode <= 0 || count <= 0 || createInstance == null)
            {
                return false;
            }

            RuntimeAbilityKey key = RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode);
            bool requiresNewInstance = !m_instances.ContainsKey(key);

            if (!m_bonusAbilitySources.TryGetValue(key, out Dictionary<CharacterAbilitySourceKey, int> sources))
            {
                sources = new Dictionary<CharacterAbilitySourceKey, int>();
                m_bonusAbilitySources.Add(key, sources);
            }

            sources.TryGetValue(source, out int currentCount);
            sources[source] = currentCount + count;

            if (requiresNewInstance)
            {
                AbilityBase instance = createInstance(formalGasAbilityCode);
                if (instance == null)
                {
                    sources[source] = currentCount;
                    if (sources.Count == 1 && currentCount <= 0)
                    {
                        m_bonusAbilitySources.Remove(key);
                    }

                    return false;
                }

                m_instances[key] = instance;
                onAdded?.Invoke(formalGasAbilityCode);
            }

            return requiresNewInstance;
        }

        /// <summary>
        /// 撤回指定来源的一部分临时授予层数。
        /// 返回 true 只表示该能力已经没有临时来源且也不是永久解锁，调用方应释放实例。
        /// </summary>
        public bool TryUnregisterBonusFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            if (formalGasAbilityCode <= 0 ||
                count <= 0 ||
                !m_bonusAbilitySources.TryGetValue(RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode), out Dictionary<CharacterAbilitySourceKey, int> sources) ||
                !sources.TryGetValue(source, out int currentCount))
            {
                return false;
            }

            RuntimeAbilityKey key = RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode);

            int nextCount = currentCount - count;
            if (nextCount > 0)
            {
                sources[source] = nextCount;
                return false;
            }

            sources.Remove(source);

            if (sources.Count > 0)
            {
                return false;
            }

            m_bonusAbilitySources.Remove(key);
            return !m_unlockedAbilities.Contains(key);
        }

        /// <summary>
        /// 创建指定来源当前仍授予的能力来源快照。
        /// 存档和变身/感染规则回滚用它精确记录该来源贡献的层数。
        /// </summary>
        public CharacterAbilitySourceRuntimeEntry[] CreateBonusAbilitySourceEntrySnapshot(CharacterAbilitySourceKey source)
        {
            return m_bonusAbilitySources
                .SelectMany(abilityEntry => abilityEntry.Value
                    .Where(sourceEntry => sourceEntry.Key.Equals(source))
                    .Select(sourceEntry =>
                        CreateSourceRuntimeEntry(abilityEntry.Key, sourceEntry.Key, sourceEntry.Value)))
                .Where(entry => entry.StackCount > 0 && entry.HasFormalGasAbility)
                .ToArray();
        }

        /// <summary>
        /// 撤回指定来源的一部分临时授予层数，并在需要时释放能力实例。
        /// 永久解锁能力不会因为临时来源退场而释放实例。
        /// </summary>
        public bool TryUnregisterBonusFormalGasAbility(
            int formalGasAbilityCode,
            CharacterAbilitySourceKey source,
            int count,
            Action<AbilityBase> releaseInstance,
            Action<int> onRemoved = null)
        {
            bool shouldRemoveInstance = TryUnregisterBonusFormalGasAbility(formalGasAbilityCode, source, count);
            RuntimeAbilityKey key = RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode);

            if (shouldRemoveInstance &&
                m_instances.TryGetValue(key, out AbilityBase instance))
            {
                m_instances.Remove(key);
                m_suppressedAbilitySources.Remove(key);

                releaseInstance?.Invoke(instance);
                onRemoved?.Invoke(formalGasAbilityCode);
            }

            return shouldRemoveInstance;
        }

        /// <summary>
        /// 从指定来源压制一个正式能力。
        /// 返回 true 表示该能力从未压制变为已压制，适合上层刷新 UI 或打断入口。
        /// </summary>
        public bool TrySuppressFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            if (formalGasAbilityCode <= 0 || count <= 0)
            {
                return false;
            }

            RuntimeAbilityKey key = RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode);
            bool wasSuppressed = IsAbilitySuppressed(key);

            if (!m_suppressedAbilitySources.TryGetValue(key, out Dictionary<CharacterAbilitySourceKey, int> sources))
            {
                sources = new Dictionary<CharacterAbilitySourceKey, int>();
                m_suppressedAbilitySources.Add(key, sources);
            }

            sources.TryGetValue(source, out int currentCount);
            sources[source] = currentCount + count;
            return !wasSuppressed;
        }

        /// <summary>
        /// 撤回指定来源的一部分能力压制层数。
        /// 返回 true 表示该能力已经没有任何压制来源。
        /// </summary>
        public bool TryUnsuppressFormalGasAbility(int formalGasAbilityCode, CharacterAbilitySourceKey source, int count = 1)
        {
            if (formalGasAbilityCode <= 0 ||
                count <= 0 ||
                !m_suppressedAbilitySources.TryGetValue(RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode), out Dictionary<CharacterAbilitySourceKey, int> sources) ||
                !sources.TryGetValue(source, out int currentCount))
            {
                return false;
            }

            RuntimeAbilityKey key = RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode);

            int nextCount = currentCount - count;
            if (nextCount > 0)
            {
                sources[source] = nextCount;
                return false;
            }

            sources.Remove(source);

            if (sources.Count > 0)
            {
                return false;
            }

            m_suppressedAbilitySources.Remove(key);
            return true;
        }

        /// <summary>
        /// 查询正式能力当前是否被任意来源压制。
        /// 无效能力编号直接视为未压制，避免 UI 查询时把空槽误判为异常。
        /// </summary>
        public bool IsFormalGasAbilitySuppressed(int formalGasAbilityCode)
        {
            return formalGasAbilityCode > 0 &&
                IsAbilitySuppressed(RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode));
        }

        /// <summary>
        /// 创建全部能力压制来源快照。
        /// 存档恢复只保存来源键和叠层数，不保存压制期间的 UI 临时状态。
        /// </summary>
        public CharacterAbilitySourceRuntimeEntry[] CreateSuppressedAbilitySourceEntrySnapshot()
        {
            return m_suppressedAbilitySources
                .SelectMany(abilityEntry => abilityEntry.Value.Select(sourceEntry =>
                    CreateSourceRuntimeEntry(abilityEntry.Key, sourceEntry.Key, sourceEntry.Value)))
                .Where(entry => entry.StackCount > 0 && entry.HasFormalGasAbility)
                .ToArray();
        }

        /// <summary>
        /// 创建指定来源的能力压制快照。
        /// 用于撤回装备、状态效果或变身时只处理该来源贡献的压制层数。
        /// </summary>
        public CharacterAbilitySourceRuntimeEntry[] CreateSuppressedAbilitySourceEntrySnapshot(CharacterAbilitySourceKey source)
        {
            return m_suppressedAbilitySources
                .SelectMany(abilityEntry => abilityEntry.Value
                    .Where(sourceEntry => sourceEntry.Key.Equals(source))
                    .Select(sourceEntry =>
                        CreateSourceRuntimeEntry(abilityEntry.Key, sourceEntry.Key, sourceEntry.Value)))
                .Where(entry => entry.StackCount > 0 && entry.HasFormalGasAbility)
                .ToArray();
        }

        /// <summary>
        /// 创建全部临时授予能力来源快照。
        /// 这份快照只描述来源关系，不替代能力实例自己的冷却和 extra state 存档。
        /// </summary>
        public CharacterAbilitySourceRuntimeEntry[] CreateBonusAbilitySourceEntrySnapshot()
        {
            return m_bonusAbilitySources
                .SelectMany(abilityEntry => abilityEntry.Value.Select(sourceEntry =>
                    CreateSourceRuntimeEntry(abilityEntry.Key, sourceEntry.Key, sourceEntry.Value)))
                .Where(entry => entry.StackCount > 0 && entry.HasFormalGasAbility)
                .ToArray();
        }

        /// <summary>
        /// 使用当前 Unity 帧时间推进所有能力实例的冷却和动画状态。
        /// </summary>
        public void UpdateRuntime()
        {
            UpdateRuntime(Time.deltaTime);
        }

        /// <summary>
        /// 推进所有存活能力实例的轻量运行时状态。
        /// 容器只转发统一 tick，不在这里决定能力是否能释放。
        /// </summary>
        public void UpdateRuntime(float deltaTime)
        {
            foreach (AbilityBase ability in m_instances.Values)
            {
                ability.UpdateCooldowns(deltaTime);
                ability.UpdateAnimationState();
            }
        }

        /// <summary>
        /// 重置所有能力实例的内部状态。
        /// 角色复活、读档或全局清理时使用，能力来源集合本身不在这里被清空。
        /// </summary>
        public void ResetInstances()
        {
            foreach (AbilityBase ability in m_instances.Values)
            {
                ability.Reset();
            }
        }

        /// <summary>
        /// 打断所有能力实例当前执行。
        /// 这只通知已有实例，能力是否继续保留由来源集合和实例释放规则决定。
        /// </summary>
        public void InterruptInstances()
        {
            foreach (AbilityBase ability in m_instances.Values)
            {
                ability.Interrupt();
            }
        }

        /// <summary>
        /// 这里只通知显式声明了动作中断合同的能力实例，
        /// 不再让 CharacterBase 自己遍历实例集合并判断具体实现类型。
        /// </summary>
        public void NotifyActionInterrupted()
        {
            foreach (AbilityBase ability in m_instances.Values)
            {
                if (ability is IActionInterruptReceiver interruptReceiver)
                {
                    interruptReceiver.OnActionInterrupted();
                }
            }
        }

        /// <summary>
        /// 查询角色当前是否拥有某个正式能力实例。
        /// 被压制的能力仍然可能拥有实例，因此释放前还要另查压制状态。
        /// </summary>
        public bool HasFormalGasAbility(int formalGasAbilityCode)
        {
            return formalGasAbilityCode > 0 &&
                m_instances.ContainsKey(RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode));
        }

        /// <summary>
        /// 获取正式能力实例。
        /// 返回 false 表示能力编号无效、实例不存在，或实例已经被释放。
        /// </summary>
        public bool TryGetFormalGasAbilityInstance(int formalGasAbilityCode, out AbilityBase instance)
        {
            instance = null;

            if (formalGasAbilityCode <= 0)
            {
                return false;
            }

            return m_instances.TryGetValue(RuntimeAbilityKey.FromFormalGasAbilityCode(formalGasAbilityCode), out instance) &&
                instance != null;
        }

        /// <summary>
        /// 创建正式能力编号和实例的快照。
        /// 调用方可安全遍历这份数组，不会被容器后续增删实例影响枚举器。
        /// </summary>
        public KeyValuePair<int, AbilityBase>[] GetFormalGasAbilityInstanceEntriesSnapshot()
        {
            return m_instances
                .Where(entry => entry.Key.HasFormalGasAbility)
                .Select(entry => new KeyValuePair<int, AbilityBase>(entry.Key.FormalGasAbilityCode, entry.Value))
                .Where(entry => entry.Value != null)
                .ToArray();
        }

        /// <summary>
        /// 创建当前所有正式能力编号快照。
        /// 主要给存档、菜单和调试展示使用，不暴露内部 RuntimeAbilityKey。
        /// </summary>
        public int[] GetFormalGasAbilityCodeSnapshots()
        {
            return m_instances.Keys
                .Where(key => key.HasFormalGasAbility)
                .Select(key => key.FormalGasAbilityCode)
                .Distinct()
                .ToArray();
        }

        /// <summary>
        /// 判断某个能力键是否还有有效压制层数。
        /// 这里按所有来源层数求和，任何正数层数都会让能力保持压制状态。
        /// </summary>
        private bool IsAbilitySuppressed(RuntimeAbilityKey key)
        {
            return m_suppressedAbilitySources.TryGetValue(key, out Dictionary<CharacterAbilitySourceKey, int> sources) &&
                sources.Values.Sum() > 0;
        }

        /// <summary>
        /// 把内部能力键和来源叠层转换成可存档的运行时来源条目。
        /// </summary>
        private CharacterAbilitySourceRuntimeEntry CreateSourceRuntimeEntry(
            RuntimeAbilityKey key,
            CharacterAbilitySourceKey source,
            int stackCount)
        {
            return new CharacterAbilitySourceRuntimeEntry(
                key.FormalGasAbilityCode,
                source,
                stackCount);
        }

        /// <summary>
        /// 能力容器内部使用的稳定键。
        /// 目前只承载正式 EX-GAS 能力编号，保留结构体是为了后续扩展其它能力来源时不改外层字典形状。
        /// </summary>
        private readonly struct RuntimeAbilityKey : IEquatable<RuntimeAbilityKey>
        {
            private RuntimeAbilityKey(int formalGasAbilityCode)
            {
                FormalGasAbilityCode = Math.Max(0, formalGasAbilityCode);
            }

            public int FormalGasAbilityCode { get; }
            public bool HasFormalGasAbility => FormalGasAbilityCode > 0;

            public static RuntimeAbilityKey FromFormalGasAbilityCode(int formalGasAbilityCode)
            {
                return new RuntimeAbilityKey(formalGasAbilityCode);
            }

            public bool Equals(RuntimeAbilityKey other)
            {
                return FormalGasAbilityCode == other.FormalGasAbilityCode;
            }

            public override bool Equals(object obj)
            {
                return obj is RuntimeAbilityKey other && Equals(other);
            }

            public override int GetHashCode()
            {
                return HashCode.Combine(nameof(RuntimeAbilityKey), FormalGasAbilityCode);
            }
        }
    }
}
