param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function Read-Text {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return Get-Content -Raw -LiteralPath $Path
    }

    return ""
}

$violations = [System.Collections.Generic.List[string]]::new()
$runtimeRoot = Join-Path $ProjectRoot "Assets/Scripts/GameCore/Runtime"
$inventorySystemPath = Join-Path $runtimeRoot "Game/Systems/InventorySystem.cs"
$characterEquipmentPath = Join-Path $runtimeRoot "Entities/Characters/CharacterEquipment.cs"
$chestPath = Join-Path $runtimeRoot "Entities/Chest.cs"
$itemPickablePath = Join-Path $runtimeRoot "Loot/ItemPickable.cs"
$inventoryTransferRequestPath = Join-Path $runtimeRoot "Game/Systems/InventoryTransferRequest.cs"
$shopPath = Join-Path $runtimeRoot "UI/Menus/Shop/UIShop.cs"
$menuFeedbackPromptsPath = Join-Path $runtimeRoot "UI/Menus/MenuFeedbackPrompts.cs"
$recipePath = Join-Path $runtimeRoot "Database/Crafting/Recipe.cs"
$craftingStationPath = Join-Path $runtimeRoot "Database/Crafting/CraftingStation.cs"
$itemEffectBasePath = Join-Path $runtimeRoot "Database/Items/ItemEffects/AItemEffect.cs"
$characterActorRewardsPath = Join-Path $runtimeRoot "Entities/Characters/CharacterActor.Rewards.cs"

$inventorySystemText = Read-Text $inventorySystemPath
$characterEquipmentText = Read-Text $characterEquipmentPath
$chestText = Read-Text $chestPath
$itemPickableText = Read-Text $itemPickablePath
$inventoryTransferRequestText = Read-Text $inventoryTransferRequestPath
$shopText = Read-Text $shopPath
$menuFeedbackPromptsText = Read-Text $menuFeedbackPromptsPath
$recipeText = Read-Text $recipePath
$craftingStationText = Read-Text $craftingStationPath
$itemEffectBaseText = Read-Text $itemEffectBasePath
$characterActorRewardsText = Read-Text $characterActorRewardsPath

$inventoryWritesRejectInvalidInputs =
    $inventorySystemText.Contains("private static void EnsureValidInventoryWrite(Item item, int quantity, string operationName)") -and
    $inventorySystemText.Contains("throw new InvalidOperationException") -and
    $inventorySystemText.Contains("if (!item)") -and
    $inventorySystemText.Contains("if (quantity <= 0)") -and
    $inventorySystemText.Contains("EnsureValidInventoryWrite(item, quantity, nameof(AddToBag));") -and
    $inventorySystemText.Contains("EnsureValidInventoryWrite(item, quantity, nameof(RemoveFromBag));")
if (-not $inventoryWritesRejectInvalidInputs) {
    [void]$violations.Add("InventorySystem AddToBag/RemoveFromBag must reject invalid item or quantity instead of treating bad result writes as successful no-ops.")
}

$chestRejectsInvalidLootEntries =
    $inventorySystemText.Contains("public void ExecuteChestLootInitialization(InventoryOwnerHandle containerOwner, ChestLoot loot)") -and
    $inventorySystemText.Contains("private static void EnsureValidChestLoot(ChestLootEntry[] entries, int money)") -and
    $inventorySystemText.Contains("if (money < 0)") -and
    $inventorySystemText.Contains("if (!entry.item || entry.quantity <= 0)") -and
    $inventorySystemText.IndexOf("EnsureValidChestLoot(entries, loot.money);", [System.StringComparison]::Ordinal) -lt
        $inventorySystemText.IndexOf("AddToBag(containerOwner, entry.item, entry.quantity, EItemTransferType.Chest);", [System.StringComparison]::Ordinal) -and
    $chestText.Contains("ExecuteChestLootInitialization(GetInventoryOwner(), m_loot)") -and
    $chestText.IndexOf("InitializeContainerLoot(commandContext);", [System.StringComparison]::Ordinal) -lt
        $chestText.IndexOf("TryPlayContentRevealAnimation();", [System.StringComparison]::Ordinal) -and
    -not $chestText.Contains("AddToBag(containerOwner, entry.item, entry.quantity, EItemTransferType.Chest);") -and
    -not $chestText.Contains("GameManager.InventorySystem.AddMoney(m_loot.money);")
if (-not $chestRejectsInvalidLootEntries) {
    [void]$violations.Add("Chest first-open loot initialization must use InventorySystem to validate all configured loot before writing any items or money.")
}

$pickableKeepsFailedInteraction =
    $itemPickableText.Contains("if (m_item == null || m_quantity <= 0)") -and
    $itemPickableText.Contains("return false;") -and
    $itemPickableText.Contains("GameManager.InventorySystem.AddToBag(ownerHandle, m_item, m_quantity, m_transferType);")
if (-not $pickableKeepsFailedInteraction) {
    [void]$violations.Add("ItemPickable must keep invalid pickup configuration as a failed interaction rather than a completed pickup.")
}

$transferKeepsFailureResult =
    $inventorySystemText.Contains("public InventoryTransferResult ExecuteTransfer(InventoryTransferRequest request)") -and
    $inventorySystemText.Contains("ValidateTransferRequest(request)") -and
    $inventoryTransferRequestText.Contains("InvalidItem") -and
    $inventoryTransferRequestText.Contains("InvalidQuantity") -and
    $inventoryTransferRequestText.Contains("public static InventoryTransferResult Failed")
if (-not $transferKeepsFailureResult) {
    [void]$violations.Add("Inventory transfer requests must keep explicit failed results for invalid item or quantity instead of throwing before UI can report failure.")
}

$shopTradingUsesInventoryTransaction =
    $inventorySystemText.Contains("public InventoryOperationResult ExecuteShopPurchase(") -and
    $inventorySystemText.Contains("public InventoryOperationResult ExecuteShopSale(") -and
    $inventorySystemText.Contains("InventoryOperationResult paymentResult = ExecuteMoneyPayment(itemPrice);") -and
    $inventorySystemText.Contains("AddToBag(destinationOwner, item, 1, EItemTransferType.Trading);") -and
    $inventorySystemText.IndexOf("InventoryOperationResult paymentResult = ExecuteMoneyPayment(itemPrice);", [System.StringComparison]::Ordinal) -lt
        $inventorySystemText.IndexOf("AddToBag(destinationOwner, item, 1, EItemTransferType.Trading);", [System.StringComparison]::Ordinal) -and
    $inventorySystemText.Contains("RemoveFromBag(sourceOwner, item, 1, EItemTransferType.Trading)") -and
    $inventorySystemText.Contains("AddMoney(sellingPrice);") -and
    $shopText.Contains("ExecuteShopPurchase(ownerHandle, m_shop, item)") -and
    $shopText.Contains("ExecuteShopSale(ownerHandle, m_shop, item)") -and
    -not [regex]::IsMatch($shopText, "GameManager\.InventorySystem\.(RemoveMoney|AddMoney|AddToBag|RemoveFromBag)\(")
if (-not $shopTradingUsesInventoryTransaction) {
    [void]$violations.Add("Shop buy/sell flows must request InventorySystem shop transactions instead of hand-writing remove money/add item/remove item/add money steps in UI.")
}

$craftingUsesValidatedInventoryTransaction =
    $recipeText.Contains("public void EnsureCraftConfiguration()") -and
    $recipeText.Contains("if (!m_item)") -and
    $recipeText.Contains("if (m_quantity <= 0)") -and
    $recipeText.Contains("if (!IsValidIngredient(ingredient))") -and
    $inventorySystemText.Contains("public InventoryOperationResult ExecuteCraftRecipe(") -and
    $inventorySystemText.Contains("foreach (KeyValuePair<Item, int> requirement in recipe.GetIngredients())") -and
    $inventorySystemText.Contains("return InventoryOperationResult.Failed(EInventoryOperationFailureReason.InsufficientIngredients);") -and
    $inventorySystemText.Contains("EnsureValidMoneyPayment(craftCost, nameof(ExecuteCraftRecipe));") -and
    $inventorySystemText.Contains("InventoryOperationResult paymentResult = ExecuteMoneyPayment(craftCost);") -and
    $inventorySystemText.IndexOf("foreach (KeyValuePair<Item, int> requirement in recipe.GetIngredients())", [System.StringComparison]::Ordinal) -lt
        $inventorySystemText.IndexOf("InventoryOperationResult paymentResult = ExecuteMoneyPayment(craftCost);", [System.StringComparison]::Ordinal) -and
    $inventorySystemText.IndexOf("InventoryOperationResult paymentResult = ExecuteMoneyPayment(craftCost);", [System.StringComparison]::Ordinal) -lt
        $inventorySystemText.IndexOf("RemoveFromBag(owner, requirement.Key, requirement.Value, EItemTransferType.Crafting)", [System.StringComparison]::Ordinal) -and
    $inventorySystemText.Contains("AddToBag(owner, recipe.item, recipe.quantity, EItemTransferType.Crafting);") -and
    $craftingStationText.Contains("public InventoryOperationResult TryCraft(CharacterBase owner, Recipe recipe)") -and
    $craftingStationText.Contains("ExecuteCraftRecipe(ownerHandle, recipe, craftCost)") -and
    $craftingStationText.IndexOf("TryCraft(owner, recipe)", [System.StringComparison]::Ordinal) -lt
        $craftingStationText.IndexOf("throw new System.InvalidOperationException", [System.StringComparison]::Ordinal) -and
    $craftingStationText.IndexOf("ExecuteCraftRecipe(ownerHandle, recipe, craftCost)", [System.StringComparison]::Ordinal) -ge 0 -and
    -not [regex]::IsMatch($craftingStationText, "GameManager\.InventorySystem\.(RemoveMoney|AddMoney|AddToBag|RemoveFromBag)\(")
if (-not $craftingUsesValidatedInventoryTransaction) {
    [void]$violations.Add("Crafting must request a validated InventorySystem craft transaction instead of hand-writing remove money/remove ingredients/add outputs in CraftingStation.")
}

$moneyPaymentHelperIsInventoryInternal =
    $inventorySystemText.Contains("private InventoryOperationResult ExecuteMoneyPayment(int amount)") -and
    $inventorySystemText.Contains("EnsureValidMoneyPayment(amount, nameof(ExecuteMoneyPayment));") -and
    $inventorySystemText.Contains("if (amount < 0)") -and
    -not $inventorySystemText.Contains("public InventoryOperationResult ExecuteMoneyPayment(int amount)")
if (-not $moneyPaymentHelperIsInventoryInternal) {
    [void]$violations.Add("Inventory money payment helper must remain internal to InventorySystem transaction flows and must not become a public business entry without current business evidence.")
}

$characterRewardsUseInventoryLootTransaction =
    $inventorySystemText.Contains("public void ExecuteLootReward(") -and
    $inventorySystemText.Contains("private static void EnsureValidLootReward(IReadOnlyList<Loot> grantedLoot, int moneyReward)") -and
    $inventorySystemText.Contains("if (!loot.item || loot.quantity <= 0)") -and
    $inventorySystemText.IndexOf("EnsureValidLootReward(grantedLoot, moneyReward);", [System.StringComparison]::Ordinal) -lt
        $inventorySystemText.IndexOf("AddToBag(destinationOwner, loot.item, loot.quantity, transferType);", [System.StringComparison]::Ordinal) -and
    $characterActorRewardsText.Contains("inventorySystem.ExecuteLootReward(") -and
    $characterActorRewardsText.Contains("EItemTransferType.CharacterDrop") -and
    -not $characterActorRewardsText.Contains("inventorySystem.AddMoney(moneyReward);") -and
    -not $characterActorRewardsText.Contains("inventorySystem.AddToBag(receiverOwner, loot.item, loot.quantity, EItemTransferType.CharacterDrop);")
if (-not $characterRewardsUseInventoryLootTransaction) {
    [void]$violations.Add("Character kill rewards must validate all granted loot before writing reward items or money.")
}

$consumableUseRequiresInventoryItem =
    $menuFeedbackPromptsText.Contains("InventoryUseMissingItem") -and
    $itemEffectBaseText.Contains("TryResolveConsumptionOwner(item, sourceOwner, out consumptionOwner)") -and
    $itemEffectBaseText.Contains("GameManager.InventorySystem.HasItemInBag(ownerHandle, item, 1)") -and
    $itemEffectBaseText.Contains("MenuFeedbackPrompts.InventoryUseMissingItem") -and
    $itemEffectBaseText.Contains("GameManager.InventorySystem.RemoveFromBag(consumptionOwner, item, 1, EItemTransferType.Use)") -and
    $itemEffectBaseText.Contains("throw new System.InvalidOperationException") -and
    $itemEffectBaseText.IndexOf("TryResolveConsumptionOwner(item, sourceOwner, out consumptionOwner)", [System.StringComparison]::Ordinal) -lt
        $itemEffectBaseText.IndexOf("ItemUsageResult result = OnUse(item, sourceOwner, target, location);", [System.StringComparison]::Ordinal) -and
    $itemEffectBaseText.IndexOf("GameManager.InventorySystem.RemoveFromBag(consumptionOwner, item, 1, EItemTransferType.Use)", [System.StringComparison]::Ordinal) -lt
        $itemEffectBaseText.IndexOf("GameRuntimeEvents.RequestAudioPlayback(m_useAudio);", [System.StringComparison]::Ordinal)
if (-not $consumableUseRequiresInventoryItem) {
    [void]$violations.Add("Consumable item effects must confirm the source owner still has the item before applying the effect, and must remove the item before success feedback.")
}

$equipmentUnequipValidatesDestinationBeforeStateChange =
    $inventorySystemText.Contains("private static void EnsureValidInventoryOwner(InventoryOwnerHandle owner, string operationName)") -and
    $inventorySystemText.Contains("if (!owner.IsValid)") -and
    $inventorySystemText.Contains("EnsureValidInventoryOwner(destinationOwner, nameof(TryUnequip));") -and
    $inventorySystemText.IndexOf("EnsureValidInventoryOwner(destinationOwner, nameof(TryUnequip));", [System.StringComparison]::Ordinal) -lt
        $inventorySystemText.IndexOf("EEquipmentOperationResult result = equipmentTarget.TryUnequip(type, out Equipment previousEquipment);", [System.StringComparison]::Ordinal) -and
    $inventorySystemText.IndexOf("EEquipmentOperationResult result = equipmentTarget.TryUnequip(type, out Equipment previousEquipment);", [System.StringComparison]::Ordinal) -lt
        $inventorySystemText.IndexOf("AddToBag(destinationOwner, previousEquipment, 1, EItemTransferType.Equipment);", [System.StringComparison]::Ordinal)
if (-not $equipmentUnequipValidatesDestinationBeforeStateChange) {
    [void]$violations.Add("Equipment unequip must validate the destination inventory owner before changing equipment state or adding the removed item back to inventory.")
}

$equipmentCorpseTransferValidatesOwnerBeforeForceUnequip =
    $inventorySystemText.Contains("EnsureValidInventoryOwner(corpseOwner, nameof(TransferCharacterEquipmentToCorpse));") -and
    $inventorySystemText.Contains("equipmentComponent.ForceUnequipAllEquipmentForLifecycle()") -and
    $inventorySystemText.IndexOf("EnsureValidInventoryOwner(corpseOwner, nameof(TransferCharacterEquipmentToCorpse));", [System.StringComparison]::Ordinal) -ge 0 -and
    $inventorySystemText.IndexOf("EnsureValidInventoryOwner(corpseOwner, nameof(TransferCharacterEquipmentToCorpse));", [System.StringComparison]::Ordinal) -lt
        $inventorySystemText.IndexOf("equipmentComponent.ForceUnequipAllEquipmentForLifecycle()", [System.StringComparison]::Ordinal)
if (-not $equipmentCorpseTransferValidatesOwnerBeforeForceUnequip) {
    [void]$violations.Add("Corpse equipment transfer must validate the corpse inventory owner before force-unequipping character equipment.")
}

$equipmentAbilitySourcePreparedBeforeSlotChange =
    $characterEquipmentText.Contains("private static bool TryPrepareEquipmentAbilitySource(") -and
    $characterEquipmentText.Contains("throw new InvalidOperationException") -and
    $characterEquipmentText.Contains("GameManager.Database.TryCreateReference(equipment, out DatabaseEntryReference<Equipment> reference)") -and
    -not $characterEquipmentText.Contains("TryCreateEquipmentAbilitySource") -and
    $characterEquipmentText.IndexOf("bool hasPreviousSource = TryPrepareEquipmentAbilitySource(", [System.StringComparison]::Ordinal) -ge 0 -and
    $characterEquipmentText.IndexOf("bool hasNextSource = TryPrepareEquipmentAbilitySource(", [System.StringComparison]::Ordinal) -ge 0 -and
    $characterEquipmentText.IndexOf("bool hasPreviousSource = TryPrepareEquipmentAbilitySource(", [System.StringComparison]::Ordinal) -lt
        $characterEquipmentText.IndexOf("m_equipmentLoadout.Set(change.SlotType, change.NextEquipment);", [System.StringComparison]::Ordinal) -and
    $characterEquipmentText.IndexOf("bool hasNextSource = TryPrepareEquipmentAbilitySource(", [System.StringComparison]::Ordinal) -lt
        $characterEquipmentText.IndexOf("m_equipmentLoadout.Set(change.SlotType, change.NextEquipment);", [System.StringComparison]::Ordinal)
if (-not $equipmentAbilitySourcePreparedBeforeSlotChange) {
    [void]$violations.Add("Equipment bonus ability sources must be prepared from DatabaseRegistry before changing the equipment slot; log-and-continue source creation paths are not allowed.")
}

$result = [ordered]@{
    Passed = $violations.Count -eq 0
    InventoryWritesRejectInvalidInputs = $inventoryWritesRejectInvalidInputs
    ChestRejectsInvalidLootEntries = $chestRejectsInvalidLootEntries
    PickableKeepsFailedInteraction = $pickableKeepsFailedInteraction
    TransferKeepsFailureResult = $transferKeepsFailureResult
    ShopTradingUsesInventoryTransaction = $shopTradingUsesInventoryTransaction
    CraftingUsesValidatedInventoryTransaction = $craftingUsesValidatedInventoryTransaction
    MoneyPaymentHelperIsInventoryInternal = $moneyPaymentHelperIsInventoryInternal
    CharacterRewardsUseInventoryLootTransaction = $characterRewardsUseInventoryLootTransaction
    ConsumableUseRequiresInventoryItem = $consumableUseRequiresInventoryItem
    EquipmentUnequipValidatesDestinationBeforeStateChange = $equipmentUnequipValidatesDestinationBeforeStateChange
    EquipmentCorpseTransferValidatesOwnerBeforeForceUnequip = $equipmentCorpseTransferValidatesOwnerBeforeForceUnequip
    EquipmentAbilitySourcePreparedBeforeSlotChange = $equipmentAbilitySourcePreparedBeforeSlotChange
    ViolationCount = $violations.Count
    Violations = $violations
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    if ($result.Passed) {
        Write-Host "Inventory runtime static gate passed."
    }
    else {
        Write-Host "Inventory runtime static gate failed."
        foreach ($violation in $violations) {
            Write-Host " - $violation"
        }
    }
}

if ($violations.Count -gt 0) {
    exit 2
}
