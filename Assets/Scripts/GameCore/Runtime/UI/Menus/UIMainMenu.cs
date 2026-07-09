using System;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    public class UIMainMenu : MonoBehaviour, ISaveFileEventReceiver
    {
        [Header("Settings")]
        [SerializeField] private Button m_defaultSelectedButton = null;
        [SerializeField] private UISettings m_settingsMenu = null;

        [Header("References")]
        [SerializeField] private UISaveFile[] m_saveFiles = null;
        [SerializeField] private Button[] m_eraseButtons = null;

        private void Start()
        {
            m_settingsMenu.Init();

            GameManager.InputSystem.AddUIActionListener(EUIInputAction.Cancel, EInputActionPhase.Performed, OnCancel);
        }

        private void OnDestroy()
        {
            GameManager.InputSystem.RemoveUIActionListener(EUIInputAction.Cancel, EInputActionPhase.Performed, OnCancel);
        }

        public void OnEnable()
        {
            UpdateUI();
            SelectDefaultButton();
        }

        private void UpdateUI()
        {
            for (int i = 0; i < m_saveFiles.Length; ++i)
            {
                UISaveFile saveFile = m_saveFiles[i];
                Button eraseButton = i < m_eraseButtons.Length ? m_eraseButtons[i] : null;
                saveFile.UpdateUI();
                eraseButton.interactable = saveFile.CanEraseSaveData();
            }
        }

        public void ShowSettingsMenu()
        {
            m_settingsMenu.Show();
        }

        private void OnCancel(UnityEngine.InputSystem.InputAction.CallbackContext context)
        {
            m_settingsMenu.Hide();
        }

        public void StartNewGameFromDefaultSaveFile(SaveFile saveFile)
        {
            LoadScenes(() =>
            {
                GameManager.SaveSystem.LoadDefaultSaveFile(saveFile);
            });
        }

        private void LoadScenes(Action onScenesLoaded)
        {
            SceneManager.LoadSceneAsync(Constants.M2DEngineSceneName).completed += (operation) =>
            {
                onScenesLoaded();
            };
        }

        private void SelectDefaultButton()
        {
            m_defaultSelectedButton.Select();
        }

        public void EraseSaveFile(UISaveFile saveFile)
        {
            saveFile.EraseSaveData();
            UpdateUI();
            SelectDefaultButton();
        }

        public void HandleSaveFileClicked(SaveFileActionDesc desc)
        {
            LoadScenes(() =>
            {
                GameManager.SaveSystem.LoadFromFile(desc.filename);
            });
        }
    }
}

