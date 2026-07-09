using TMPro;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public class UIEffectDescription : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private TextMeshProUGUI m_text = null;

        [Header("Settings")]
        [SerializeField] private int m_maxLineCount = 1;

        public int maxLineCount => m_maxLineCount;

        public void Show(CharacterTemporalEffectPresentationSnapshot effect, float positionY)
        {
            transform.position = new(transform.position.x, positionY, transform.position.z);
            m_text.text = GenerateDescription(effect);
            gameObject.SetActive(true);
        }

        public void Hide()
        {
            gameObject.SetActive(false);
        }

        private static string GenerateDescription(CharacterTemporalEffectPresentationSnapshot effect)
        {
            return effect.Details;
        }
    }
}

