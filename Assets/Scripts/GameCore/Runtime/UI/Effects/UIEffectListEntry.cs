using Sirenix.OdinInspector;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 效果列表条目被悬停或选中时传给父级列表的事件载荷。
    /// </summary>
    public struct EffectHoveredEvent
    {
        /// <summary>
        /// 当前条目展示的持续效果快照。
        /// </summary>
        public CharacterTemporalEffectPresentationSnapshot effect;

        /// <summary>
        /// 条目在屏幕中的 Y 坐标，用于父级定位详情面板。
        /// </summary>
        public float listElementY;
    }

    /// <summary>
    /// 单个持续效果 UI 条目，负责展示图标/简称并把悬停状态通知父级列表。
    /// </summary>
    public class UIEffectListEntry : MonoBehaviour, IPointerEnterHandler, ISelectHandler, IDeselectHandler
    {
        [SerializeField]
        [LabelText("图标")]
        [Tooltip("展示持续效果图标的 Image。")]
        private Image m_icon = null;

        [SerializeField]
        [LabelText("文本")]
        [Tooltip("展示持续效果简称的文本。")]
        private TextMeshProUGUI m_text = null;

        [SerializeField]
        [LabelText("按钮")]
        [Tooltip("用于选择和焦点导航的 Button。")]
        private Button m_button = null;

        private CharacterTemporalEffectPresentationSnapshot m_effect;
        private UIEffectList m_effectList = null;

        /// <summary>
        /// 绑定持续效果快照并刷新条目显示。
        /// </summary>
        public void SetEffect(CharacterTemporalEffectPresentationSnapshot effect)
        {
            m_effectList = GetComponentInParent<UIEffectList>();
            Debug.Assert(m_effectList != null, $"{nameof(UIEffectListEntry)} 需要父级 {nameof(UIEffectList)} 作为效果列表。");
            m_effect = effect;
            m_icon.sprite = effect.Info.Icon;
            m_text.text = effect.Info.ShortName;
        }

        /// <summary>鼠标进入条目时把焦点交给按钮，统一复用选择态详情显示逻辑。</summary>
        public void OnPointerEnter(PointerEventData eventData)
        {
            if (m_button.IsInteractable())
            {
                m_button.Select();
            }
        }

        /// <summary>条目获得焦点时通知父级显示详情面板。</summary>
        public void OnSelect(BaseEventData eventData)
        {
            m_effectList.HandleEffectHovered(new EffectHoveredEvent()
            {
                effect = m_effect,
                listElementY = transform.position.y
            });
        }

        /// <summary>条目失去焦点时通知父级隐藏详情面板。</summary>
        public void OnDeselect(BaseEventData eventData)
        {
            m_effectList.HandleEffectNotHovered();
        }
    }
}
