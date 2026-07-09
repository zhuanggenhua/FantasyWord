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
        /// </summary>
        private bool IsCurrentOwnedTemporalEffect(ITemporalEffect effect)
        {
            return effect != null &&
                effect.runtimeKey > 0 &&
                m_temporalEffectsByRuntimeKey.TryGetValue(effect.runtimeKey, out ITemporalEffect registeredEffect) &&
                registeredEffect != null &&
                ReferenceEquals(registeredEffect, effect);
        }

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
