using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.U2D.Animation;
using azixMcAze.SerializableDictionary;

namespace FantasyWord.GameCore
{
    public class UIControllerButtonManager : MonoBehaviour
    {
        public enum EControllerType
        {
            Keyboard,
            XBOX,
            Playstation
        }

        public enum EAction
        {
            Interact,
            FireAbility1,
            FireAbility2,
            FireAbility3,
            FireAbility4,
            FireAbility5,
            OpenGameMenu,
            Submit,
            Cancel
        }

        public enum EButtonState
        {
            Idle,
            Pressed
        }

        [SerializeField] private SerializableDictionary<EControllerType, SpriteLibraryAsset> m_controllerSpriteLibraries = null;

        private HashSet<UIControllerButton> m_buttons = new();
        private EControllerType m_controllerType;

        private void Start()
        {
            UpdateControllerType();
            GameManager.InputSystem.AddControlsChangedListener(UpdateControllerType);
        }

        private void OnDestroy()
        {
            GameManager.InputSystem.RemoveControlsChangedListener(UpdateControllerType);
        }

        private void UpdateControllerType()
        {
            string devices = GameManager.InputSystem.GetCurrentControlDevicesSignature();

            if (devices.Contains("xinput"))
            {
                SetControllerType(EControllerType.XBOX);
            }
            else if (devices.Contains("dualsense"))
            {
                SetControllerType(EControllerType.Playstation);
            }
            else if (devices.Contains("keyboard"))
            {
                SetControllerType(EControllerType.Keyboard);
            }
        }

        public void RegisterButton(UIControllerButton button)
        {
            m_buttons.Add(button);
            UpdateButton(button);
        }

        public void UnregisterButton(UIControllerButton button)
        {
            m_buttons.Remove(button);
        }

        private void SetControllerType(EControllerType controllerType)
        {
            Debug.Log($"Controller set to {controllerType}");
            m_controllerType = controllerType;
            UpdateControllerButtons();
        }

        private void UpdateControllerButtons()
        {
            foreach (UIControllerButton button in m_buttons)
            {
                UpdateButton(button);
            }
        }

        private bool IsActionPressed(EAction action)
        {
            switch (action)
            {
                case EAction.Interact: return GameManager.InputSystem.IsGameplayActionPressed(EGameplayInputAction.Interact);
                case EAction.FireAbility1: return GameManager.InputSystem.IsGameplayActionPressed(EGameplayInputAction.FireAbility1);
                case EAction.FireAbility2: return GameManager.InputSystem.IsGameplayActionPressed(EGameplayInputAction.FireAbility2);
                case EAction.FireAbility3: return GameManager.InputSystem.IsGameplayActionPressed(EGameplayInputAction.FireAbility3);
                case EAction.FireAbility4: return GameManager.InputSystem.IsGameplayActionPressed(EGameplayInputAction.FireAbility4);
                case EAction.FireAbility5: return GameManager.InputSystem.IsGameplayActionPressed(EGameplayInputAction.FireAbility5);
                case EAction.OpenGameMenu: return GameManager.InputSystem.IsGameplayActionPressed(EGameplayInputAction.OpenGameMenu);
                case EAction.Submit: return GameManager.InputSystem.IsUIActionPressed(EUIInputAction.Submit);
                case EAction.Cancel: return GameManager.InputSystem.IsUIActionPressed(EUIInputAction.Cancel);
            }

            return false;
        }

        public void ForceUpdateButton(UIControllerButton button)
        {
            UpdateButton(button);
        }

        private void UpdateButton(UIControllerButton button)
        {
            SpriteLibraryAsset currentLibrary = m_controllerSpriteLibraries[m_controllerType];

            Dictionary<EButtonState, Sprite> sprites = new();

            foreach (EButtonState state in Enum.GetValues(typeof(EButtonState)).Cast<EButtonState>())
            {
                Sprite sprite = currentLibrary.GetSprite(button.action.ToString(), state.ToString());
                sprites.Add(state, sprite);
            }

            // 按钮提示只读取 InputSystem 的正式动作状态，不再持有原始 InputAction 本体。
            button.Initialize(sprites, () => IsActionPressed(button.action));
        }
    }
}
