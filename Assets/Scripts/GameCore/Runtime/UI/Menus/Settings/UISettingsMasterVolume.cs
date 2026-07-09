using UnityEngine.Events;

namespace FantasyWord.GameCore
{
    public class UISettingsMasterVolume : UISettingsVolume
    {
        public void RegisterCallbacks(UnityAction decrease, UnityAction increase)
        {
            m_decreaseButton.onClick.AddListener(decrease);
            m_increaseButton.onClick.AddListener(increase);
        }
    }
}

