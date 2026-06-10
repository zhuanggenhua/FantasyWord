using System;
using System.Collections;
using System.Linq;
using GAS.General;
using NaughtyAttributes;
using UnityEngine;
using UnityEngine.Serialization;

namespace GAS.Runtime
{
    public abstract class AbilityAsset : ScriptableObject
    {
        protected const int WIDTH_LABEL = 70;

        private static IEnumerable AbilityClassChoice = new DropdownList<string>();

        public abstract Type AbilityType();

                                                public string Description;

                public string InstanceAbilityClassFullName => AbilityType() != null ? AbilityType().FullName : null;

#if UNITY_EDITOR
                                public string TypeName => GetType().Name;

                                public string TypeFullName => GetType().FullName;

                                public string[] InheritanceChain => GetType().GetInheritanceChain().Reverse().ToArray();
#endif

                [InfoBox(GASTextDefine.TIP_UNAME, EInfoBoxType.Normal)]
        [Label("U-Name")]
                [InfoBox("无效的名字 - 不符合C#标识符命名规则", EInfoBoxType.Error)]
                public string UniqueName;

                                        [Label(GASTextDefine.ABILITY_EFFECT_COST)]
        public GameplayEffectAsset Cost;

                                [Label(GASTextDefine.ABILITY_EFFECT_CD)]
        public GameplayEffectAsset Cooldown;

                        [Label(GASTextDefine.ABILITY_CD_TIME)]
                public float CooldownTime;

        // Tags
        [Tooltip("描述性质的标签，用来描述Ability的特性表现，比如伤害、治疗、控制等。")]
        [FormerlySerializedAs("AssetTag")]
        public GameplayTag[] AssetTags;
        [Label("CancelAbility With Tags ")]
        [Space]
        [Tooltip("Ability激活时，Ability持有者当前持有的所有Ability中，拥有【任意】这些标签的Ability会被取消。")]
        public GameplayTag[] CancelAbilityTags;
        [Label("BlockAbility With Tags ")]
        [Space]
        [Tooltip("Ability激活时，Ability持有者当前持有的所有Ability中，拥有【任意】这些标签的Ability会被阻塞激活。")]
        public GameplayTag[] BlockAbilityTags;
        [Space]
        [Tooltip("Ability激活时，持有者会获得这些标签，Ability被失活时，这些标签也会被移除。")]
        [FormerlySerializedAs("ActivationOwnedTag")]
        public GameplayTag[] ActivationOwnedTags;
        [Space]
        [Tooltip("Ability只有在其拥有者拥有【所有】这些标签时才可激活。")]
        public GameplayTag[] ActivationRequiredTags;
        [Space]
        [Tooltip("Ability在其拥有者拥有【任意】这些标签时不能被激活。")]
        public GameplayTag[] ActivationBlockedTags;
        // public GameplayTag[] SourceRequiredTags;
        // public GameplayTag[] SourceBlockedTags;
        // public GameplayTag[] TargetRequiredTags;
        // public GameplayTag[] TargetBlockedTags;
    }


    public abstract class AbilityAssetT<T> : AbilityAsset where T : class
    {
        public sealed override Type AbilityType()
        {
            return typeof(T);
        }
    }
}
