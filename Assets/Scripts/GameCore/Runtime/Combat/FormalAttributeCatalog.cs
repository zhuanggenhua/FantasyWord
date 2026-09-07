using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Reflection;
using GAS.Runtime;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 项目正式属性元数据。
    /// 稳定 ID 和中文名服务 UI、装备与存档语义；属性 code 绑定到 EX-GAS 生成常量，
    /// 不在这里另起一套属性数字真相。
    /// </summary>
    public readonly struct FormalAttributeDefinition
    {
        public FormalAttributeDefinition(EStat stat, string stableId, string displayName, bool isResource, bool supportsCurrentValue)
        {
            Stat = stat;
            StableId = stableId ?? throw new ArgumentNullException(nameof(stableId));
            DisplayName = displayName ?? throw new ArgumentNullException(nameof(displayName));
            IsResource = isResource;
            SupportsCurrentValue = supportsCurrentValue;
            AttributeCode = FormalAttributeCatalog.ResolveCurrentAttributeCode(stat);
            BaseAttributeCode = isResource
                ? FormalAttributeCatalog.ResolveBaseResourceAttributeCode(stat)
                : AttributeCode;
        }

        public EStat Stat { get; }

        public string StableId { get; }

        public string DisplayName { get; }

        public bool IsResource { get; }

        public bool SupportsCurrentValue { get; }

        public int AttributeCode { get; }

        public int BaseAttributeCode { get; }

        public int Index => (int)Stat;
    }

    /// <summary>
    /// 正式属性元数据目录。
    /// 目录只保存项目侧展示和稳定 ID 绑定；属性 code 来自 EX-GAS 生成源。
    /// </summary>
    public static class FormalAttributeCatalog
    {
        private const int DefaultStamina = 100;
        private const int DefaultMaxStamina = 100;

        private static readonly FormalAttributeDefinition[] s_definitionArray =
        {
            new(EStat.Health, "core.health", "生命", isResource: true, supportsCurrentValue: true),
            new(EStat.Mana, "core.mana", "法力", isResource: true, supportsCurrentValue: true),
            new(EStat.PhysicalAttack, "core.physical_attack", "物攻", isResource: false, supportsCurrentValue: true),
            new(EStat.MagicalAttack, "core.magical_attack", "法攻", isResource: false, supportsCurrentValue: true),
            new(EStat.PhysicalDefense, "core.physical_defense", "物防", isResource: false, supportsCurrentValue: true),
            new(EStat.MagicalDefense, "core.magical_defense", "法防", isResource: false, supportsCurrentValue: true),
            new(EStat.Agility, "core.agility", "敏捷", isResource: false, supportsCurrentValue: true),
            new(EStat.Luck, "core.luck", "幸运", isResource: false, supportsCurrentValue: true),
            new(EStat.AttackSpeed, "core.attack_speed", "攻速", isResource: false, supportsCurrentValue: true)
        };
        private static readonly ReadOnlyCollection<FormalAttributeDefinition> s_definitions = Array.AsReadOnly(s_definitionArray);

        static FormalAttributeCatalog()
        {
            Array enumValues = Enum.GetValues(typeof(EStat));
            if (enumValues.Length != s_definitionArray.Length)
            {
                throw new InvalidOperationException(
                    $"正式属性目录数量 {s_definitionArray.Length} 与 {nameof(EStat)} 枚举数量 {enumValues.Length} 不一致。");
            }

            HashSet<string> stableIds = new(StringComparer.Ordinal);
            for (int i = 0; i < s_definitionArray.Length; i++)
            {
                FormalAttributeDefinition definition = s_definitionArray[i];
                if (definition.Index != i)
                {
                    throw new InvalidOperationException(
                        $"正式属性目录顺序错误：索引 {i} 对应的是 {definition.Stat}。目录顺序必须与 {nameof(EStat)} 一致。");
                }

                if (string.IsNullOrWhiteSpace(definition.StableId))
                {
                    throw new InvalidOperationException($"正式属性 {definition.Stat} 缺少稳定 ID。");
                }

                if (!stableIds.Add(definition.StableId))
                {
                    throw new InvalidOperationException($"正式属性稳定 ID 重复：{definition.StableId}");
                }

                if (definition.AttributeCode <= 0)
                {
                    throw new InvalidOperationException($"正式属性 {definition.Stat} 未绑定有效 EX-GAS attribute code。");
                }

                if (definition.BaseAttributeCode <= 0)
                {
                    throw new InvalidOperationException($"正式属性 {definition.Stat} 未绑定有效 EX-GAS base attribute code。");
                }

                if (definition.IsResource && definition.BaseAttributeCode == definition.AttributeCode)
                {
                    throw new InvalidOperationException($"资源属性 {definition.Stat} 必须绑定独立的当前值和上限属性。");
                }
            }
        }

        public static IReadOnlyList<FormalAttributeDefinition> Definitions => s_definitions;

        public static int Count => s_definitions.Count;

        public static int AttributeSetCode => GeneratedAttributeCodes.FightUnit;

        public static FormalAttributeDefinition Get(EStat stat) => s_definitionArray[(int)stat];

        public static FormalAttributeDefinition Get(int index) => s_definitionArray[index];

        public static AttrSetConfig CreateAttributeSetConfig(Stats baseStats)
        {
            Stats safeBaseStats = baseStats ?? new Stats();
            return new AttrSetConfig(
                AttributeSetCode,
                new[]
                {
                    CreateResourceSetting(GetCurrentAttributeCode(EStat.Health), safeBaseStats[EStat.Health]),
                    CreateResourceSetting(GetCurrentAttributeCode(EStat.Mana), safeBaseStats[EStat.Mana]),
                    CreateRegularSetting(GetCurrentAttributeCode(EStat.Agility), safeBaseStats[EStat.Agility]),
                    CreateRegularSetting(GetCurrentAttributeCode(EStat.PhysicalAttack), safeBaseStats[EStat.PhysicalAttack]),
                    CreateRegularSetting(GetCurrentAttributeCode(EStat.PhysicalDefense), safeBaseStats[EStat.PhysicalDefense]),
                    CreateResourceSetting(GeneratedAttributeCodes.Stamina, DefaultStamina),
                    CreateResourceSetting(GetBaseAttributeCode(EStat.Health), safeBaseStats[EStat.Health]),
                    CreateResourceSetting(GetBaseAttributeCode(EStat.Mana), safeBaseStats[EStat.Mana]),
                    CreateResourceSetting(GeneratedAttributeCodes.MaxStamina, DefaultMaxStamina),
                    CreateRegularSetting(GetCurrentAttributeCode(EStat.MagicalAttack), safeBaseStats[EStat.MagicalAttack]),
                    CreateRegularSetting(GetCurrentAttributeCode(EStat.MagicalDefense), safeBaseStats[EStat.MagicalDefense]),
                    CreateRegularSetting(GetCurrentAttributeCode(EStat.Luck), safeBaseStats[EStat.Luck]),
                    CreateRegularSetting(GetCurrentAttributeCode(EStat.AttackSpeed), safeBaseStats[EStat.AttackSpeed]),
                });
        }

        public static int GetCurrentAttributeCode(EStat stat) => Get(stat).AttributeCode;

        public static int GetBaseAttributeCode(EStat stat) => Get(stat).BaseAttributeCode;

        public static bool IsResourceStat(EStat stat) => Get(stat).IsResource;

        public static bool TryGetByStableId(string stableId, out FormalAttributeDefinition definition)
        {
            if (!string.IsNullOrWhiteSpace(stableId))
            {
                for (int i = 0; i < s_definitionArray.Length; i++)
                {
                    if (string.Equals(s_definitionArray[i].StableId, stableId, StringComparison.Ordinal))
                    {
                        definition = s_definitionArray[i];
                        return true;
                    }
                }
            }

            definition = default;
            return false;
        }

        internal static int ResolveCurrentAttributeCode(EStat stat)
        {
            return GeneratedAttributeCodes.ResolveFightUnitAttributeCode(stat.ToString());
        }

        internal static int ResolveBaseResourceAttributeCode(EStat stat)
        {
            if (!IsKnownResourceStat(stat))
            {
                return ResolveCurrentAttributeCode(stat);
            }

            return GeneratedAttributeCodes.ResolveFightUnitAttributeCode($"Max{stat}");
        }

        private static bool IsKnownResourceStat(EStat stat)
        {
            return stat == EStat.Health || stat == EStat.Mana;
        }

        private static AttributeBaseSetting CreateRegularSetting(int attributeCode, int initialValue)
        {
            return new AttributeBaseSetting(
                attributeCode,
                initialValue,
                isClampMin: false,
                isClampMax: false,
                min: 0.0f,
                max: 0.0f);
        }

        private static AttributeBaseSetting CreateResourceSetting(int attributeCode, int initialValue)
        {
            return new AttributeBaseSetting(
                attributeCode,
                initialValue,
                isClampMin: true,
                isClampMax: false,
                min: 0.0f,
                max: 0.0f);
        }

        private static class GeneratedAttributeCodes
        {
            private const string AttrSetTypeName = "GAS.Runtime.XAttrSet";
            private const string FightUnitTypeName = "GAS.Runtime.XAttrSet+AS_FightUnit";

            public static readonly int FightUnit = ResolveGeneratedInt(AttrSetTypeName, "FightUnit");
            public static readonly int Stamina = ResolveFightUnitAttributeCode("Stamina");
            public static readonly int MaxStamina = ResolveFightUnitAttributeCode("MaxStamina");

            // 生成程序集当前反向依赖 GameCore 的项目 GAS 扩展。这里用一次性反射读取生成常量，
            // 避免在 asmdef 层制造循环依赖；EditMode 合同测试负责校验这层桥接没有漂移。
            public static int ResolveFightUnitAttributeCode(string attributeName)
            {
                return ResolveGeneratedInt(FightUnitTypeName, attributeName);
            }

            private static int ResolveGeneratedInt(string typeName, string fieldName)
            {
                Type type = ResolveGeneratedType(typeName);
                FieldInfo field = type.GetField(fieldName, BindingFlags.Public | BindingFlags.Static);
                if (field == null || field.FieldType != typeof(int))
                {
                    throw new InvalidOperationException(
                        $"EX-GAS 生成属性常量缺失：{typeName}.{fieldName}。请先从 EX-GAS Attribute / AttributeSet 源表重新生成常量。");
                }

                object rawValue = field.GetRawConstantValue() ?? field.GetValue(null);
                return rawValue is int intValue
                    ? intValue
                    : throw new InvalidOperationException($"EX-GAS 生成属性常量不是 int：{typeName}.{fieldName}。");
            }

            private static Type ResolveGeneratedType(string typeName)
            {
                foreach (Assembly assembly in AppDomain.CurrentDomain.GetAssemblies())
                {
                    Type type = assembly.GetType(typeName, throwOnError: false);
                    if (type != null)
                    {
                        return type;
                    }
                }

                throw new InvalidOperationException(
                    $"未找到 EX-GAS 生成类型 {typeName}。GameCore 不直接引用生成程序集，以避免当前生成程序集反向依赖 GameCore 时形成程序集循环。");
            }
        }
    }
}
