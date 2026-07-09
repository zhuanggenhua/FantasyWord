using System.Collections.Generic;
using UnityEngine;

namespace FantasyWord.GameCore
{
    [CreateAssetMenu(menuName = AssetMenuIndexer.FantasyWord_Crafting + nameof(CraftingStation))]
    public class CraftingStation : DatabaseEntry
    {
        [SerializeField] private Recipe[] m_recipes = null;
        [SerializeField] private float m_priceMultiplier = 1.0f;
        [SerializeField] private int m_flatPrice = 0;

        public int recipeCount => m_recipes?.Length ?? 0;
        public Recipe GetRecipeAt(int index) => index >= 0 && index < recipeCount ? m_recipes[index] : null;
        public Recipe[] GetRecipes() => m_recipes != null ? (Recipe[])m_recipes.Clone() : System.Array.Empty<Recipe>();

        public int GetCraftingCost(Recipe recipe)
        {
            return recipe.CalculateCraftCost(m_flatPrice, m_priceMultiplier);
        }

        public bool CanCraft(Recipe recipe, out bool hasMoney, out bool hasIngredients)
        {
            return CanCraft(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance(), recipe, out hasMoney, out hasIngredients);
        }

        public bool CanCraft(CharacterBase owner, Recipe recipe, out bool hasMoney, out bool hasIngredients)
        {
            return recipe.CanCraft(owner, out hasMoney, out hasIngredients, m_flatPrice, m_priceMultiplier);
        }

        public void Craft(Recipe recipe)
        {
            Craft(GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance(), recipe);
        }

        public void Craft(CharacterBase owner, Recipe recipe)
        {
            int craftCost = recipe.CalculateCraftCost(m_flatPrice, m_priceMultiplier);
            InventoryOwnerHandle ownerHandle = GameManager.InventorySystem.GetOwner(owner);
            GameManager.InventorySystem.RemoveMoney(craftCost);

            foreach (var requirement in recipe.GetIngredients())
            {
                GameManager.InventorySystem.RemoveFromBag(ownerHandle, requirement.Key, requirement.Value, EItemTransferType.Crafting);
            }

            GameManager.InventorySystem.AddToBag(ownerHandle, recipe.item, recipe.quantity, EItemTransferType.Crafting);

            foreach (var entry in recipe.GetAdditionalOutput())
            {
                Debug.Assert(entry.Value > 0, $"Invalid provided quantity ({entry.Value}). Expected quantity > 0");
                GameManager.InventorySystem.AddToBag(ownerHandle, entry.Key, entry.Value, EItemTransferType.Crafting);
            }
        }
    }
}
