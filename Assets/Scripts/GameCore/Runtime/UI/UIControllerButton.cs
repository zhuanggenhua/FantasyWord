using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    public class UIControllerButton : MonoBehaviour
    {
        [SerializeField] private Image m_image = null;
        [SerializeField] private SpriteRenderer m_spriteRenderer = null;
        [SerializeField] private UIControllerButtonManager.EAction m_action;

        private Dictionary<UIControllerButtonManager.EButtonState, Sprite> m_sprites;
        private Func<bool> m_isPressed = null;
        private UIControllerButtonManager m_manager = null;

        public UIControllerButtonManager.EAction action => m_action;

        private void Start()
        {
            m_manager = ResolveManager();
            m_manager?.RegisterButton(this);
        }

        private void OnDestroy()
        {
            m_manager?.UnregisterButton(this);
        }

        private void Update()
        {
            if (m_sprites != null)
            {
                Sprite sprite = m_sprites[GetCurrentButtonState()];

                if (m_image) m_image.sprite = sprite;
                if (m_spriteRenderer) m_spriteRenderer.sprite = sprite;
            }
        }

        private UIControllerButtonManager.EButtonState GetCurrentButtonState()
        {
            if (m_isPressed != null)
            {
                return
                    m_isPressed() ?
                    UIControllerButtonManager.EButtonState.Pressed :
                    UIControllerButtonManager.EButtonState.Idle;
            }

            return UIControllerButtonManager.EButtonState.Idle;
        }

        public void Initialize(Dictionary<UIControllerButtonManager.EButtonState, Sprite> sprites, Func<bool> isPressed = null)
        {
            m_sprites = sprites;
            m_isPressed = isPressed;
        }

        public void SetAction(UIControllerButtonManager.EAction action)
        {
            m_action = action;
            m_manager ??= ResolveManager();
            m_manager?.ForceUpdateButton(this);
        }

        private UIControllerButtonManager ResolveManager()
        {
            Canvas canvasRoot = GetComponentInParent<Canvas>(true);
            if (canvasRoot == null)
            {
                return GetComponentInParent<UIControllerButtonManager>(true);
            }

            // 控制器提示按钮只在当前正式 UI 根内解析管理器，避免再依赖全局静态单例。
            return canvasRoot.GetComponentInChildren<UIControllerButtonManager>(true);
        }
    }
}
