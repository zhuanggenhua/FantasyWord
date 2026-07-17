using System;
using TMPro;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

[DisallowMultipleComponent]
public sealed class EquipmentWorkbenchIconSlotView : MonoBehaviour
{
    [SerializeField] Button button;
    [SerializeField] Image background;
    [SerializeField] Outline outline;
    [SerializeField] Image iconFrame;
    [SerializeField] Image iconImage;
    [SerializeField] TextMeshProUGUI nameLabel;
    [SerializeField] GameObject badgeRoot;
    [SerializeField] Image badgeBackground;
    [SerializeField] TextMeshProUGUI badgeLabel;

    UnityAction currentClickListener;

    const float IconFrameSidePadding = 10f;
    const float IconFrameNameReserve = 28f;
    const float IconImageInset = 0f;
    const float NameLabelHeight = 20f;
    const float PreferredIconFrameSize = 68f;
    const float MinIconFrameSize = 52f;
    const float MinIconImageSize = 48f;

    public void Bind(
        string title,
        Sprite icon,
        TMP_FontAsset font,
        Color textColor,
        Color backgroundColor,
        Color outlineColor,
        Color iconFrameColor,
        Color emptyIconColor,
        string badgeText,
        Color badgeFillColor,
        Color badgeTextColor,
        UnityAction onClick,
        bool interactable = true)
    {
        EnsureReferences();

        if (button == null || background == null || iconImage == null || nameLabel == null)
        {
            Debug.LogError($"{nameof(EquipmentWorkbenchIconSlotView)} 引用未绑定。", this);
            return;
        }

        background.color = backgroundColor;
        background.raycastTarget = true;
        if (outline != null)
            outline.effectColor = outlineColor;
        if (iconFrame != null)
        {
            iconFrame.color = iconFrameColor;
            iconFrame.raycastTarget = false;
        }

        iconImage.enabled = icon != null;
        iconImage.sprite = icon;
        iconImage.color = icon != null ? Color.white : emptyIconColor;
        iconImage.preserveAspect = true;
        iconImage.type = Image.Type.Simple;
        iconImage.maskable = false;
        iconImage.raycastTarget = false;

        nameLabel.text = title ?? string.Empty;
        nameLabel.font = font;
        nameLabel.color = textColor;
        nameLabel.enableAutoSizing = true;
        nameLabel.fontSizeMin = 10f;
        nameLabel.fontSizeMax = 14f;
        nameLabel.textWrappingMode = TextWrappingModes.Normal;
        nameLabel.overflowMode = TextOverflowModes.Ellipsis;
        nameLabel.raycastTarget = false;
        ConfigureNameLabelBounds(nameLabel.rectTransform);

        RectTransform slotRect = transform as RectTransform;
        if (slotRect != null)
        {
            float slotWidth = slotRect.rect.width > 0f ? slotRect.rect.width : slotRect.sizeDelta.x;
            float slotHeight = slotRect.rect.height > 0f ? slotRect.rect.height : slotRect.sizeDelta.y;
            float frameSize = CalculateIconFrameSize(slotWidth, slotHeight);

            if (iconFrame != null && iconFrame.rectTransform != null)
                iconFrame.rectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, frameSize);
            if (iconFrame != null && iconFrame.rectTransform != null)
                iconFrame.rectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, frameSize);

            if (iconImage != null && iconImage.rectTransform != null)
            {
                Vector2 imageSize = CalculateIconImageSize(frameSize, icon);
                iconImage.rectTransform.anchorMin = new Vector2(0.5f, 0.5f);
                iconImage.rectTransform.anchorMax = new Vector2(0.5f, 0.5f);
                iconImage.rectTransform.pivot = new Vector2(0.5f, 0.5f);
                iconImage.rectTransform.anchoredPosition = Vector2.zero;
                iconImage.rectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, imageSize.x);
                iconImage.rectTransform.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical, imageSize.y);
            }
        }

        bool showBadge = !string.IsNullOrWhiteSpace(badgeText);
        if (badgeRoot != null)
            badgeRoot.SetActive(showBadge);
        if (showBadge)
        {
            if (badgeBackground != null)
                badgeBackground.color = badgeFillColor;
            if (badgeLabel != null)
            {
                badgeLabel.text = badgeText;
                badgeLabel.font = font;
                badgeLabel.color = badgeTextColor;
                badgeLabel.enableAutoSizing = true;
                badgeLabel.fontSizeMin = 9f;
                badgeLabel.fontSizeMax = 11f;
                badgeLabel.raycastTarget = false;
            }
        }

        button.interactable = interactable;
        ClearClickListener();
        if (interactable && onClick != null)
        {
            currentClickListener = onClick;
            button.onClick.AddListener(currentClickListener);
        }
    }

    void OnDisable()
    {
        ClearClickListener();
    }

    void OnDestroy()
    {
        ClearClickListener();
    }

    void ClearClickListener()
    {
        if (button != null && currentClickListener != null)
            button.onClick.RemoveListener(currentClickListener);
        currentClickListener = null;
    }

    void EnsureReferences()
    {
        if (button == null)
            button = GetComponent<Button>() ?? gameObject.AddComponent<Button>();
        if (background == null)
            background = GetComponent<Image>() ?? gameObject.AddComponent<Image>();
        if (outline == null)
            outline = GetComponent<Outline>();

        ResolveIconImagesFromNamedChildren();
        if (iconFrame == null || iconImage == null)
            ResolveIconImagesFromChildren();

        if (iconFrame == null)
            iconFrame = CreateChildImage("Icon Frame", transform as RectTransform, new Vector2(0f, 12f));
        if (iconImage == null)
            iconImage = CreateChildImage("Icon", iconFrame.transform as RectTransform, Vector2.zero);
        if (nameLabel == null)
            nameLabel = GetComponentInChildren<TextMeshProUGUI>(true);
        if (nameLabel == null)
            nameLabel = CreateNameLabel();

        if (button.targetGraphic == null)
            button.targetGraphic = background;
    }

    void ResolveIconImagesFromNamedChildren()
    {
        Image namedFrame = FindChildImageByName("IconFrame") ?? FindChildImageByName("Icon Frame");
        if (namedFrame != null)
            iconFrame = namedFrame;

        Image namedIcon = FindChildImageByName("Icon");
        if (namedIcon != null && namedIcon != iconFrame)
            iconImage = namedIcon;
    }

    Image FindChildImageByName(string childName)
    {
        Image[] images = GetComponentsInChildren<Image>(true);
        for (int i = 0; i < images.Length; i++)
        {
            Image image = images[i];
            if (image == null || image == background)
                continue;

            if (string.Equals(image.name, childName, StringComparison.OrdinalIgnoreCase))
                return image;
        }

        return null;
    }

    void ResolveIconImagesFromChildren()
    {
        Image[] images = GetComponentsInChildren<Image>(true);
        for (int i = 0; i < images.Length; i++)
        {
            Image image = images[i];
            if (image == null || image == background)
                continue;

            if (iconFrame == null)
            {
                iconFrame = image;
                continue;
            }

            if (iconImage == null && image.transform.IsChildOf(iconFrame.transform))
            {
                iconImage = image;
                return;
            }
        }

        if (iconImage == null)
        {
            for (int i = 0; i < images.Length; i++)
            {
                Image image = images[i];
                if (image != null && image != background && image != iconFrame)
                {
                    iconImage = image;
                    return;
                }
            }
        }
    }

    static Image CreateChildImage(string childName, RectTransform parent, Vector2 anchoredPosition)
    {
        GameObject child = new GameObject(childName, typeof(RectTransform), typeof(Image));
        RectTransform rect = child.transform as RectTransform;
        rect.SetParent(parent, false);
        rect.anchorMin = new Vector2(0.5f, 0.5f);
        rect.anchorMax = new Vector2(0.5f, 0.5f);
        rect.pivot = new Vector2(0.5f, 0.5f);
        rect.anchoredPosition = anchoredPosition;
        rect.sizeDelta = new Vector2(PreferredIconFrameSize, PreferredIconFrameSize);
        return child.GetComponent<Image>();
    }

    TextMeshProUGUI CreateNameLabel()
    {
        GameObject child = new GameObject("Name Label", typeof(RectTransform), typeof(TextMeshProUGUI));
        RectTransform rect = child.transform as RectTransform;
        rect.SetParent(transform, false);
        TextMeshProUGUI label = child.GetComponent<TextMeshProUGUI>();
        label.alignment = TextAlignmentOptions.Center;
        ConfigureNameLabelBounds(rect);
        return label;
    }

    static float CalculateIconFrameSize(float slotWidth, float slotHeight)
    {
        float safeSlotWidth = slotWidth > 1f ? slotWidth : PreferredIconFrameSize + IconFrameSidePadding;
        float safeSlotHeight = slotHeight > 1f ? slotHeight : PreferredIconFrameSize + IconFrameNameReserve;
        float availableWidth = Mathf.Max(MinIconFrameSize, safeSlotWidth - IconFrameSidePadding);
        float availableHeight = Mathf.Max(MinIconFrameSize, safeSlotHeight - IconFrameNameReserve);
        return Mathf.Min(PreferredIconFrameSize, availableWidth, availableHeight);
    }

    static Vector2 CalculateIconImageSize(float frameSize, Sprite icon)
    {
        float maxSize = Mathf.Max(MinIconImageSize, frameSize - IconImageInset * 2f);
        return new Vector2(maxSize, maxSize);
    }

    static void ConfigureNameLabelBounds(RectTransform nameRect)
    {
        if (nameRect == null)
            return;

        nameRect.anchorMin = new Vector2(0f, 0f);
        nameRect.anchorMax = new Vector2(1f, 0f);
        nameRect.pivot = new Vector2(0.5f, 0f);
        nameRect.anchoredPosition = new Vector2(0f, 4f);
        nameRect.sizeDelta = new Vector2(-12f, NameLabelHeight);
    }

    void Reset()
    {
        button = GetComponent<Button>();
        background = GetComponent<Image>();
        outline = GetComponent<Outline>();

        if (transform.childCount > 0)
        {
            iconFrame = transform.GetChild(0).GetComponent<Image>();
            if (transform.GetChild(0).childCount > 0)
                iconImage = transform.GetChild(0).GetChild(0).GetComponent<Image>();
        }

        nameLabel = GetComponentInChildren<TextMeshProUGUI>(true);
    }
}
