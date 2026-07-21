using System;
using System.Collections.Generic;
using System.Linq;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        /// <summary>
        /// 角色动作状态内部容器。
        /// 这里只服务 CharacterBase 自己的动作启用位、动作锁和移动速度修饰，
        /// 不对外升格成独立角色宿主或第二套动作系统。
        /// </summary>
        private sealed class CharacterActionStateRuntime
        {
            // 当前启用的动作位。禁用动作位和动作锁是两层门禁，Can 会同时检查。
            private EActionFlags m_actionFlags = EActionFlags.All;

            // 普通动作锁按随机 key 管理，key 由调用方保存并用于解锁。
            private readonly Dictionary<string, EActionFlags> m_lockedActions = new();

            // 来源化动作锁按能力来源管理，适合状态效果、变形、感染等可叠加规则。
            private readonly Dictionary<CharacterAbilitySourceKey, CharacterActionLockRuntimeEntry> m_alterationRuleActionLocks = new();

            // 普通移速倍率按随机 key 管理，适合装备、地形或临时外部规则。
            private readonly Dictionary<string, float> m_moveSpeedFactors = new();

            // 持续效果动作锁按 effect runtimeKey 管理，读档恢复时能和 effect 实例一一对应。
            private readonly Dictionary<int, EActionFlags> m_temporalEffectActionLocks = new();

            // 持续效果移速倍率按 effect runtimeKey 管理，避免 effect 自己保存不透明句柄。
            private readonly Dictionary<int, float> m_temporalEffectMoveSpeedFactors = new();

            /// <summary>
            /// 来源化动作锁运行时条目。
            /// Actions 保存该来源锁住的动作位，StackCount 保存来源叠层数量。
            /// </summary>
            private readonly struct CharacterActionLockRuntimeEntry
            {
                public CharacterActionLockRuntimeEntry(EActionFlags actions, int stackCount)
                {
                    Actions = actions;
                    StackCount = stackCount;
                }

                public EActionFlags Actions { get; }
                public int StackCount { get; }
            }

            /// <summary>
            /// 创建当前所有移速倍率快照。
            /// 调用方只拿数值列表，不拿内部 key，避免外部误改锁表。
            /// </summary>
            public float[] CreateMoveSpeedFactorSnapshot()
            {
                return m_moveSpeedFactors.Values
                    .Concat(m_temporalEffectMoveSpeedFactors.Values)
                    .ToArray();
            }

            /// <summary>
            /// 添加普通移速倍率，返回后续更新或移除使用的 key。
            /// </summary>
            public string ApplyMoveSpeedFactor(float factor)
            {
                string key = Guid.NewGuid().ToString();
                m_moveSpeedFactors[key] = factor;
                return key;
            }

            /// <summary>
            /// 更新普通移速倍率。
            /// key 不存在时直接抛错，暴露调用方生命周期管理错误。
            /// </summary>
            public void UpdateMoveSpeedFactor(string key, float factor)
            {
                if (!m_moveSpeedFactors.ContainsKey(key))
                {
                    throw new InvalidOperationException("Invalid key, no move speed factor is applied with this key.");
                }

                m_moveSpeedFactors[key] = factor;
            }

            /// <summary>
            /// 移除普通移速倍率。
            /// key 不存在时抛错，避免静默吞掉重复释放。
            /// </summary>
            public void RemoveMoveSpeedFactor(string key)
            {
                if (!m_moveSpeedFactors.ContainsKey(key))
                {
                    throw new InvalidOperationException("Invalid key, no move speed factor is applied with this key.");
                }

                m_moveSpeedFactors.Remove(key);
            }

            /// <summary>
            /// 应用持续效果派生的移速倍率。
            /// runtimeKey 必须是正数稳定 key，保证可存档和可回滚。
            /// </summary>
            public void ApplyTemporalEffectMoveSpeedFactor(int runtimeKey, float factor)
            {
                EnsureValidTemporalEffectRuntimeKey(runtimeKey);
                m_temporalEffectMoveSpeedFactors[runtimeKey] = factor;
            }

            /// <summary>
            /// 更新持续效果派生的移速倍率。
            /// 不存在对应 runtimeKey 时抛错，提示 effect 注册/恢复顺序有问题。
            /// </summary>
            public void UpdateTemporalEffectMoveSpeedFactor(int runtimeKey, float factor)
            {
                EnsureValidTemporalEffectRuntimeKey(runtimeKey);
                if (!m_temporalEffectMoveSpeedFactors.ContainsKey(runtimeKey))
                {
                    throw new InvalidOperationException("Invalid runtimeKey, no temporal-effect move speed factor is applied with this runtimeKey.");
                }

                m_temporalEffectMoveSpeedFactors[runtimeKey] = factor;
            }

            /// <summary>
            /// 移除持续效果派生的移速倍率。
            /// </summary>
            public void RemoveTemporalEffectMoveSpeedFactor(int runtimeKey)
            {
                EnsureValidTemporalEffectRuntimeKey(runtimeKey);
                if (!m_temporalEffectMoveSpeedFactors.ContainsKey(runtimeKey))
                {
                    throw new InvalidOperationException("Invalid runtimeKey, no temporal-effect move speed factor is applied with this runtimeKey.");
                }

                m_temporalEffectMoveSpeedFactors.Remove(runtimeKey);
            }

            /// <summary>
            /// 添加普通动作锁并返回解锁 key。
            /// </summary>
            public string LockActions(EActionFlags actions)
            {
                string key = Guid.NewGuid().ToString();
                m_lockedActions[key] = actions;
                return key;
            }

            /// <summary>
            /// 使用 key 解除普通动作锁。
            /// key 不存在时抛错，避免动作锁泄漏或重复释放被吞掉。
            /// </summary>
            public void UnlockActions(string key)
            {
                if (!m_lockedActions.ContainsKey(key))
                {
                    throw new InvalidOperationException("Invalid key, no actions are locked with this key.");
                }

                m_lockedActions.Remove(key);
            }

            /// <summary>
            /// 应用来源化动作锁。
            /// 同一来源重复应用会合并动作位并增加叠层数。
            /// </summary>
            public void ApplyAlterationRuleActionLock(CharacterAbilitySourceKey source, EActionFlags actions)
            {
                if (actions == EActionFlags.None)
                {
                    return;
                }

                m_alterationRuleActionLocks.TryGetValue(source, out CharacterActionLockRuntimeEntry currentEntry);
                EActionFlags nextActions = currentEntry.Actions | actions;
                int nextStackCount = currentEntry.StackCount + 1;
                m_alterationRuleActionLocks[source] = new CharacterActionLockRuntimeEntry(nextActions, nextStackCount);
            }

            /// <summary>
            /// 移除来源化动作锁的一层叠层。
            /// 叠层归零后才删除该来源条目。
            /// </summary>
            public void RemoveAlterationRuleActionLockStack(CharacterAbilitySourceKey source)
            {
                if (!m_alterationRuleActionLocks.TryGetValue(source, out CharacterActionLockRuntimeEntry currentEntry))
                {
                    return;
                }

                int nextStackCount = currentEntry.StackCount - 1;
                if (nextStackCount <= 0)
                {
                    m_alterationRuleActionLocks.Remove(source);
                    return;
                }

                m_alterationRuleActionLocks[source] = new CharacterActionLockRuntimeEntry(currentEntry.Actions, nextStackCount);
            }

            /// <summary>
            /// 移除某个来源的所有动作锁。
            /// </summary>
            public void RemoveAllAlterationRuleActionLocks(CharacterAbilitySourceKey source)
            {
                m_alterationRuleActionLocks.Remove(source);
            }

            /// <summary>
            /// 清空全部来源化动作锁。
            /// 主要用于读档、角色重置或对象复用前清理旧规则。
            /// </summary>
            public void ClearAlterationRuleActionLocks()
            {
                m_alterationRuleActionLocks.Clear();
            }

            /// <summary>
            /// 应用持续效果派生的动作锁。
            /// 同一 runtimeKey 后写会覆盖前写，表示该 effect 当前最新动作锁状态。
            /// </summary>
            public void ApplyTemporalEffectActionLock(int runtimeKey, EActionFlags actions)
            {
                EnsureValidTemporalEffectRuntimeKey(runtimeKey);
                m_temporalEffectActionLocks[runtimeKey] = actions;
            }

            /// <summary>
            /// 移除持续效果派生的动作锁。
            /// </summary>
            public void RemoveTemporalEffectActionLock(int runtimeKey)
            {
                EnsureValidTemporalEffectRuntimeKey(runtimeKey);
                if (!m_temporalEffectActionLocks.ContainsKey(runtimeKey))
                {
                    throw new InvalidOperationException("Invalid runtimeKey, no temporal-effect action lock is applied with this runtimeKey.");
                }

                m_temporalEffectActionLocks.Remove(runtimeKey);
            }

            /// <summary>
            /// 查询动作是否被任何锁表锁住。
            /// 普通锁、来源化锁和持续效果锁任意命中都会返回 true。
            /// </summary>
            public bool IsActionLocked(EActionFlags actions)
            {
                foreach (EActionFlags lockedActions in m_lockedActions.Values)
                {
                    if (lockedActions.HasFlag(actions))
                    {
                        return true;
                    }
                }

                foreach (CharacterActionLockRuntimeEntry entry in m_alterationRuleActionLocks.Values)
                {
                    if (entry.Actions.HasFlag(actions))
                    {
                        return true;
                    }
                }

                foreach (EActionFlags lockedActions in m_temporalEffectActionLocks.Values)
                {
                    if (lockedActions.HasFlag(actions))
                    {
                        return true;
                    }
                }

                return false;
            }

            /// <summary>
            /// 启用指定动作位。
            /// </summary>
            public void EnableActions(EActionFlags actions)
            {
                m_actionFlags |= actions;
            }

            /// <summary>
            /// 禁用指定动作位。
            /// </summary>
            public void DisableActions(EActionFlags actions)
            {
                m_actionFlags &= ~actions;
            }

            /// <summary>
            /// 查询动作当前是否可执行。
            /// 需要动作位启用且没有命中任何动作锁。
            /// </summary>
            public bool Can(EActionFlags actions)
            {
                return m_actionFlags.HasFlag(actions) && !IsActionLocked(actions);
            }

            /// <summary>
            /// 校验持续效果 runtimeKey。
            /// runtimeKey 必须为正数，因为它承担读档恢复、状态回滚和运行时注册表匹配职责。
            /// </summary>
            private static void EnsureValidTemporalEffectRuntimeKey(int runtimeKey)
            {
                if (runtimeKey <= 0)
                {
                    throw new InvalidOperationException("Temporal effect runtimeKey must be a positive stable key.");
                }
            }
        }
    }
}
