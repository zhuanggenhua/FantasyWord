using System.Collections.Generic;
using GAS.Runtime;
using NUnit.Framework;

namespace FantasyWord.GameCore.Tests
{
    public sealed class FormalAttributeSingleSourceEditModeTests
    {
        [Test]
        public void FormalAttributeCatalog_UsesGeneratedFightUnitCodes()
        {
            Assert.AreEqual(XAttrSet.FightUnit, FormalAttributeCatalog.AttributeSetCode);
            Assert.AreEqual(XAttribute.Health, XAttrSet.AS_FightUnit.Health);
            Assert.AreEqual(XAttribute.Mana, XAttrSet.AS_FightUnit.Mana);
            Assert.AreEqual(XAttribute.Agility, XAttrSet.AS_FightUnit.Agility);
            Assert.AreEqual(XAttribute.PhysicalAttack, XAttrSet.AS_FightUnit.PhysicalAttack);
            Assert.AreEqual(XAttribute.PhysicalDefense, XAttrSet.AS_FightUnit.PhysicalDefense);
            Assert.AreEqual(XAttribute.Stamina, XAttrSet.AS_FightUnit.Stamina);
            Assert.AreEqual(XAttribute.MaxHealth, XAttrSet.AS_FightUnit.MaxHealth);
            Assert.AreEqual(XAttribute.MaxMana, XAttrSet.AS_FightUnit.MaxMana);
            Assert.AreEqual(XAttribute.MaxStamina, XAttrSet.AS_FightUnit.MaxStamina);
            Assert.AreEqual(XAttribute.MagicalAttack, XAttrSet.AS_FightUnit.MagicalAttack);
            Assert.AreEqual(XAttribute.MagicalDefense, XAttrSet.AS_FightUnit.MagicalDefense);
            Assert.AreEqual(XAttribute.Luck, XAttrSet.AS_FightUnit.Luck);
            Assert.AreEqual(XAttribute.AttackSpeed, XAttrSet.AS_FightUnit.AttackSpeed);

            Assert.AreEqual(XAttrSet.AS_FightUnit.Health, FormalAttributeCatalog.GetCurrentAttributeCode(EStat.Health));
            Assert.AreEqual(XAttrSet.AS_FightUnit.Mana, FormalAttributeCatalog.GetCurrentAttributeCode(EStat.Mana));
            Assert.AreEqual(XAttrSet.AS_FightUnit.Agility, FormalAttributeCatalog.GetCurrentAttributeCode(EStat.Agility));
            Assert.AreEqual(XAttrSet.AS_FightUnit.PhysicalAttack, FormalAttributeCatalog.GetCurrentAttributeCode(EStat.PhysicalAttack));
            Assert.AreEqual(XAttrSet.AS_FightUnit.PhysicalDefense, FormalAttributeCatalog.GetCurrentAttributeCode(EStat.PhysicalDefense));
            Assert.AreEqual(XAttrSet.AS_FightUnit.MaxHealth, FormalAttributeCatalog.GetBaseAttributeCode(EStat.Health));
            Assert.AreEqual(XAttrSet.AS_FightUnit.MaxMana, FormalAttributeCatalog.GetBaseAttributeCode(EStat.Mana));
            Assert.AreEqual(XAttrSet.AS_FightUnit.MagicalAttack, FormalAttributeCatalog.GetCurrentAttributeCode(EStat.MagicalAttack));
            Assert.AreEqual(XAttrSet.AS_FightUnit.MagicalDefense, FormalAttributeCatalog.GetCurrentAttributeCode(EStat.MagicalDefense));
            Assert.AreEqual(XAttrSet.AS_FightUnit.Luck, FormalAttributeCatalog.GetCurrentAttributeCode(EStat.Luck));
            Assert.AreEqual(XAttrSet.AS_FightUnit.AttackSpeed, FormalAttributeCatalog.GetCurrentAttributeCode(EStat.AttackSpeed));
        }

        [Test]
        public void FormalAttributeCatalog_BindsEveryDefinitionToGeneratedAttributeCodes()
        {
            HashSet<int> currentCodes = new();
            foreach (FormalAttributeDefinition definition in FormalAttributeCatalog.Definitions)
            {
                Assert.Greater(definition.AttributeCode, 0, definition.StableId);
                Assert.Greater(definition.BaseAttributeCode, 0, definition.StableId);
                Assert.AreEqual(
                    FormalAttributeCatalog.GetCurrentAttributeCode(definition.Stat),
                    definition.AttributeCode,
                    definition.StableId);
                Assert.AreEqual(
                    FormalAttributeCatalog.GetBaseAttributeCode(definition.Stat),
                    definition.BaseAttributeCode,
                    definition.StableId);
                Assert.IsTrue(currentCodes.Add(definition.AttributeCode), definition.StableId);
            }
        }

        [Test]
        public void CreateConfig_InitializesFightUnitWithGeneratedAttributeCodes()
        {
            Stats stats = new();
            stats[EStat.Health] = 120;
            stats[EStat.Mana] = 40;
            stats[EStat.PhysicalAttack] = 11;
            stats[EStat.MagicalAttack] = 12;
            stats[EStat.PhysicalDefense] = 13;
            stats[EStat.MagicalDefense] = 14;
            stats[EStat.Agility] = 15;
            stats[EStat.Luck] = 16;
            stats[EStat.AttackSpeed] = 17;

            AttrSetConfig config = FormalAttributeCatalog.CreateAttributeSetConfig(stats);
            Dictionary<int, AttributeBaseSetting> settings = new();
            foreach (AttributeBaseSetting setting in config.Settings)
            {
                settings.Add(setting.Code, setting);
            }

            Assert.AreEqual(XAttrSet.FightUnit, config.Code);
            Assert.AreEqual(120f, settings[XAttrSet.AS_FightUnit.Health].InitValue);
            Assert.AreEqual(40f, settings[XAttrSet.AS_FightUnit.Mana].InitValue);
            Assert.AreEqual(120f, settings[XAttrSet.AS_FightUnit.MaxHealth].InitValue);
            Assert.AreEqual(40f, settings[XAttrSet.AS_FightUnit.MaxMana].InitValue);
            Assert.AreEqual(11f, settings[XAttrSet.AS_FightUnit.PhysicalAttack].InitValue);
            Assert.AreEqual(12f, settings[XAttrSet.AS_FightUnit.MagicalAttack].InitValue);
            Assert.AreEqual(13f, settings[XAttrSet.AS_FightUnit.PhysicalDefense].InitValue);
            Assert.AreEqual(14f, settings[XAttrSet.AS_FightUnit.MagicalDefense].InitValue);
            Assert.AreEqual(15f, settings[XAttrSet.AS_FightUnit.Agility].InitValue);
            Assert.AreEqual(16f, settings[XAttrSet.AS_FightUnit.Luck].InitValue);
            Assert.AreEqual(17f, settings[XAttrSet.AS_FightUnit.AttackSpeed].InitValue);
            Assert.IsTrue(settings.ContainsKey(XAttrSet.AS_FightUnit.Stamina));
            Assert.IsTrue(settings.ContainsKey(XAttrSet.AS_FightUnit.MaxStamina));
        }
    }
}
