using UnityEngine.InputSystem;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// Gameplay 动作引用集合。
    /// 这里只描述正式输入根对外公开的动作形状，不承载运行时路由、生命周期或绑定工具逻辑。
    /// </summary>
    public struct GameplayActions
    {
        public InputAction move;
        public InputAction interact;
        public InputAction fireAbility1;
        public InputAction fireAbility2;
        public InputAction fireAbility3;
        public InputAction fireAbility4;
        public InputAction fireAbility5;
        public InputAction openGameMenu;
        public InputAction point;
        public InputAction click;
        public InputAction toggleMovementControlMode;
    }

    /// <summary>
    /// UI 动作引用集合。
    /// 正式 UI 输入语义仍归 InputSystem 所有，这里只定义动作容器形状。
    /// </summary>
    public struct UIActions
    {
        public InputAction submit;
        public InputAction cancel;
        public InputAction click;
        public InputAction navigate;
        public InputAction point;
    }

    public enum EActionMap
    {
        Gameplay,
        UI,
        None
    }

    public enum EGameplayInputAction
    {
        Move,
        Interact,
        FireAbility1,
        FireAbility2,
        FireAbility3,
        FireAbility4,
        FireAbility5,
        OpenGameMenu,
        Point,
        Click,
        ToggleMovementControlMode
    }

    public enum EUIInputAction
    {
        Submit,
        Cancel,
        Click,
        Navigate,
        Point
    }

    public enum EInputActionPhase
    {
        Started,
        Performed,
        Canceled
    }
}
