using TMPro;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

[DisallowMultipleComponent]
public sealed class EquipmentWorkbenchChipButtonView : MonoBehaviour
{
    [SerializeField] Button button;
    [SerializeField] Image background;
    [SerializeField] Outline outline;
    [SerializeField] TextMeshProUGUI label;

    public void Bind(
        string text,
        TMP_FontAsset font,
        Color textColor,
        Color backgroundColor,
        Color outlineColor,
        UnityAction onClick,
        bool interactable = true)
    {
        EnsureReferences();

        if (button == null || background == null || label == null)
        {
            Debug.LogError($"{nameof(EquipmentWorkbenchChipButtonView)} 引用未绑定。", this);
            return;
        }

        label.text = text ?? string.Empty;
        label.font = font;
        label.color = textColor;
        label.enableAutoSizing = true;
        label.fontSizeMin = 11f;
        label.fontSizeMax = 16f;
        label.textWrappingMode = TextWrappingModes.NoWrap;
        label.overflowMode = TextOverflowModes.Ellipsis;
        label.raycastTarget = false;

        background.color = backgroundColor;
        background.raycastTarget = true;
        if (outline != null)
            outline.effectColor = outlineColor;

        if (button.targetGraphic == null)
            button.targetGraphic = background;
        button.interactable = interactable;
        button.onClick.RemoveAllListeners();
        if (interactable && onClick != null)
            button.onClick.AddListener(onClick);
    }

    void EnsureReferences()
    {
        if (button == null)
            button = GetComponent<Button>() ?? gameObject.AddComponent<Button>();
        if (background == null)
            background = GetComponent<Image>() ?? gameObject.AddComponent<Image>();
        if (outline == null)
            outline = GetComponent<Outline>();
        if (label == null)
            label = GetComponentInChildren<TextMeshProUGUI>(true);
        if (label == null)
            label = CreateLabel();
    }

    TextMeshProUGUI CreateLabel()
    {
        GameObject child = new GameObject("Label", typeof(RectTransform), typeof(TextMeshProUGUI));
        RectTransform rect = child.transform as RectTransform;
        rect.SetParent(transform, false);
        rect.anchorMin = Vector2.zero;
        rect.anchorMax = Vector2.one;
        rect.offsetMin = new Vector2(6f, 2f);
        rect.offsetMax = new Vector2(-6f, -2f);

        TextMeshProUGUI createdLabel = child.GetComponent<TextMeshProUGUI>();
        createdLabel.alignment = TextAlignmentOptions.Center;
        createdLabel.raycastTarget = false;
        return createdLabel;
    }

    void Reset()
    {
        button = GetComponent<Button>();
        background = GetComponent<Image>();
        outline = GetComponent<Outline>();
        label = GetComponentInChildren<TextMeshProUGUI>(true);
    }
}
