using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    public interface ISaveFileEventReceiver
    {
        void HandleSaveFileClicked(SaveFileActionDesc desc);
    }

    public enum SaveFileActionType
    {
        Save,
        Load
    }

    /// <summary>
    /// 存档按钮点击后传给父级菜单的正式动作描述。
    /// 这里只表达“对哪个槽位做什么”，不承担存档系统真相。
    /// </summary>
    public struct SaveFileActionDesc
    {
        public SaveFileActionType action;
        public string filename;
    }

    public class UISaveFile : MonoBehaviour
    {
        [Header("Settings")]
        [SerializeField] private SaveFileActionType m_action = SaveFileActionType.Load;
        [SerializeField] private string m_saveFileName = null;

        [Header("References")]
        [SerializeField] private TextMeshProUGUI m_details = null;
        [SerializeField] private Button m_button = null;

        private bool m_isEmpty;
        private ISaveFileEventReceiver m_receiver = null;

        private void Awake()
        {
            m_receiver = GetComponentInParent<ISaveFileEventReceiver>();
            Debug.Assert(m_receiver != null, $"{nameof(UISaveFile)} requires a parent implementing {nameof(ISaveFileEventReceiver)}.");
            m_button.onClick.AddListener(OnClick);
        }

        public void UpdateUI()
        {
            SaveDataBlock saveData = SaveSystem.ExtractSaveDataFromFile(m_saveFileName);

            if (saveData != null)
            {
                m_details.text = saveData.header;
                m_isEmpty = false;
            }
            else
            {
                m_details.text = "Empty";
                m_isEmpty = true;

                if (m_action == SaveFileActionType.Load)
                {
                    m_button.interactable = false;
                }
            }
        }

        public bool CanEraseSaveData() => !m_isEmpty;

        public void EraseSaveData()
        {
            SaveSystem.EraseSaveData(m_saveFileName);
        }

        public void OnClick()
        {
            m_receiver.HandleSaveFileClicked(new SaveFileActionDesc
            {
                action = m_action,
                filename = m_saveFileName

            });
        }
    }
}

