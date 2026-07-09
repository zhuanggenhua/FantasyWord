#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using azixMcAze.SerializableDictionary;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// CharacterEquipment 正式运行态 smoke。
    /// 只验证当前 change 的设备边界：独立装备、装备授予能力、装备压制可逆、非 Hero 尸体转移。
    /// </summary>
    public static class CharacterEquipmentRuntimeSmokeValidator
    {
        private const string ResultRelativePath = "Temp/UnityBridge/results/character-equipment-runtime-smoke.json";
        private const string HeroPrefabPath = "Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab";
        private const string BaseCharacterPrefabPath = "Assets/Prefabs/Entities/Characters/0_Character_Base.prefab";
        private const string SmokeNpcSheetAssetPath = "Assets/Editor/GameCore/Bridge/CharacterEquipmentRuntimeSmoke_NPCSheet.asset";
        private const string SmokeHeadEquipmentAssetPath = "Assets/Editor/GameCore/Bridge/CharacterEquipmentRuntimeSmoke_Head.asset";
        private const string SmokeAbilityEquipmentAssetPath = "Assets/Editor/GameCore/Bridge/CharacterEquipmentRuntimeSmoke_TorsoAbility.asset";
        private const string SmokeSuppressionSourceId = "character-equipment-runtime-smoke-suppression";
        private const int SmokeEquipmentAbilityCode = FormalGasAbilityCodes.BasicAttack;

        private static NPC? s_characterAlpha;
        private static NPC? s_characterBeta;
        private static NPC? s_nonHeroNpc;
        private static NPCSheet? s_smokeNpcSheet;
        private static Equipment? s_smokeHeadEquipment;
        private static Equipment? s_smokeAbilityEquipment;
        private static bool s_registeredHeadEquipment;
        private static bool s_registeredAbilityEquipment;

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);

        public static StartResult Start()
        {
            ValidationResult result;
            if (!Application.isPlaying)
            {
                result = Fail("CharacterEquipment runtime smoke 只能在 PlayMode 下启动。");
                WriteResult(result);
                return new StartResult { ResultPath = ResultPath };
            }

            result = new ValidationResult
            {
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                ScreenSize = $"{Screen.width}x{Screen.height}",
            };

            try
            {
                RunValidation(result);
                FinalizeResult(result);
            }
            catch (Exception exception)
            {
                result.Completed = true;
                result.Success = false;
                result.Message = exception.ToString();
                result.Failures = new[] { exception.ToString() };
            }
            finally
            {
                CleanupRuntimeArtifacts();
                WriteResult(result);
            }

            return new StartResult { ResultPath = ResultPath };
        }

        private static void RunValidation(ValidationResult result)
        {
            result.GameManagerExists = GameManager.Exists();
            result.HasInventorySystem = result.GameManagerExists && GameManager.HasSystem<InventorySystem>();
            result.HasPersistenceSystem = result.GameManagerExists && GameManager.HasSystem<PersistenceSystem>();
            if (!result.GameManagerExists || !result.HasInventorySystem || !result.HasPersistenceSystem)
            {
                throw new InvalidOperationException("GameManager / InventorySystem / PersistenceSystem 未完整启动。");
            }

            result.HeroPrefabFound = AssetDatabase.LoadAssetAtPath<GameObject>(HeroPrefabPath) != null;
            result.BaseCharacterPrefabFound = AssetDatabase.LoadAssetAtPath<GameObject>(BaseCharacterPrefabPath) != null;
            result.FormalGasAbilitySmokeCodeConfigured = SmokeEquipmentAbilityCode > 0;
            if (!result.HeroPrefabFound || !result.BaseCharacterPrefabFound || !result.FormalGasAbilitySmokeCodeConfigured)
            {
                throw new InvalidOperationException("运行态 smoke 缺少正式 prefab 或 EX-GAS 能力 code。");
            }

            result.SmokeAssetsPrepared = PrepareSmokeAssets();
            if (!result.SmokeAssetsPrepared || s_smokeHeadEquipment == null || s_smokeAbilityEquipment == null || s_smokeNpcSheet == null)
            {
                throw new InvalidOperationException("运行态 smoke 资产准备失败。");
            }

            InventorySystem inventorySystem = GameManager.InventorySystem;

            s_characterAlpha = CreateSmokeNpc("装备烟雾-角色A", new Vector3(-2.0f, 0.0f, 0.0f));
            s_characterBeta = CreateSmokeNpc("装备烟雾-角色B", new Vector3(-0.5f, 0.0f, 0.0f));
            result.CharacterAlphaRegisteredPersistable = TryRegisterCustomPersistable(s_characterAlpha);
            result.CharacterBetaRegisteredPersistable = TryRegisterCustomPersistable(s_characterBeta);

            InventoryOwnerHandle characterAlphaOwner = inventorySystem.GetOwner(s_characterAlpha);
            InventoryOwnerHandle characterBetaOwner = inventorySystem.GetOwner(s_characterBeta);
            result.CharacterOwnersAreDistinct = !characterAlphaOwner.Equals(characterBetaOwner);
            result.CharacterAlphaOwner = characterAlphaOwner.ToString();
            result.CharacterBetaOwner = characterBetaOwner.ToString();

            inventorySystem.AddToBag(characterAlphaOwner, s_smokeHeadEquipment, 1, EItemTransferType.Command);
            inventorySystem.AddToBag(characterBetaOwner, s_smokeAbilityEquipment, 1, EItemTransferType.Command);
            result.CharacterAlphaBagBeforeEquip = inventorySystem.GetItemCount(characterAlphaOwner, s_smokeHeadEquipment);
            result.CharacterBetaBagBeforeEquip = inventorySystem.GetItemCount(characterBetaOwner, s_smokeAbilityEquipment);

            if (!s_characterAlpha.TryGetComponent(out CharacterEquipment characterAlphaEquipment) ||
                !s_characterBeta.TryGetComponent(out CharacterEquipment characterBetaEquipment))
            {
                throw new InvalidOperationException("装备烟雾角色缺少 CharacterEquipment。");
            }

            EEquipmentOperationResult characterAlphaEquipResult = inventorySystem.TryEquip(characterAlphaOwner, characterAlphaEquipment, s_smokeHeadEquipment);
            EEquipmentOperationResult characterBetaEquipResult = inventorySystem.TryEquip(characterBetaOwner, characterBetaEquipment, s_smokeAbilityEquipment);
            result.CharacterAlphaEquipResult = characterAlphaEquipResult.ToString();
            result.CharacterBetaEquipResult = characterBetaEquipResult.ToString();
            result.CharacterAlphaEquippedHead =
                inventorySystem.GetEquipment(characterAlphaEquipment, s_smokeHeadEquipment.type) == s_smokeHeadEquipment;
            result.CharacterBetaEquippedTorso =
                inventorySystem.GetEquipment(characterBetaEquipment, s_smokeAbilityEquipment.type) == s_smokeAbilityEquipment;
            result.CharacterAlphaBagAfterEquip = inventorySystem.GetItemCount(characterAlphaOwner, s_smokeHeadEquipment);
            result.CharacterBetaBagAfterEquip = inventorySystem.GetItemCount(characterBetaOwner, s_smokeAbilityEquipment);

            EEquipmentOperationResult characterAlphaUnequipResult = inventorySystem.TryUnequip(characterAlphaOwner, characterAlphaEquipment, s_smokeHeadEquipment.type);
            result.CharacterAlphaUnequipResult = characterAlphaUnequipResult.ToString();
            result.CharacterAlphaBagAfterUnequip = inventorySystem.GetItemCount(characterAlphaOwner, s_smokeHeadEquipment);
            result.CharacterBetaStillEquippedAfterCharacterAlphaUnequip =
                s_characterBeta.TryGetComponent(out characterBetaEquipment) &&
                inventorySystem.GetEquipment(characterBetaEquipment, s_smokeAbilityEquipment.type) == s_smokeAbilityEquipment;
            result.CharacterBetaBagAfterCharacterAlphaUnequip = inventorySystem.GetItemCount(characterBetaOwner, s_smokeAbilityEquipment);

            result.FormalGasAbilityGrantedOnEquip = s_characterBeta.HasFormalGasAbility(SmokeEquipmentAbilityCode);
            EEquipmentOperationResult characterBetaUnequipResult = inventorySystem.TryUnequip(characterBetaOwner, characterBetaEquipment, s_smokeAbilityEquipment.type);
            result.CharacterBetaUnequipResult = characterBetaUnequipResult.ToString();
            result.FormalGasAbilityRemovedOnUnequip = !s_characterBeta.HasFormalGasAbility(SmokeEquipmentAbilityCode);
            result.CharacterBetaBagAfterUnequip = inventorySystem.GetItemCount(characterBetaOwner, s_smokeAbilityEquipment);

            EEquipmentOperationResult characterBetaReequipResult = inventorySystem.TryEquip(characterBetaOwner, characterBetaEquipment, s_smokeAbilityEquipment);
            result.CharacterBetaReequipResult = characterBetaReequipResult.ToString();
            result.FormalGasAbilityRestoredOnReequip = s_characterBeta.HasFormalGasAbility(SmokeEquipmentAbilityCode);

            CharacterAbilitySourceKey suppressionSource = new(ECharacterAbilitySourceKind.Transformation, SmokeSuppressionSourceId);
            s_characterBeta.ApplyAlterationEquipmentEffectSuppressionRule(suppressionSource);
            result.FormalGasAbilityStillOwnedDuringSuppression = s_characterBeta.HasFormalGasAbility(SmokeEquipmentAbilityCode);
            result.FormalGasAbilitySuppressedDuringSuppression = s_characterBeta.IsFormalGasAbilitySuppressed(SmokeEquipmentAbilityCode);

            s_characterBeta.RemoveAllAlterationEquipmentEffectSuppressionRules(suppressionSource);
            result.FormalGasAbilityUnsuppressedAfterRemoval = !s_characterBeta.IsFormalGasAbilitySuppressed(SmokeEquipmentAbilityCode);

            s_nonHeroNpc = CreateSmokeNpc("装备烟雾-NPC", new Vector3(1.5f, 0.0f, 0.0f));
            result.NonHeroRegisteredPersistable = TryRegisterCustomPersistable(s_nonHeroNpc);
            result.NonHeroIsHero = s_nonHeroNpc.GetComponent<Hero>() != null;

            InventoryOwnerHandle nonHeroOwner = inventorySystem.GetOwner(s_nonHeroNpc);
            InventoryOwnerHandle nonHeroCorpseOwner = inventorySystem.GetCorpseOwner(s_nonHeroNpc);
            result.NonHeroOwner = nonHeroOwner.ToString();
            result.NonHeroCorpseOwner = nonHeroCorpseOwner.ToString();

            if (!s_nonHeroNpc.TryGetComponent(out CharacterEquipment nonHeroEquipment))
            {
                throw new InvalidOperationException("非 Hero 装备烟雾角色缺少 CharacterEquipment。");
            }

            inventorySystem.AddToBag(nonHeroOwner, s_smokeHeadEquipment, 1, EItemTransferType.Command);
            result.NonHeroBagBeforeEquip = inventorySystem.GetItemCount(nonHeroOwner, s_smokeHeadEquipment);
            EEquipmentOperationResult nonHeroEquipResult = inventorySystem.TryEquip(nonHeroOwner, nonHeroEquipment, s_smokeHeadEquipment);
            result.NonHeroEquipResult = nonHeroEquipResult.ToString();
            result.NonHeroEquippedHead =
                inventorySystem.GetEquipment(nonHeroEquipment, s_smokeHeadEquipment.type) == s_smokeHeadEquipment;
            result.NonHeroBagAfterEquip = inventorySystem.GetItemCount(nonHeroOwner, s_smokeHeadEquipment);

            result.NonHeroCorpseTransferResult = inventorySystem.TransferCharacterEquipmentToCorpse(s_nonHeroNpc);
            result.NonHeroEquipmentRemovedFromSlots =
                inventorySystem.GetEquipment(nonHeroEquipment, s_smokeHeadEquipment.type) == null;
            result.NonHeroCorpseHeadCount = inventorySystem.GetItemCount(nonHeroCorpseOwner, s_smokeHeadEquipment);
            result.NonHeroBagAfterCorpseTransfer = inventorySystem.GetItemCount(nonHeroOwner, s_smokeHeadEquipment);
        }

        private static void FinalizeResult(ValidationResult result)
        {
            List<string> failures = new();

            Require(result.GameManagerExists, "GameManager 未启动。", failures);
            Require(result.HasInventorySystem, "InventorySystem 未注册。", failures);
            Require(result.HasPersistenceSystem, "PersistenceSystem 未注册。", failures);
            Require(result.HeroPrefabFound, "没有找到 0_Hero_Base.prefab。", failures);
            Require(result.BaseCharacterPrefabFound, "没有找到 0_Character_Base.prefab。", failures);
            Require(result.FormalGasAbilitySmokeCodeConfigured, "没有配置装备 smoke 使用的 EX-GAS 能力 code。", failures);
            Require(result.SmokeAssetsPrepared, "运行态 smoke 资产未准备完成。", failures);
            Require(result.CharacterAlphaRegisteredPersistable, "角色A 没有登记为正式持久化 owner。", failures);
            Require(result.CharacterBetaRegisteredPersistable, "角色B 没有登记为正式持久化 owner。", failures);
            Require(result.CharacterOwnersAreDistinct, "两个角色的背包 owner 没有区分开。", failures);
            Require(result.CharacterAlphaBagBeforeEquip == 1, $"角色A 装备前背包数量应为 1，实际为 {result.CharacterAlphaBagBeforeEquip}。", failures);
            Require(result.CharacterBetaBagBeforeEquip == 1, $"角色B 装备前背包数量应为 1，实际为 {result.CharacterBetaBagBeforeEquip}。", failures);
            Require(result.CharacterAlphaEquipResult == EEquipmentOperationResult.Valid.ToString(), $"角色A 装备失败：{result.CharacterAlphaEquipResult}。", failures);
            Require(result.CharacterBetaEquipResult == EEquipmentOperationResult.Valid.ToString(), $"角色B 装备失败：{result.CharacterBetaEquipResult}。", failures);
            Require(result.CharacterAlphaEquippedHead, "角色A 没有持有自己的头部装备。", failures);
            Require(result.CharacterBetaEquippedTorso, "角色B 没有持有自己的躯干装备。", failures);
            Require(result.CharacterAlphaBagAfterEquip == 0, $"角色A 装备后背包数量应为 0，实际为 {result.CharacterAlphaBagAfterEquip}。", failures);
            Require(result.CharacterBetaBagAfterEquip == 0, $"角色B 装备后背包数量应为 0，实际为 {result.CharacterBetaBagAfterEquip}。", failures);
            Require(result.CharacterAlphaUnequipResult == EEquipmentOperationResult.Valid.ToString(), $"角色A 卸装失败：{result.CharacterAlphaUnequipResult}。", failures);
            Require(result.CharacterAlphaBagAfterUnequip == 1, $"角色A 卸装后背包数量应恢复为 1，实际为 {result.CharacterAlphaBagAfterUnequip}。", failures);
            Require(result.CharacterBetaStillEquippedAfterCharacterAlphaUnequip, "角色A 卸装影响了角色B 的装备状态。", failures);
            Require(result.CharacterBetaBagAfterCharacterAlphaUnequip == 0, $"角色A 卸装后，角色B 背包数量应仍为 0，实际为 {result.CharacterBetaBagAfterCharacterAlphaUnequip}。", failures);
            Require(result.FormalGasAbilityGrantedOnEquip, "装备授予的 EX-GAS 能力没有随着装备生效。", failures);
            Require(result.CharacterBetaUnequipResult == EEquipmentOperationResult.Valid.ToString(), $"角色B 卸装失败：{result.CharacterBetaUnequipResult}。", failures);
            Require(result.FormalGasAbilityRemovedOnUnequip, "角色B 卸装后，装备授予的 EX-GAS 能力没有撤回。", failures);
            Require(result.CharacterBetaBagAfterUnequip == 1, $"角色B 卸装后背包数量应恢复为 1，实际为 {result.CharacterBetaBagAfterUnequip}。", failures);
            Require(result.CharacterBetaReequipResult == EEquipmentOperationResult.Valid.ToString(), $"角色B 重新装备失败：{result.CharacterBetaReequipResult}。", failures);
            Require(result.FormalGasAbilityRestoredOnReequip, "角色B 重新装备后，授予的 EX-GAS 能力没有恢复。", failures);
            Require(result.FormalGasAbilityStillOwnedDuringSuppression, "装备压制期间角色B 丢失了 EX-GAS 能力实例，而不是进入压制态。", failures);
            Require(result.FormalGasAbilitySuppressedDuringSuppression, "EX-GAS 能力在压制期间没有进入 suppressed 状态。", failures);
            Require(result.FormalGasAbilityUnsuppressedAfterRemoval, "解除压制后 EX-GAS 能力没有恢复可用。", failures);
            Require(result.NonHeroRegisteredPersistable, "非 Hero 角色没有登记为正式持久化 owner。", failures);
            Require(!result.NonHeroIsHero, "非 Hero 尸体转移 smoke 实际上仍然用了 Hero。", failures);
            Require(result.NonHeroBagBeforeEquip == 1, $"非 Hero 装备前背包数量应为 1，实际为 {result.NonHeroBagBeforeEquip}。", failures);
            Require(result.NonHeroEquipResult == EEquipmentOperationResult.Valid.ToString(), $"非 Hero 装备失败：{result.NonHeroEquipResult}。", failures);
            Require(result.NonHeroEquippedHead, "非 Hero 没有持有自己的头部装备。", failures);
            Require(result.NonHeroBagAfterEquip == 0, $"非 Hero 装备后背包数量应为 0，实际为 {result.NonHeroBagAfterEquip}。", failures);
            Require(result.NonHeroCorpseTransferResult, "非 Hero 装备没有通过正式尸体转移入口进入尸体 owner。", failures);
            Require(result.NonHeroEquipmentRemovedFromSlots, "非 Hero 尸体转移后装备槽仍保留装备。", failures);
            Require(result.NonHeroCorpseHeadCount == 1, $"非 Hero 尸体 owner 中装备数量应为 1，实际为 {result.NonHeroCorpseHeadCount}。", failures);
            Require(result.NonHeroBagAfterCorpseTransfer == 0, $"非 Hero 尸体转移后原 owner 背包数量应为 0，实际为 {result.NonHeroBagAfterCorpseTransfer}。", failures);

            result.Success = failures.Count == 0;
            result.Failures = failures.ToArray();
            result.Message = result.Success
                ? "CharacterEquipment runtime smoke 通过。"
                : string.Join(" | ", failures);
            result.Completed = true;
        }

        private static NPC CreateSmokeNpc(string cloneName, Vector3 spawnPosition)
        {
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(BaseCharacterPrefabPath)
                ?? throw new InvalidOperationException($"无法加载 Character base prefab: {BaseCharacterPrefabPath}");

            GameObject cloneObject = UnityEngine.Object.Instantiate(prefab, spawnPosition, Quaternion.identity);
            cloneObject.name = cloneName;
            ApplyDontSaveHierarchy(cloneObject);
            cloneObject.SetActive(false);

            NPC npc = cloneObject.AddComponent<NPC>();
            SetPrivateField(npc, "m_sheet", s_smokeNpcSheet);
            ConfigureCoreCharacterReferences(cloneObject, npc);

            CharacterAbilitySet abilitySet = cloneObject.GetComponent<CharacterAbilitySet>()
                ?? cloneObject.AddComponent<CharacterAbilitySet>();
            SetPrivateField(abilitySet, "m_character", npc);
            ConfigureAbilityRoots(cloneObject.transform, abilitySet);

            if (!cloneObject.TryGetComponent(out CharacterInventory characterInventory))
            {
                characterInventory = cloneObject.AddComponent<CharacterInventory>();
            }
            SetPrivateField(characterInventory, "m_character", npc);

            if (!cloneObject.TryGetComponent(out CharacterEquipment characterEquipment))
            {
                characterEquipment = cloneObject.AddComponent<CharacterEquipment>();
            }
            SetPrivateField(characterEquipment, "m_character", npc);

            cloneObject.transform.position = spawnPosition;
            cloneObject.SetActive(true);
            if (cloneObject.TryGetComponent(out Rigidbody2D rigidbody))
            {
                rigidbody.position = spawnPosition;
            }

            cloneObject.transform.position = spawnPosition;
            npc.ResetMovement();
            NormalizeCharacterRuntimeState(npc);
            return npc;
        }

        private static void ConfigureAbilityRoots(Transform root, CharacterAbilitySet abilitySet)
        {
            Transform staticRoot = root.Find("Static Pivot")
                ?? throw new InvalidOperationException("0_Character_Base 缺少 Static Pivot。");
            Transform polydirectionalRoot = root.Find("Polydirectional Pivot")
                ?? throw new InvalidOperationException("0_Character_Base 缺少 Polydirectional Pivot。");
            Transform horizontalRoot = root.Find("Horizontal Pivot")
                ?? throw new InvalidOperationException("0_Character_Base 缺少 Horizontal Pivot。");

            SetPrivateField(abilitySet, "m_staticAbilityRoot", staticRoot);
            SetPrivateField(abilitySet, "m_polydirectionalAbilityRoot", polydirectionalRoot);
            SetPrivateField(abilitySet, "m_horizontalAbilityRoot", horizontalRoot);
        }

        private static void ApplyDontSaveHierarchy(GameObject root)
        {
            if (root == null)
            {
                return;
            }

            foreach (Transform child in root.GetComponentsInChildren<Transform>(true))
            {
                child.gameObject.hideFlags = HideFlags.DontSave;
                foreach (Component component in child.GetComponents<Component>())
                {
                    if (component != null)
                    {
                        component.hideFlags = HideFlags.DontSave;
                    }
                }
            }
        }

        private static void ConfigureCoreCharacterReferences(GameObject cloneObject, NPC npc)
        {
            Rigidbody2D rigidbody = cloneObject.GetComponent<Rigidbody2D>()
                ?? throw new InvalidOperationException("0_Character_Base 缺少 Rigidbody2D。");
            SetPrivateField(npc, "m_rigidbody", rigidbody);
        }

        private static bool PrepareSmokeAssets()
        {
            s_smokeNpcSheet = CreateOrUpdateSmokeNpcSheet();
            s_smokeHeadEquipment = CreateOrUpdateSmokeEquipment(
                SmokeHeadEquipmentAssetPath,
                "CharacterEquipment Runtime Smoke Head",
                EEquipmentType.Head,
                0);
            s_smokeAbilityEquipment = CreateOrUpdateSmokeEquipment(
                SmokeAbilityEquipmentAssetPath,
                "CharacterEquipment Runtime Smoke Torso Formal Ability",
                EEquipmentType.Torso,
                SmokeEquipmentAbilityCode);

            if (s_smokeNpcSheet == null || s_smokeHeadEquipment == null || s_smokeAbilityEquipment == null)
            {
                return false;
            }

            RegisterSmokeEquipment(s_smokeHeadEquipment, ref s_registeredHeadEquipment);
            RegisterSmokeEquipment(s_smokeAbilityEquipment, ref s_registeredAbilityEquipment);
            return true;
        }

        private static NPCSheet? CreateOrUpdateSmokeNpcSheet()
        {
            NPCSheet npcSheet = AssetDatabase.LoadAssetAtPath<NPCSheet>(SmokeNpcSheetAssetPath);
            if (npcSheet == null)
            {
                npcSheet = ScriptableObject.CreateInstance<NPCSheet>();
                AssetDatabase.CreateAsset(npcSheet, SmokeNpcSheetAssetPath);
            }

            SetPrivateField(npcSheet, "m_displayName", "CharacterEquipment Runtime Smoke NPC");
            SetPrivateField(npcSheet, "m_formalGasAbilitiesPerLevel", new SerializableDictionary<int, int>());
            EditorUtility.SetDirty(npcSheet);
            AssetDatabase.SaveAssets();
            return npcSheet;
        }

        private static Equipment? CreateOrUpdateSmokeEquipment(
            string assetPath,
            string displayName,
            EEquipmentType equipmentType,
            int formalGasAbilityCode)
        {
            Equipment equipment = AssetDatabase.LoadAssetAtPath<Equipment>(assetPath);
            if (equipment == null)
            {
                equipment = ScriptableObject.CreateInstance<Equipment>();
                AssetDatabase.CreateAsset(equipment, assetPath);
            }

            SetPrivateField(equipment, "m_category", EItemCategory.Gear);
            SetPrivateField(equipment, "m_displayName", displayName);
            SetPrivateField(equipment, "m_description", "CharacterEquipment runtime smoke asset");
            SetPrivateField(equipment, "m_price", 1);
            SetPrivateField(equipment, "m_type", equipmentType);
            SetPrivateField(equipment, "m_bonusStats", new Stats());
            SetPrivateField(
                equipment,
                "m_formalGasAbilityCodes",
                formalGasAbilityCode > 0 ? new[] { formalGasAbilityCode } : Array.Empty<int>());

            EditorUtility.SetDirty(equipment);
            AssetDatabase.SaveAssets();
            return equipment;
        }

        private static void RegisterSmokeEquipment(Equipment equipment, ref bool registeredBySmoke)
        {
            if (!GameManager.Database.HasGUID(equipment.GetAssetGUID()))
            {
                GameManager.Database.Register(equipment);
                registeredBySmoke = true;
            }
            else
            {
                registeredBySmoke = false;
            }
        }

        private static void CleanupRuntimeArtifacts()
        {
            try
            {
                if (GameManager.Exists() && GameManager.HasSystem<InventorySystem>())
                {
                    InventorySystem inventorySystem = GameManager.InventorySystem;

                    CleanupCharacterInventoryState(inventorySystem, s_characterAlpha, s_smokeHeadEquipment);
                    CleanupCharacterInventoryState(inventorySystem, s_characterBeta, s_smokeAbilityEquipment);
                    CleanupCharacterInventoryState(inventorySystem, s_nonHeroNpc, s_smokeHeadEquipment);
                }
            }
            catch
            {
                // cleanup 失败不能覆盖原始 smoke 结果
            }

            SafeDestroy(s_nonHeroNpc);
            SafeDestroy(s_characterBeta);
            SafeDestroy(s_characterAlpha);

            UnregisterAndDeleteSmokeEquipment(s_smokeHeadEquipment, SmokeHeadEquipmentAssetPath, s_registeredHeadEquipment);
            UnregisterAndDeleteSmokeEquipment(s_smokeAbilityEquipment, SmokeAbilityEquipmentAssetPath, s_registeredAbilityEquipment);
            DeleteSmokeAsset(SmokeNpcSheetAssetPath);

            s_nonHeroNpc = null;
            s_characterBeta = null;
            s_characterAlpha = null;
            s_smokeNpcSheet = null;
            s_smokeHeadEquipment = null;
            s_smokeAbilityEquipment = null;
            s_registeredHeadEquipment = false;
            s_registeredAbilityEquipment = false;
        }

        private static void CleanupCharacterInventoryState(
            InventorySystem inventorySystem,
            CharacterBase? character,
            Equipment? equipment)
        {
            if (inventorySystem == null || character == null || equipment == null)
            {
                return;
            }

            if (character.TryGetComponent(out CharacterEquipment equipmentComponent) &&
                equipmentComponent != null &&
                equipmentComponent.TryGetEquipment(equipment.type, out _))
            {
                InventoryOwnerHandle owner = inventorySystem.GetOwner(character);
                inventorySystem.TryUnequip(owner, equipmentComponent, equipment.type);
            }

            InventoryOwnerHandle bagOwner = inventorySystem.GetOwner(character);
            int bagCount = inventorySystem.GetItemCount(bagOwner, equipment);
            if (bagCount > 0)
            {
                inventorySystem.RemoveFromBag(bagOwner, equipment, bagCount, EItemTransferType.Command);
            }

            InventoryOwnerHandle corpseOwner = inventorySystem.GetCorpseOwner(character);
            int corpseCount = inventorySystem.GetItemCount(corpseOwner, equipment);
            if (corpseCount > 0)
            {
                inventorySystem.RemoveFromBag(corpseOwner, equipment, corpseCount, EItemTransferType.Corpse);
            }
        }

        private static void SafeDestroy(Component? component)
        {
            if (component != null)
            {
                UnityEngine.Object.DestroyImmediate(component.gameObject);
            }
        }

        private static void UnregisterAndDeleteSmokeEquipment(Equipment? equipment, string assetPath, bool registeredBySmoke)
        {
            if (equipment != null && registeredBySmoke && GameManager.Exists())
            {
                GameManager.Database.Unregister(equipment);
            }

            DeleteSmokeAsset(assetPath);
        }

        private static void DeleteSmokeAsset(string assetPath)
        {
            if (!string.IsNullOrWhiteSpace(assetPath) && AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(assetPath) != null)
            {
                AssetDatabase.DeleteAsset(assetPath);
                AssetDatabase.SaveAssets();
            }
        }

        private static void NormalizeCharacterRuntimeState(CharacterBase character)
        {
            if (character == null)
            {
                return;
            }

            character.Heal(int.MaxValue, EEffectVisualFlags.NoFloatingText);
            character.RecoverMana(int.MaxValue, EEffectVisualFlags.NoFloatingText);
        }

        private static bool TryRegisterCustomPersistable(Persistable persistable)
        {
            if (persistable == null || !GameManager.Exists() || !GameManager.HasSystem<PersistenceSystem>())
            {
                return false;
            }

            MethodInfo? registerMethod = typeof(PersistenceSystem).GetMethod(
                "RegisterCustomInstancedPersistable",
                BindingFlags.Instance | BindingFlags.NonPublic);
            if (registerMethod == null)
            {
                return false;
            }

            registerMethod.Invoke(GameManager.PersistenceSystem, new object?[] { persistable, null });
            return true;
        }

        private static void SetPrivateField(object target, string fieldName, object? value)
        {
            Type? currentType = target.GetType();
            while (currentType != null)
            {
                FieldInfo? field = currentType.GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
                if (field != null)
                {
                    field.SetValue(target, value);
                    return;
                }

                currentType = currentType.BaseType;
            }

            throw new MissingFieldException(target.GetType().FullName, fieldName);
        }

        private static ValidationResult Fail(string message)
        {
            return new ValidationResult
            {
                Completed = true,
                Success = false,
                Message = message,
                Failures = new[] { message },
            };
        }

        private static void WriteResult(ValidationResult result)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ResultPath)!);
            File.WriteAllText(ResultPath, JsonUtility.ToJson(result, true));
        }

        private static void Require(bool condition, string failure, List<string> failures)
        {
            if (!condition)
            {
                failures.Add(failure);
            }
        }

        [Serializable]
        public sealed class StartResult
        {
            public string ResultPath = string.Empty;
        }

        [Serializable]
        public sealed class ValidationResult
        {
            public bool Completed;
            public bool Success;
            public string Message = string.Empty;
            public string ScenePath = string.Empty;
            public string ScreenSize = string.Empty;

            public bool GameManagerExists;
            public bool HasInventorySystem;
            public bool HasPersistenceSystem;
            public bool HeroPrefabFound;
            public bool BaseCharacterPrefabFound;
            public bool FormalGasAbilitySmokeCodeConfigured;
            public bool SmokeAssetsPrepared;

            public bool CharacterAlphaRegisteredPersistable;
            public bool CharacterBetaRegisteredPersistable;
            public bool CharacterOwnersAreDistinct;
            public string CharacterAlphaOwner = string.Empty;
            public string CharacterBetaOwner = string.Empty;
            public int CharacterAlphaBagBeforeEquip;
            public int CharacterBetaBagBeforeEquip;
            public string CharacterAlphaEquipResult = string.Empty;
            public string CharacterBetaEquipResult = string.Empty;
            public bool CharacterAlphaEquippedHead;
            public bool CharacterBetaEquippedTorso;
            public int CharacterAlphaBagAfterEquip;
            public int CharacterBetaBagAfterEquip;
            public string CharacterAlphaUnequipResult = string.Empty;
            public int CharacterAlphaBagAfterUnequip;
            public bool CharacterBetaStillEquippedAfterCharacterAlphaUnequip;
            public int CharacterBetaBagAfterCharacterAlphaUnequip;

            public bool FormalGasAbilityGrantedOnEquip;
            public string CharacterBetaUnequipResult = string.Empty;
            public bool FormalGasAbilityRemovedOnUnequip;
            public int CharacterBetaBagAfterUnequip;
            public string CharacterBetaReequipResult = string.Empty;
            public bool FormalGasAbilityRestoredOnReequip;
            public bool FormalGasAbilityStillOwnedDuringSuppression;
            public bool FormalGasAbilitySuppressedDuringSuppression;
            public bool FormalGasAbilityUnsuppressedAfterRemoval;

            public bool NonHeroRegisteredPersistable;
            public bool NonHeroIsHero;
            public string NonHeroOwner = string.Empty;
            public string NonHeroCorpseOwner = string.Empty;
            public int NonHeroBagBeforeEquip;
            public string NonHeroEquipResult = string.Empty;
            public bool NonHeroEquippedHead;
            public int NonHeroBagAfterEquip;
            public bool NonHeroCorpseTransferResult;
            public bool NonHeroEquipmentRemovedFromSlots;
            public int NonHeroCorpseHeadCount;
            public int NonHeroBagAfterCorpseTransfer;

            public string[] Failures = Array.Empty<string>();
        }
    }
}
