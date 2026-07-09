using System.Threading.Tasks;

namespace FantasyWord.GameCore
{
    public readonly struct MenuRequestedEvent
    {
        public MenuRequestedEvent(EMenu menu, TaskCompletionSource<bool> menuClosedTask)
        {
            Menu = menu;
            MenuClosedTask = menuClosedTask;
        }

        public EMenu Menu { get; }

        public TaskCompletionSource<bool> MenuClosedTask { get; }
    }

    public readonly struct ShopRequestedEvent
    {
        public ShopRequestedEvent(Shop shop, TaskCompletionSource<bool> menuClosedTask)
            : this(shop, GameCommandContext.Unknown(), menuClosedTask)
        {
        }

        public ShopRequestedEvent(Shop shop, GameCommandContext commandContext, TaskCompletionSource<bool> menuClosedTask)
        {
            Shop = shop;
            CommandContext = commandContext;
            MenuClosedTask = menuClosedTask;
        }

        public Shop Shop { get; }

        public GameCommandContext CommandContext { get; }

        public TaskCompletionSource<bool> MenuClosedTask { get; }
    }

    public readonly struct InventoryMenuRequestedEvent
    {
        public InventoryMenuRequestedEvent(InventoryMenuContext context, TaskCompletionSource<bool> menuClosedTask)
        {
            Context = context;
            MenuClosedTask = menuClosedTask;
        }

        public InventoryMenuContext Context { get; }

        public TaskCompletionSource<bool> MenuClosedTask { get; }
    }

    public readonly struct CharacterMenuRequestedEvent
    {
        public CharacterMenuRequestedEvent(CharacterMenuContext context, TaskCompletionSource<bool> menuClosedTask)
        {
            Context = context;
            MenuClosedTask = menuClosedTask;
        }

        public CharacterMenuContext Context { get; }

        public TaskCompletionSource<bool> MenuClosedTask { get; }
    }

    public readonly struct AbilitiesMenuRequestedEvent
    {
        public AbilitiesMenuRequestedEvent(CharacterMenuContext context, TaskCompletionSource<bool> menuClosedTask)
        {
            Context = context;
            MenuClosedTask = menuClosedTask;
        }

        public CharacterMenuContext Context { get; }

        public TaskCompletionSource<bool> MenuClosedTask { get; }
    }

    public readonly struct CraftRequestedEvent
    {
        public CraftRequestedEvent(CraftingStation craftingStation, TaskCompletionSource<bool> menuClosedTask)
            : this(craftingStation, GameCommandContext.Unknown(), menuClosedTask)
        {
        }

        public CraftRequestedEvent(CraftingStation craftingStation, GameCommandContext commandContext, TaskCompletionSource<bool> menuClosedTask)
        {
            CraftingStation = craftingStation;
            CommandContext = commandContext;
            MenuClosedTask = menuClosedTask;
        }

        public CraftingStation CraftingStation { get; }

        public GameCommandContext CommandContext { get; }

        public TaskCompletionSource<bool> MenuClosedTask { get; }
    }

    public readonly struct CloseAllMenusRequestedEvent
    {
    }

    public readonly struct ItemDetailsOpenedEvent
    {
        public ItemDetailsOpenedEvent(Item item)
        {
            Item = item;
        }

        public Item Item { get; }
    }

    public readonly struct ItemDetailsClosedEvent
    {
    }

    public static partial class GameRuntimeEvents
    {
        public static void RequestMenu(EMenu menu, TaskCompletionSource<bool> menuClosedTask = null)
        {
            Publish(new MenuRequestedEvent(menu, menuClosedTask));
        }

        public static void RequestShop(Shop shop, TaskCompletionSource<bool> menuClosedTask = null)
        {
            RequestShop(shop, GameCommandContext.Unknown(), menuClosedTask);
        }

        public static void RequestShop(Shop shop, GameCommandContext commandContext, TaskCompletionSource<bool> menuClosedTask = null)
        {
            if (!shop)
            {
                return;
            }

            Publish(new ShopRequestedEvent(shop, commandContext, menuClosedTask));
        }

        public static void RequestInventory(InventoryMenuContext context, TaskCompletionSource<bool> menuClosedTask = null)
        {
            Publish(new InventoryMenuRequestedEvent(context, menuClosedTask));
        }

        public static void RequestCharacterMenu(CharacterMenuContext context, TaskCompletionSource<bool> menuClosedTask = null)
        {
            Publish(new CharacterMenuRequestedEvent(context, menuClosedTask));
        }

        public static void RequestAbilitiesMenu(CharacterMenuContext context, TaskCompletionSource<bool> menuClosedTask = null)
        {
            Publish(new AbilitiesMenuRequestedEvent(context, menuClosedTask));
        }

        public static void RequestCraft(CraftingStation craftingStation, TaskCompletionSource<bool> menuClosedTask = null)
        {
            RequestCraft(craftingStation, GameCommandContext.Unknown(), menuClosedTask);
        }

        public static void RequestCraft(CraftingStation craftingStation, GameCommandContext commandContext, TaskCompletionSource<bool> menuClosedTask = null)
        {
            if (!craftingStation)
            {
                return;
            }

            Publish(new CraftRequestedEvent(craftingStation, commandContext, menuClosedTask));
        }

        public static void RequestCloseAllMenus()
        {
            Publish(new CloseAllMenusRequestedEvent());
        }

        public static void NotifyItemDetailsOpened(Item item)
        {
            if (!item)
            {
                NotifyItemDetailsClosed();
                return;
            }

            Publish(new ItemDetailsOpenedEvent(item));
        }

        public static void NotifyItemDetailsClosed()
        {
            Publish(new ItemDetailsClosedEvent());
        }
    }
}
