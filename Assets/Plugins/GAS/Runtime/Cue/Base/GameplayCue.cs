using System.Linq;
using GAS.General;
using NaughtyAttributes;
using UnityEngine;

namespace GAS.Runtime
{
    public abstract class GameplayCue : ScriptableObject
    {
        protected const int WIDTH_LABEL = 70;

                                                public string Description;

#if UNITY_EDITOR
                                public string TypeName => GetType().Name;

                                public string TypeFullName => GetType().FullName;

                                public string[] InheritanceChain => GetType().GetInheritanceChain().Reverse().ToArray();
#endif
        // Tags
        [Label("RequiredTags - 持有所有标签才可触发")]
        public GameplayTag[] RequiredTags;
        [Label("ImmunityTags - 持有任意标签不可触发")]
        public GameplayTag[] ImmunityTags;

        public virtual bool Triggerable(AbilitySystemComponent owner)
        {
            if (owner == null) return false;
            // 持有【所有】RequiredTags才可触发
            if (!owner.HasAllTags(new GameplayTagSet(RequiredTags)))
                return false;

            // 持有【任意】ImmunityTags不可触发
            if (owner.HasAnyTags(new GameplayTagSet(ImmunityTags)))
                return false;

            return true;
        }
    }

    public abstract class GameplayCue<T> : GameplayCue where T : GameplayCueSpec
    {
        public abstract T CreateSpec(GameplayCueParameters parameters);
    }
}
