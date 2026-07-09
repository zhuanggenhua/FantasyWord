using System;
using System.Collections.Generic;
using UnityEngine;
using azixMcAze.SerializableDictionary;

namespace FantasyWord.GameCore
{
    [Serializable]
    public class PerTargetCooldownDataBlock<TargetType> : DataBlock where TargetType : Persistable
    {
        public SerializableDictionary<PersistableReference<TargetType>, float> perTargetCooldowns = new();
    }

    public class PerTargetCooldown<TargetType> : IDataBlockHandler<PerTargetCooldownDataBlock<TargetType>> where TargetType : Persistable
    {
        private Dictionary<TargetType, float> m_perTargetCooldowns = new();

        public TargetType[] CreateValidTargetSnapshot(IEnumerable<TargetType> potentialTargets)
        {
            if (potentialTargets == null)
            {
                return Array.Empty<TargetType>();
            }

            List<TargetType> validTargets = new();
            foreach (TargetType target in potentialTargets)
            {
                if (CanTrackTarget(target) && !IsTargetOnCooldown(target))
                {
                    validTargets.Add(target);
                }
            }

            return validTargets.ToArray();
        }

        public bool IsTargetOnCooldown(TargetType target) => CanTrackTarget(target) && m_perTargetCooldowns.ContainsKey(target);

        public void StartCooldown(TargetType target, float duration)
        {
            if (CanTrackTarget(target) && duration > 0.0f)
            {
                m_perTargetCooldowns[target] = duration;
            }
        }

        public void Reset()
        {
            m_perTargetCooldowns.Clear();
        }

        public void Update() => Update(Time.deltaTime);

        public void Update(float deltaTime)
        {
            foreach (var key in new HashSet<TargetType>(m_perTargetCooldowns.Keys))
            {
                if (!CanTrackTarget(key))
                {
                    m_perTargetCooldowns.Remove(key);
                    continue;
                }

                m_perTargetCooldowns[key] -= Mathf.Max(0.0f, deltaTime);
                if (m_perTargetCooldowns[key] <= 0.0f)
                {
                    m_perTargetCooldowns.Remove(key);
                }
            }
        }

        public PerTargetCooldownDataBlock<TargetType> CreateDataBlock()
        {
            SerializableDictionary<PersistableReference<TargetType>, float> cooldowns = new();
            foreach (KeyValuePair<TargetType, float> pair in m_perTargetCooldowns)
            {
                if (!CanTrackTarget(pair.Key) || pair.Value <= 0.0f)
                {
                    continue;
                }

                cooldowns[new PersistableReference<TargetType>(pair.Key)] = pair.Value;
            }

            return new PerTargetCooldownDataBlock<TargetType>
            {
                perTargetCooldowns = cooldowns
            };
        }

        public void LoadDataBlock(PerTargetCooldownDataBlock<TargetType> block)
        {
            m_perTargetCooldowns.Clear();
            if (block?.perTargetCooldowns == null)
            {
                return;
            }

            foreach (KeyValuePair<PersistableReference<TargetType>, float> pair in block.perTargetCooldowns)
            {
                TargetType target = pair.Key.ResolveOrNull();
                if (!CanTrackTarget(target) || pair.Value <= 0.0f)
                {
                    continue;
                }

                // 冷却快照只保存仍存在的目标，避免读档后把已销毁对象重新当成命中事实。
                m_perTargetCooldowns[target] = pair.Value;
            }
        }

        private static bool CanTrackTarget(TargetType target)
        {
            return target != null && !target.isMarkedAsDestroyed;
        }
    }
}

