using System;
using System.Collections.Generic;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public abstract partial class CharacterBase
    {
        /// <summary>
        /// 持续效果 live runtime 注册表。
        /// 当前只保留 runtimeKey 到 effect 实例的增删查职责，
        /// 不再额外包一层只负责转发的内部容器类型。
        /// </summary>
        private readonly SortedDictionary<int, ITemporalEffect> m_temporalEffectsByRuntimeKey = new();

        /// <summary>
        /// 注册角色拥有的持续效果。
        /// runtimeKey 是正式主键；同 key 新实例会替换旧实例，并把旧实例交给调用方完成退场。
        /// </summary>
        private ITemporalEffect RegisterOwnedTemporalEffect(ITemporalEffect effect)
        {
            if (effect == null)
            {
                return null;
            }

            if (effect.runtimeKey <= 0)
            {
                Debug.LogWarning($"Temporal effect [{effect.GetType().Name}] tried to enter the runtime registry without a valid runtimeKey.");
                return null;
            }

            if (m_temporalEffectsByRuntimeKey.TryGetValue(effect.runtimeKey, out ITemporalEffect registeredEffect))
            {
                if (ReferenceEquals(registeredEffect, effect))
                {
                    return null;
                }

                Debug.LogWarning($"Temporal effect runtimeKey [{effect.runtimeKey}] was already registered. The old runtime shell will be removed before the new one is registered.");
                m_temporalEffectsByRuntimeKey[effect.runtimeKey] = effect;
                return registeredEffect;
            }

            m_temporalEffectsByRuntimeKey[effect.runtimeKey] = effect;
            return null;
        }

        /// <summary>
        /// 按 runtimeKey 查询当前登记的持续效果。
        /// runtimeKey 无效、未登记或登记值为空时都返回 false。
        /// </summary>
        private bool TryGetOwnedTemporalEffect(int runtimeKey, out ITemporalEffect effect)
        {
            effect = null;
            if (runtimeKey <= 0)
            {
                return false;
            }

            if (m_temporalEffectsByRuntimeKey.TryGetValue(runtimeKey, out effect) && effect != null)
            {
                return true;
            }

            effect = null;
            return false;
        }

        /// <summary>
        /// 当调用方只需要当前登记的 effect 主键时，直接拿 key 快照，
        /// 避免先投影成对象数组再回查注册表。
        /// 快照会过滤掉无效 key 和空 effect，供推进、存档、清除等流程安全遍历。
        /// </summary>
        private int[] GetOwnedTemporalEffectRuntimeKeySnapshot()
        {
            if (m_temporalEffectsByRuntimeKey.Count == 0)
            {
                return Array.Empty<int>();
            }

            List<int> runtimeKeys = new(m_temporalEffectsByRuntimeKey.Count);
            foreach (KeyValuePair<int, ITemporalEffect> entry in m_temporalEffectsByRuntimeKey)
            {
                if (entry.Key <= 0 || entry.Value == null)
                {
                    continue;
                }

                runtimeKeys.Add(entry.Key);
            }

            return runtimeKeys.ToArray();
        }

        /// <summary>
        /// 某些调用方只关心“这是不是当前登记的那只 effect”，
        /// 不应该自己再把 key 查询和引用比较拼在一起。
        /// 这能防止旧 effect 被替换后仍在完成回调里误操作当前新 effect。
        /// </summary>
        private bool IsCurrentOwnedTemporalEffect(ITemporalEffect effect)
        {
            return effect != null &&
                effect.runtimeKey > 0 &&
                m_temporalEffectsByRuntimeKey.TryGetValue(effect.runtimeKey, out ITemporalEffect registeredEffect) &&
                registeredEffect != null &&
                ReferenceEquals(registeredEffect, effect);
        }

        /// <summary>
        /// 按 runtimeKey 快照移除持续效果。
        /// 输入可以包含重复 key；方法会去重并返回实际移除的 effect 实例，由调用方统一 Finalize。
        /// </summary>
        private ITemporalEffect[] RemoveOwnedTemporalEffectsByRuntimeKeySnapshot(int[] runtimeKeys)
        {
            if (runtimeKeys == null)
            {
                return Array.Empty<ITemporalEffect>();
            }

            List<ITemporalEffect> removedEffects = new();
            HashSet<int> seenRuntimeKeys = new();
            foreach (int runtimeKey in runtimeKeys)
            {
                if (runtimeKey <= 0 ||
                    !seenRuntimeKeys.Add(runtimeKey) ||
                    !m_temporalEffectsByRuntimeKey.TryGetValue(runtimeKey, out ITemporalEffect effect) ||
                    effect == null)
                {
                    continue;
                }

                m_temporalEffectsByRuntimeKey.Remove(runtimeKey);
                removedEffects.Add(effect);
            }

            return removedEffects.ToArray();
        }

    }
}
