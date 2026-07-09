using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    public struct EffectHoveredEvent
    {
        public CharacterTemporalEffectPresentationSnapshot effect;
        public float listElementY;
    }

    public class UIEffectListEntry : MonoBehaviour, IPointerEnterHandler, ISelectHandler, IDeselectHandler
    {
        [Header("References")]
        [SerializeField] private Image m_icon = null;
        [SerializeField] private TextMeshProUGUI m_text = null;
        [SerializeField] private Button m_button = null;

        private CharacterTemporalEffectPresentationSnapshot m_effect;
        private UIEffectList m_effectList = null;

        public void SetEffect(CharacterTemporalEffectPresentationSnapshot effect)
        {
            m_effectList = GetComponentInParent<UIEffectList>();
            Debug.Assert(m_effectList != null, $"{nameof(UIEffectListEntry)} 需要父级 {nameof(UIEffectList)} 作为效果列表。");
            m_effect = effect;
            m_icon.sprite = effect.Info.Icon;
            m_text.text = effect.Info.ShortName;
        }

        public void OnPointerEnter(PointerEventData eventData)
        {
            if (m_button.IsInteractable())
            {
                m_button.Select();
            }
        }

        public void OnSelect(BaseEventData eventData)
        {
            m_effectList.HandleEffectHovered(new EffectHoveredEvent()
            {
                effect = m_effect,
                listElementY = transform.position.y
            });
        }

        public void OnDeselect(BaseEventData eventData)
        {
            m_effectList.HandleEffectNotHovered();
        }
    }
}

