using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.Serialization;
using NaughtyAttributes;
using NaughtyAttributes.Editor;
using UnityEditor;
using UnityEngine;
using Object = UnityEngine.Object;

/// <summary>
/// SerializableDictionary 的字典表格绘制器，按 Odin 字典 Inspector 的核心交互显示 key/value 行。
/// </summary>
[CustomPropertyDrawer(typeof(SerializableDictionaryBase), true)]
public class SerializableDictionaryDrawer : PropertyDrawer
{
    private const float ButtonWidth = 17f;
    private const float RowSpacing = 1f;
    private const float HeaderHeight = 15f;
    private const float HorizontalGap = 1f;
    private const float FoldoutArrowWidth = 8f;
    private const float FoldoutValueIndent = 8f;
    private const float ItemVerticalPadding = 0f;
    private const float SeparatorHeight = 1f;
    private const float InlineValueSpacing = 0f;
    private const float FoldoutItemOuterPadding = 0f;
    private const float FoldoutItemInnerPadding = 1f;
    private const float ValuePanelTopSpacing = 0f;
    private const float ValuePanelVerticalPadding = 0f;
    private const float ValuePanelHorizontalPadding = 2f;
    private const float ValuePanelBottomPadding = 0f;
    private const float IconButtonWidth = 20f;
    private const float ManagedReferenceTypeRowHeight = 17f;
    private const float ManagedReferenceChildTopSpacing = 0f;
    private const float CompactListHeaderHeight = 18f;
    private const float CompactListBodyPadding = 2f;
    private const float CompactListRowSpacing = 1f;
    private const float CompactListHandleWidth = 10f;
    private static readonly GUIContent AddButtonContent = new("+");
    private static readonly GUIContent RemoveButtonContent = new("\u00D7");
    private static readonly System.Collections.Generic.HashSet<string> FoldoutStatesInitialized = new();
    private static readonly Dictionary<string, bool> ItemFoldoutStates = new();

    /// <summary>
    /// 供项目内预览窗口统一控制指定字典属性的条目展开态；避免外部工具反射 Drawer 私有静态状态。
    /// </summary>
    public static void SetItemExpandedStates(SerializedProperty dictionaryProperty, bool expanded)
    {
        if (dictionaryProperty == null)
        {
            return;
        }

        dictionaryProperty.isExpanded = true;
        SerializedProperty keysProperty = dictionaryProperty.FindPropertyRelative("keys");
        SerializedProperty valuesProperty = dictionaryProperty.FindPropertyRelative("values");
        int itemCount = Mathf.Max(
            keysProperty?.arraySize ?? 0,
            valuesProperty?.arraySize ?? 0);

        for (int itemIndex = 0; itemIndex < itemCount; itemIndex++)
        {
            ItemFoldoutStates[GetItemStateKey(dictionaryProperty, itemIndex)] = expanded;
        }
    }

    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        SerializedProperty keys = property.FindPropertyRelative(SerializableDictionaryBase.KeysFieldName);
        SerializedProperty values = property.FindPropertyRelative(SerializableDictionaryBase.ValuesFieldName);
        if (keys == null || values == null)
        {
            EditorGUI.LabelField(position, label.text, "SerializableDictionary 数据字段缺失");
            return;
        }

        EditorGUI.BeginProperty(position, label, property);

        DictionaryDrawerSettingsAttribute settings = GetSettings();
        EnsureDefaultFoldoutState(property, settings);
        int count = Mathf.Max(keys.arraySize, values.arraySize);
        string title = label.text;
        Rect foldoutRect = new Rect(position.x, position.y, position.width, EditorGUIUtility.singleLineHeight);
        string countLabel = BuildDictionaryItemCountLabel(count);
        float countWidth = GetDictionaryItemCountWidth(countLabel);
        Rect countRect = new Rect(position.xMax - countWidth, position.y, countWidth, EditorGUIUtility.singleLineHeight);
        Rect addRect = default;
        if (!settings.IsReadOnly)
        {
            addRect = new Rect(position.xMax - ButtonWidth, position.y, ButtonWidth, EditorGUIUtility.singleLineHeight);
            countRect.x -= ButtonWidth + HorizontalGap;
            foldoutRect.width -= ButtonWidth + HorizontalGap;
        }
        foldoutRect.width -= countWidth + HorizontalGap;

        EditorGUI.BeginChangeCheck();

        DrawDictionaryRootChrome(new Rect(position.x, position.y, position.width, EditorGUIUtility.singleLineHeight));
        property.isExpanded = EditorGUI.Foldout(
            new Rect(foldoutRect.x + 1f, foldoutRect.y, foldoutRect.width - 1f, foldoutRect.height),
            property.isExpanded,
            title,
            true,
            GetDictionaryRootFoldoutStyle());
        EditorGUI.LabelField(countRect, countLabel, GetDictionaryItemCountStyle());
        if (!settings.IsReadOnly && DrawDictionaryActionButton(addRect, AddButtonContent))
        {
            int index = keys.arraySize;
            keys.InsertArrayElementAtIndex(index);
            values.InsertArrayElementAtIndex(index);
            ResetProperty(keys.GetArrayElementAtIndex(index));
            ResetProperty(values.GetArrayElementAtIndex(index));
            count = Mathf.Max(keys.arraySize, values.arraySize);
        }

        if (!property.isExpanded)
        {
            if (EditorGUI.EndChangeCheck())
            {
                SyncRuntimeDictionary(property);
            }

            EditorGUI.EndProperty();
            return;
        }

        float y = foldoutRect.yMax + RowSpacing;
        EnsureSameSize(keys, values, count);
        HashSet<string> seenKeys = new HashSet<string>();
        if (settings.DisplayMode == DictionaryDisplayOptions.OneLine)
        {
            Rect headerRect = new Rect(position.x, y, position.width, HeaderHeight);
            DrawHeader(headerRect, settings);
            y += HeaderHeight + RowSpacing;

            for (int i = 0; i < count; i++)
            {
                SerializedProperty key = keys.GetArrayElementAtIndex(i);
                SerializedProperty value = values.GetArrayElementAtIndex(i);
                float rowHeight = Mathf.Max(EditorGUI.GetPropertyHeight(key, true), EditorGUI.GetPropertyHeight(value, true), EditorGUIUtility.singleLineHeight);
                Rect rowRect = new Rect(position.x, y, position.width, rowHeight);
                DrawOneLineRow(rowRect, keys, values, key, value, i, seenKeys, settings);
                y += rowHeight + RowSpacing;
            }
        }
        else
        {
            for (int i = 0; i < count; i++)
            {
                SerializedProperty key = keys.GetArrayElementAtIndex(i);
                SerializedProperty value = values.GetArrayElementAtIndex(i);
                Rect itemRect = new Rect(position.x, y, position.width, GetFoldoutItemHeight(property, key, value, i, settings));
                DrawFoldoutItem(itemRect, property, keys, values, key, value, i, seenKeys, settings);
                y += itemRect.height + RowSpacing;
            }
        }

        if (EditorGUI.EndChangeCheck())
        {
            SyncRuntimeDictionary(property);
        }

        EditorGUI.EndProperty();
    }

    public override float GetPropertyHeight(SerializedProperty property, GUIContent label)
    {
        SerializedProperty keys = property.FindPropertyRelative(SerializableDictionaryBase.KeysFieldName);
        SerializedProperty values = property.FindPropertyRelative(SerializableDictionaryBase.ValuesFieldName);
        if (keys == null || values == null)
        {
            return EditorGUIUtility.singleLineHeight;
        }

        DictionaryDrawerSettingsAttribute settings = GetSettings();
        EnsureDefaultFoldoutState(property, settings);
        float height = EditorGUIUtility.singleLineHeight;
        if (!property.isExpanded)
        {
            return height;
        }

        int count = Mathf.Max(keys.arraySize, values.arraySize);
        if (settings.DisplayMode == DictionaryDisplayOptions.OneLine)
        {
            height += RowSpacing + HeaderHeight + RowSpacing;
            for (int i = 0; i < count; i++)
            {
                SerializedProperty key = keys.GetArrayElementAtIndex(i);
                SerializedProperty value = values.GetArrayElementAtIndex(i);
                height += Mathf.Max(EditorGUI.GetPropertyHeight(key, true), EditorGUI.GetPropertyHeight(value, true), EditorGUIUtility.singleLineHeight) + RowSpacing;
            }
        }
        else
        {
            height += RowSpacing;
            for (int i = 0; i < count; i++)
            {
                SerializedProperty key = keys.GetArrayElementAtIndex(i);
                SerializedProperty value = values.GetArrayElementAtIndex(i);
                height += GetFoldoutItemHeight(property, key, value, i, settings) + RowSpacing;
            }
        }

        return height;
    }

    private static void DrawHeader(Rect rect, DictionaryDrawerSettingsAttribute settings)
    {
        float keyWidth = GetKeyColumnWidth(rect.width, settings);
        Rect keyRect = new Rect(rect.x, rect.y, keyWidth, rect.height);
        Rect valueRect = GetValueRect(rect, keyWidth, settings.IsReadOnly);
        Color separatorColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.028f)
            : new Color(0f, 0f, 0f, 0.044f);
        Rect keyContentRect = new Rect(keyRect.x, keyRect.y - 1f, keyRect.width, keyRect.height);
        Rect valueContentRect = new Rect(valueRect.x, valueRect.y - 1f, valueRect.width, valueRect.height);

        EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - 1f, rect.width, 1f), separatorColor);
        EditorGUI.LabelField(keyContentRect, string.IsNullOrEmpty(settings.KeyLabel) ? "Key" : settings.KeyLabel, GetDictionaryColumnHeaderStyle());
        EditorGUI.LabelField(valueContentRect, string.IsNullOrEmpty(settings.ValueLabel) ? "Value" : settings.ValueLabel, GetDictionaryColumnHeaderStyle());
    }

    private static GUIStyle GetDictionaryRootFoldoutStyle()
    {
        GUIStyle style = new GUIStyle(EditorStyles.foldout)
        {
            fontStyle = FontStyle.Normal,
            clipping = TextClipping.Clip,
            fixedHeight = EditorGUIUtility.singleLineHeight,
            margin = new RectOffset(0, 0, 0, 0),
            padding = new RectOffset(10, 0, 0, 0)
        };

        if (EditorGUIUtility.isProSkin)
        {
            Color textColor = new Color(0.72f, 0.72f, 0.72f, 0.88f);
            style.normal.textColor = textColor;
            style.onNormal.textColor = textColor;
            style.hover.textColor = textColor;
            style.onHover.textColor = textColor;
            style.focused.textColor = textColor;
            style.onFocused.textColor = textColor;
        }

        return style;
    }

    private static string BuildDictionaryItemCountLabel(int count)
    {
        return count == 1 ? "1 item" : $"{count} items";
    }

    private static float GetDictionaryItemCountWidth(string label)
    {
        return Mathf.Max(40f, EditorStyles.miniLabel.CalcSize(new GUIContent(label)).x + 2f);
    }

    private static GUIStyle GetDictionaryItemCountStyle()
    {
        GUIStyle style = new GUIStyle(EditorStyles.miniLabel)
        {
            alignment = TextAnchor.MiddleRight,
            clipping = TextClipping.Clip,
            padding = new RectOffset(0, 0, 0, 0),
            margin = new RectOffset(0, 0, 0, 0)
        };

        if (EditorGUIUtility.isProSkin)
        {
            style.normal.textColor = new Color(0.54f, 0.54f, 0.54f, 0.78f);
        }

        return style;
    }

    private static GUIStyle GetDictionaryColumnHeaderStyle()
    {
        GUIStyle style = new GUIStyle(EditorStyles.miniLabel)
        {
            alignment = TextAnchor.MiddleCenter,
            clipping = TextClipping.Clip,
            fontStyle = FontStyle.Normal,
            padding = new RectOffset(0, 0, 0, 0),
            margin = new RectOffset(0, 0, 0, 0)
        };

        if (EditorGUIUtility.isProSkin)
        {
            style.normal.textColor = new Color(0.63f, 0.63f, 0.63f, 0.77f);
        }

        return style;
    }

    private void DrawOneLineRow(
        Rect rect,
        SerializedProperty keyList,
        SerializedProperty valueList,
        SerializedProperty key,
        SerializedProperty value,
        int index,
        HashSet<string> seenKeys,
        DictionaryDrawerSettingsAttribute settings)
    {
        bool isReadOnly = settings.IsReadOnly;
        float keyWidth = GetKeyColumnWidth(rect.width, settings);
        Rect keyRect = new Rect(rect.x, rect.y, keyWidth, rect.height);
        Rect valueRect = GetValueRect(rect, keyWidth, isReadOnly);
        Rect removeRect = new Rect(rect.xMax - ButtonWidth, rect.y, ButtonWidth, EditorGUIUtility.singleLineHeight);
        Color separatorColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.028f)
            : new Color(0f, 0f, 0f, 0.040f);

        bool duplicate = !seenKeys.Add(GetComparableKey(key));
        Color oldColor = GUI.color;
        if (duplicate)
        {
            GUI.color = new Color(1f, 0.65f, 0.65f, 1f);
        }

        using (new EditorGUI.DisabledScope(isReadOnly))
        {
            DrawInlinePropertyField(keyRect, key, GUIContent.none);
        }

        GUI.color = oldColor;
        using (new EditorGUI.DisabledScope(isReadOnly))
        {
            DrawInlinePropertyField(valueRect, value, GUIContent.none);
        }

        EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - 1f, rect.width, 1f), separatorColor);

        if (!isReadOnly && DrawDictionaryActionButton(removeRect, RemoveButtonContent))
        {
            keyList.DeleteArrayElementAtIndex(index);
            valueList.DeleteArrayElementAtIndex(index);
        }
    }

    private void DrawFoldoutItem(
        Rect rect,
        SerializedProperty dictionaryProperty,
        SerializedProperty keyList,
        SerializedProperty valueList,
        SerializedProperty key,
        SerializedProperty value,
        int index,
        HashSet<string> seenKeys,
        DictionaryDrawerSettingsAttribute settings)
    {
        bool duplicate = !seenKeys.Add(GetComparableKey(key));
        string stateKey = GetItemStateKey(dictionaryProperty, index);
        bool expanded = GetItemExpandedState(stateKey, settings.DisplayMode);

        Rect headerRect = new Rect(
            rect.x + FoldoutItemOuterPadding + FoldoutItemInnerPadding,
            rect.y + FoldoutItemOuterPadding + ItemVerticalPadding,
            rect.width - ((FoldoutItemOuterPadding + FoldoutItemInnerPadding) * 2f),
            EditorGUIUtility.singleLineHeight);
        if (!settings.IsReadOnly)
        {
            headerRect.width -= ButtonWidth + HorizontalGap;
        }

        Rect arrowRect = new Rect(headerRect.x + 1f, headerRect.y, FoldoutArrowWidth, headerRect.height);
        Rect keyPrefixRect = default;
        float keyPrefixWidth = GetFoldoutKeyPrefixWidth(settings);
        Rect keyFieldRect = new Rect(
            arrowRect.xMax + 1f + keyPrefixWidth,
            headerRect.y,
            headerRect.xMax - (arrowRect.xMax + 1f + keyPrefixWidth),
            headerRect.height);
        Rect removeRect = new Rect(
            rect.xMax - FoldoutItemOuterPadding - FoldoutItemInnerPadding - ButtonWidth,
            headerRect.y,
            ButtonWidth,
            EditorGUIUtility.singleLineHeight);

        DrawFoldoutItemChrome(rect, headerRect, expanded);
        expanded = EditorGUI.Foldout(arrowRect, expanded, GUIContent.none, true);
        if (keyPrefixWidth > 0f)
        {
            keyPrefixRect = new Rect(arrowRect.xMax + 2f, headerRect.y + 1f, keyPrefixWidth - 2f, headerRect.height - 2f);
            DrawFoldoutKeyPrefix(keyPrefixRect, GetFoldoutKeyPrefixLabel(settings));
        }

        if (duplicate)
        {
            DrawDuplicateKeyBackground(keyFieldRect);
        }

        using (new EditorGUI.DisabledScope(settings.IsReadOnly))
        {
            DrawInlinePropertyField(keyFieldRect, key, GUIContent.none);
        }

        if (duplicate)
        {
            DrawDuplicateKeyOverlay(keyFieldRect);
        }

        ItemFoldoutStates[stateKey] = expanded;

        if (!settings.IsReadOnly && DrawDictionaryActionButton(removeRect, RemoveButtonContent))
        {
            keyList.DeleteArrayElementAtIndex(index);
            valueList.DeleteArrayElementAtIndex(index);
            ItemFoldoutStates.Remove(stateKey);
            return;
        }

        if (!expanded)
        {
            return;
        }

        Rect valuePanelRect = GetExpandedValuePanelRect(rect, headerRect, value);
        bool drawOuterValuePanelChrome = ShouldDrawOuterValuePanelChrome(value);
        if (drawOuterValuePanelChrome)
        {
            DrawExpandedValuePanelChrome(valuePanelRect);
        }

        float horizontalPadding = drawOuterValuePanelChrome ? ValuePanelHorizontalPadding : 0f;

        using (new EditorGUI.DisabledScope(settings.IsReadOnly))
        {
            DrawExpandedValue(
                new Rect(
                    valuePanelRect.x + horizontalPadding,
                    valuePanelRect.y + ValuePanelVerticalPadding,
                    valuePanelRect.width - (horizontalPadding * 2f),
                    GetExpandedValueHeight(value)),
                value,
                settings);
        }
    }

    private static string GetComparableKey(SerializedProperty property)
    {
        return property.propertyType switch
        {
            SerializedPropertyType.String => property.stringValue,
            SerializedPropertyType.Integer => property.longValue.ToString(),
            SerializedPropertyType.Boolean => property.boolValue.ToString(),
            SerializedPropertyType.Float => property.doubleValue.ToString("R"),
            SerializedPropertyType.Enum => property.enumValueIndex.ToString(),
            SerializedPropertyType.ObjectReference => property.objectReferenceValue == null ? "null" : property.objectReferenceValue.GetHashCode().ToString(),
            _ => property.propertyPath + ":" + property.displayName,
        };
    }

    private static void EnsureSameSize(SerializedProperty keyList, SerializedProperty valueList, int count)
    {
        while (keyList.arraySize < count) keyList.InsertArrayElementAtIndex(keyList.arraySize);
        while (valueList.arraySize < count) valueList.InsertArrayElementAtIndex(valueList.arraySize);
        while (keyList.arraySize > count) keyList.DeleteArrayElementAtIndex(keyList.arraySize - 1);
        while (valueList.arraySize > count) valueList.DeleteArrayElementAtIndex(valueList.arraySize - 1);
    }

    private static void ResetProperty(SerializedProperty property)
    {
        switch (property.propertyType)
        {
            case SerializedPropertyType.Integer:
                property.intValue = 0;
                break;
            case SerializedPropertyType.Boolean:
                property.boolValue = false;
                break;
            case SerializedPropertyType.Float:
                property.floatValue = 0f;
                break;
            case SerializedPropertyType.String:
                property.stringValue = string.Empty;
                break;
            case SerializedPropertyType.Enum:
                property.enumValueIndex = 0;
                break;
            case SerializedPropertyType.ObjectReference:
                property.objectReferenceValue = null;
                break;
            case SerializedPropertyType.ManagedReference:
                property.managedReferenceValue = null;
                break;
        }
    }

    private static float GetKeyColumnWidth(float totalWidth, DictionaryDrawerSettingsAttribute settings)
    {
        float buttonSpace = settings.IsReadOnly ? 0f : ButtonWidth + HorizontalGap;
        float availableWidth = totalWidth - buttonSpace - HorizontalGap;
        if (settings.KeyColumnWidth > 0f)
        {
            return Mathf.Clamp(settings.KeyColumnWidth, 60f, Mathf.Max(60f, availableWidth - 80f));
        }

        return availableWidth * 0.45f;
    }

    private static Rect GetValueRect(Rect rect, float keyWidth, bool isReadOnly)
    {
        float buttonSpace = isReadOnly ? 0f : ButtonWidth + HorizontalGap;
        float valueWidth = rect.width - keyWidth - buttonSpace - HorizontalGap;
        return new Rect(rect.x + keyWidth + HorizontalGap, rect.y, valueWidth, rect.height);
    }

    private static float GetFoldoutKeyPrefixWidth(DictionaryDrawerSettingsAttribute settings)
    {
        string keyPrefix = GetFoldoutKeyPrefixLabel(settings);
        if (string.IsNullOrWhiteSpace(keyPrefix))
        {
            return 0f;
        }

        float width = EditorStyles.miniLabel.CalcSize(new GUIContent(keyPrefix)).x + 4f;
        return Mathf.Clamp(width, 16f, 46f);
    }

    private static string GetFoldoutKeyPrefixLabel(DictionaryDrawerSettingsAttribute settings)
    {
        return string.IsNullOrWhiteSpace(settings?.KeyLabel) ? "Key" : settings.KeyLabel;
    }

    private static float GetFoldoutItemHeight(
        SerializedProperty dictionaryProperty,
        SerializedProperty key,
        SerializedProperty value,
        int index,
        DictionaryDrawerSettingsAttribute settings)
    {
        float height = EditorGUIUtility.singleLineHeight
            + (ItemVerticalPadding * 2f)
            + SeparatorHeight
            + (FoldoutItemOuterPadding * 2f)
            + 2f;
        string stateKey = GetItemStateKey(dictionaryProperty, index);
        if (!GetItemExpandedState(stateKey, settings.DisplayMode))
        {
            return height;
        }

        height += ValuePanelTopSpacing;
        height += ValuePanelVerticalPadding;
        height += GetExpandedValueHeight(value);
        height += ValuePanelVerticalPadding + ValuePanelBottomPadding;
        return height;
    }

    private static Rect GetExpandedValuePanelRect(Rect itemRect, Rect headerRect, SerializedProperty value)
    {
        float contentHeight = GetExpandedValueHeight(value);
        return new Rect(
            itemRect.x + FoldoutItemOuterPadding + FoldoutItemInnerPadding + FoldoutValueIndent - 2f,
            headerRect.yMax + ValuePanelTopSpacing,
            itemRect.width - ((FoldoutItemOuterPadding + FoldoutItemInnerPadding) * 2f) - FoldoutValueIndent + 4f,
            (ValuePanelVerticalPadding * 2f) + contentHeight + ValuePanelBottomPadding);
    }

    private static bool GetItemExpandedState(string stateKey, DictionaryDisplayOptions displayMode)
    {
        if (ItemFoldoutStates.TryGetValue(stateKey, out bool expanded))
        {
            return expanded;
        }

        return displayMode != DictionaryDisplayOptions.CollapsedFoldout;
    }

    private static string GetItemStateKey(SerializedProperty dictionaryProperty, int index)
    {
        return $"{GetTargetObjectStateKey(dictionaryProperty.serializedObject.targetObject)}::{dictionaryProperty.propertyPath}::{index}";
    }

    private static float GetExpandedValueHeight(SerializedProperty value)
    {
        if (value.propertyType == SerializedPropertyType.ManagedReference)
        {
            return GetManagedReferenceExpandedValueHeight(value);
        }

        if (TryGetSingleVisibleChildProperty(value, out SerializedProperty singleChildProperty))
        {
            return GetInlinePropertyHeight(singleChildProperty);
        }

        if (!ShouldInlineValueChildren(value))
        {
            return EditorGUI.GetPropertyHeight(value, true);
        }

        float inlineValueHeight = 0f;
        SerializedProperty inlineValueIterator = value.Copy();
        SerializedProperty inlineValueEndProperty = inlineValueIterator.GetEndProperty();
        bool enterInlineChildren = true;
        while (inlineValueIterator.NextVisible(enterInlineChildren) && !SerializedProperty.EqualContents(inlineValueIterator, inlineValueEndProperty))
        {
            inlineValueHeight += GetInlinePropertyHeight(inlineValueIterator) + InlineValueSpacing;
            enterInlineChildren = false;
        }

        return Mathf.Max(EditorGUIUtility.singleLineHeight, inlineValueHeight - InlineValueSpacing);
    }

    private static float GetManagedReferenceExpandedValueHeight(SerializedProperty value)
    {
        float managedReferenceHeight = ManagedReferenceTypeRowHeight;
        if (string.IsNullOrEmpty(value.managedReferenceFullTypename) || !value.hasVisibleChildren)
        {
            return managedReferenceHeight;
        }

        SerializedProperty managedReferenceIterator = value.Copy();
        SerializedProperty managedReferenceEndProperty = managedReferenceIterator.GetEndProperty();
        bool enterManagedReferenceChildren = true;
        while (managedReferenceIterator.NextVisible(enterManagedReferenceChildren) && !SerializedProperty.EqualContents(managedReferenceIterator, managedReferenceEndProperty))
        {
            managedReferenceHeight += RowSpacing + GetInlinePropertyHeight(managedReferenceIterator);
            enterManagedReferenceChildren = false;
        }

        return managedReferenceHeight;
    }

    private void DrawExpandedValue(Rect rect, SerializedProperty value, DictionaryDrawerSettingsAttribute settings)
    {
        float previousLabelWidth = EditorGUIUtility.labelWidth;
        EditorGUIUtility.labelWidth = GetInlineLabelWidth(rect);

        if (value.propertyType == SerializedPropertyType.ManagedReference)
        {
            DrawManagedReferenceValue(rect, value, settings.IsReadOnly, GetPolymorphicSettings(), GetTypeSelectorSettings());
            EditorGUIUtility.labelWidth = previousLabelWidth;
            return;
        }

        if (TryGetSingleVisibleChildProperty(value, out SerializedProperty singleChildProperty))
        {
            GUIContent singleChildLabel = BuildInlinePropertyLabel(singleChildProperty);
            DrawInlinePropertyField(
                rect,
                singleChildProperty,
                ShouldSuppressSingleChildLabel(singleChildProperty, singleChildLabel)
                    ? GUIContent.none
                    : singleChildLabel);
            EditorGUIUtility.labelWidth = previousLabelWidth;
            return;
        }

        if (!ShouldInlineValueChildren(value))
        {
            EditorGUI.PropertyField(rect, value, GetExpandedValueLabel(value, settings), true);
            EditorGUIUtility.labelWidth = previousLabelWidth;
            return;
        }

        float currentY = rect.y;
        SerializedProperty inlineValueIterator = value.Copy();
        SerializedProperty inlineValueEndProperty = inlineValueIterator.GetEndProperty();
        bool enterInlineChildren = true;
        while (inlineValueIterator.NextVisible(enterInlineChildren) && !SerializedProperty.EqualContents(inlineValueIterator, inlineValueEndProperty))
        {
            float childHeight = GetInlinePropertyHeight(inlineValueIterator);
            Rect childRect = new Rect(rect.x, currentY, rect.width, childHeight);
            DrawInlinePropertyField(childRect, inlineValueIterator, BuildInlinePropertyLabel(inlineValueIterator));
            currentY += childHeight + InlineValueSpacing;
            enterInlineChildren = false;
        }

        EditorGUIUtility.labelWidth = previousLabelWidth;
    }

    private static void DrawManagedReferenceValue(
        Rect rect,
        SerializedProperty value,
        bool isDictionaryReadOnly,
        PolymorphicDrawerSettingsAttribute polymorphicSettings,
        TypeSelectorSettingsAttribute typeSelectorSettings)
    {
        bool isReadOnly = ShouldManagedReferenceBeReadOnly(value, isDictionaryReadOnly, polymorphicSettings);
        float previousLabelWidth = EditorGUIUtility.labelWidth;
        EditorGUIUtility.labelWidth = GetInlineLabelWidth(rect);
        Rect typeRect = new Rect(rect.x, rect.y, rect.width, ManagedReferenceTypeRowHeight);
        DrawManagedReferenceTypeRow(typeRect, value, isReadOnly, polymorphicSettings, typeSelectorSettings);

        if (string.IsNullOrEmpty(value.managedReferenceFullTypename) || !value.hasVisibleChildren)
        {
            EditorGUIUtility.labelWidth = previousLabelWidth;
            return;
        }

        float currentY = typeRect.yMax + ManagedReferenceChildTopSpacing;
        SerializedProperty managedReferenceIterator = value.Copy();
        SerializedProperty managedReferenceEndProperty = managedReferenceIterator.GetEndProperty();
        bool enterManagedReferenceChildren = true;
        using (new EditorGUI.DisabledScope(isReadOnly))
        {
            while (managedReferenceIterator.NextVisible(enterManagedReferenceChildren) && !SerializedProperty.EqualContents(managedReferenceIterator, managedReferenceEndProperty))
            {
                float childHeight = GetInlinePropertyHeight(managedReferenceIterator);
                Rect childRect = new Rect(rect.x, currentY, rect.width, childHeight);
                DrawInlinePropertyField(childRect, managedReferenceIterator, BuildInlinePropertyLabel(managedReferenceIterator));
                currentY += childHeight + InlineValueSpacing;
                enterManagedReferenceChildren = false;
            }
        }

        EditorGUIUtility.labelWidth = previousLabelWidth;
    }

    private static GUIContent BuildInlinePropertyLabel(SerializedProperty property)
    {
        if (property == null)
        {
            return GUIContent.none;
        }

        string customLabelText = ResolveCustomLabelText(property);
        if (!string.IsNullOrWhiteSpace(customLabelText))
        {
            return new GUIContent(customLabelText);
        }

        GUIContent naughtyLabel = PropertyUtility.GetLabel(property);
        if (naughtyLabel != null && !string.IsNullOrWhiteSpace(naughtyLabel.text))
        {
            return naughtyLabel;
        }

        return new GUIContent(property.displayName);
    }

    private static void DrawInlinePropertyField(Rect rect, SerializedProperty property, GUIContent label)
    {
        if (ShouldUseCompactInlineListField(property))
        {
            DrawCompactInlineListField(rect, property, label);
            return;
        }

        if (ShouldUseCompactInlineScalarField(property))
        {
            DrawCompactInlineScalarField(rect, property, label);
            return;
        }

        if (ShouldUseCompactInlineColorField(property))
        {
            DrawCompactInlineColorField(rect, property, label);
            return;
        }

        if (ShouldUseCompactInlineEnumField(property))
        {
            DrawCompactInlineEnumField(rect, property, label);
            return;
        }

        if (ShouldUseCompactInlineObjectField(property))
        {
            DrawCompactInlineObjectField(rect, property, label);
            return;
        }

        if (ShouldUseCompactInlineCurveField(property))
        {
            DrawCompactInlineCurveField(rect, property, label);
            return;
        }

        if (ShouldUseCompactInlineVectorField(property))
        {
            DrawCompactInlineVectorField(rect, property, label);
            return;
        }

        EditorGUI.PropertyField(rect, property, label, true);
    }

    private static float GetInlinePropertyHeight(SerializedProperty property)
    {
        if (ShouldUseCompactInlineListField(property))
        {
            return GetCompactInlineListHeight(property);
        }

        if (ShouldUseCompactInlineScalarField(property) || ShouldUseCompactInlineCurveField(property))
        {
            return EditorGUIUtility.singleLineHeight;
        }

        return EditorGUI.GetPropertyHeight(property, true);
    }

    private static bool ShouldUseCompactInlineListField(SerializedProperty property)
    {
        return property != null
            && property.isArray
            && property.propertyType != SerializedPropertyType.String;
    }

    private static bool ShouldUseCompactInlineScalarField(SerializedProperty property)
    {
        return property != null
            && (property.propertyType == SerializedPropertyType.String
                || property.propertyType == SerializedPropertyType.Integer
                || property.propertyType == SerializedPropertyType.Float);
    }

    private static bool ShouldUseCompactInlineColorField(SerializedProperty property)
    {
        return property != null
            && property.propertyType == SerializedPropertyType.Color
            && !property.hasVisibleChildren;
    }

    private static bool ShouldUseCompactInlineEnumField(SerializedProperty property)
    {
        return property != null
            && property.propertyType == SerializedPropertyType.Enum
            && !property.hasVisibleChildren;
    }

    private static bool ShouldUseCompactInlineObjectField(SerializedProperty property)
    {
        return property != null
            && property.propertyType == SerializedPropertyType.ObjectReference
            && !property.hasVisibleChildren;
    }

    private static bool ShouldUseCompactInlineCurveField(SerializedProperty property)
    {
        return property != null
            && property.propertyType == SerializedPropertyType.AnimationCurve
            && !property.hasVisibleChildren;
    }

    private static bool ShouldUseCompactInlineVectorField(SerializedProperty property)
    {
        return property != null
            && (property.propertyType == SerializedPropertyType.Vector2
                || property.propertyType == SerializedPropertyType.Vector2Int
                || property.propertyType == SerializedPropertyType.Vector3
                || property.propertyType == SerializedPropertyType.Vector3Int
                || property.propertyType == SerializedPropertyType.Vector4);
    }

    private static void DrawCompactInlineColorField(Rect rect, SerializedProperty property, GUIContent label)
    {
        EditorGUI.BeginProperty(rect, label, property);
        Rect fieldRect = EditorGUI.PrefixLabel(rect, label ?? GUIContent.none);
        DrawCompactColorFieldChrome(fieldRect);

        float swatchSize = Mathf.Max(12f, fieldRect.height - 4f);
        Rect swatchRect = new Rect(fieldRect.x + 2f, fieldRect.y + 2f, swatchSize, swatchSize);
        Rect textRect = new Rect(
            swatchRect.xMax + 6f,
            fieldRect.y,
            Mathf.Max(0f, fieldRect.width - swatchSize - 10f),
            fieldRect.height);

        EditorGUI.BeginChangeCheck();
        Color nextColor = EditorGUI.ColorField(
            swatchRect,
            GUIContent.none,
            property.colorValue,
            false,
            true,
            false);
        if (EditorGUI.EndChangeCheck())
        {
            property.colorValue = nextColor;
        }

        GUIStyle textStyle = new GUIStyle(EditorStyles.miniLabel)
        {
            alignment = TextAnchor.MiddleLeft,
            clipping = TextClipping.Clip,
            padding = new RectOffset(0, 0, 0, 0),
            margin = new RectOffset(0, 0, 0, 0)
        };
        if (EditorGUIUtility.isProSkin)
        {
            textStyle.normal.textColor = new Color(0.78f, 0.78f, 0.78f, 0.92f);
        }

        EditorGUI.LabelField(textRect, BuildCompactColorValueLabel(property.colorValue), textStyle);
        EditorGUI.EndProperty();
    }

    private static void DrawCompactColorFieldChrome(Rect rect)
    {
        DrawCompactInlineFieldChrome(rect);
    }

    private static void DrawCompactInlineScalarField(Rect rect, SerializedProperty property, GUIContent label)
    {
        EditorGUI.BeginProperty(rect, label, property);
        Rect fieldRect = EditorGUI.PrefixLabel(rect, label ?? GUIContent.none);
        DrawCompactInlineFieldChrome(fieldRect);

        Rect inputRect = new Rect(
            fieldRect.x + 1f,
            fieldRect.y + 1f,
            Mathf.Max(0f, fieldRect.width - 2f),
            Mathf.Max(0f, fieldRect.height - 2f));
        GUIStyle inputStyle = GetCompactInlineTextFieldStyle();

        EditorGUI.BeginChangeCheck();
        switch (property.propertyType)
        {
            case SerializedPropertyType.String:
                property.stringValue = EditorGUI.TextField(inputRect, property.stringValue, inputStyle);
                break;
            case SerializedPropertyType.Integer:
                property.longValue = EditorGUI.LongField(inputRect, property.longValue, inputStyle);
                break;
            case SerializedPropertyType.Float:
                property.floatValue = EditorGUI.FloatField(inputRect, property.floatValue, inputStyle);
                break;
        }

        EditorGUI.EndChangeCheck();
        EditorGUI.EndProperty();
    }

    private static void DrawCompactInlineFieldChrome(Rect rect)
    {
        Color backgroundColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.014f)
            : new Color(0f, 0f, 0f, 0.018f);
        Color borderColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.050f)
            : new Color(0f, 0f, 0f, 0.060f);

        EditorGUI.DrawRect(rect, backgroundColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.y, rect.width, 1f), borderColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - 1f, rect.width, 1f), borderColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.y, 1f, rect.height), borderColor);
        EditorGUI.DrawRect(new Rect(rect.xMax - 1f, rect.y, 1f, rect.height), borderColor);
    }

    private static GUIStyle GetCompactInlineTextFieldStyle()
    {
        GUIStyle style = new GUIStyle(EditorStyles.toolbarTextField)
        {
            alignment = TextAnchor.MiddleLeft,
            margin = new RectOffset(0, 0, 0, 0),
            padding = new RectOffset(4, 4, 0, 0)
        };

        if (EditorGUIUtility.isProSkin)
        {
            style.normal.textColor = new Color(0.83f, 0.83f, 0.83f, 0.96f);
            style.focused.textColor = style.normal.textColor;
            style.active.textColor = style.normal.textColor;
            style.hover.textColor = style.normal.textColor;
        }

        return style;
    }

    private static string BuildCompactColorValueLabel(Color color)
    {
        Color32 color32 = color;
        return $"#{ColorUtility.ToHtmlStringRGB(color)}  {color32.r},{color32.g},{color32.b}";
    }

    private static void DrawCompactInlineCurveField(Rect rect, SerializedProperty property, GUIContent label)
    {
        EditorGUI.BeginProperty(rect, label, property);
        Rect fieldRect = EditorGUI.PrefixLabel(rect, label ?? GUIContent.none);
        DrawCompactInlineFieldChrome(fieldRect);

        Rect curveRect = new Rect(
            fieldRect.x + 2f,
            fieldRect.y + 2f,
            Mathf.Max(0f, fieldRect.width - 4f),
            Mathf.Max(0f, fieldRect.height - 4f));

        EditorGUI.BeginChangeCheck();
        AnimationCurve nextCurve = EditorGUI.CurveField(curveRect, GUIContent.none, property.animationCurveValue);
        if (EditorGUI.EndChangeCheck())
        {
            property.animationCurveValue = nextCurve;
        }

        EditorGUI.EndProperty();
    }

    private static float GetCompactInlineListHeight(SerializedProperty property)
    {
        if (property == null)
        {
            return EditorGUIUtility.singleLineHeight;
        }

        float height = CompactListHeaderHeight;
        if (!property.isExpanded)
        {
            return height;
        }

        height += CompactListRowSpacing + CompactListBodyPadding;
        for (int i = 0; i < property.arraySize; i++)
        {
            SerializedProperty elementProperty = property.GetArrayElementAtIndex(i);
            height += GetInlinePropertyHeight(elementProperty) + CompactListRowSpacing;
        }

        height += CompactListBodyPadding;
        return height;
    }

    private static void DrawCompactInlineListField(Rect rect, SerializedProperty property, GUIContent label)
    {
        Rect headerRect = new Rect(rect.x, rect.y, rect.width, CompactListHeaderHeight);
        DrawFoldoutItemChrome(rect, headerRect, property.isExpanded);

        string countLabel = BuildDictionaryItemCountLabel(property.arraySize);
        float countWidth = GetDictionaryItemCountWidth(countLabel);
        Rect addRect = new Rect(rect.xMax - ButtonWidth, rect.y, ButtonWidth, CompactListHeaderHeight);
        Rect countRect = new Rect(
            addRect.x - HorizontalGap - countWidth,
            rect.y,
            countWidth,
            CompactListHeaderHeight);
        Rect foldoutRect = new Rect(
            rect.x + 2f,
            rect.y,
            Mathf.Max(20f, rect.width - countWidth - ButtonWidth - (HorizontalGap * 2f) - 2f),
            CompactListHeaderHeight);

        property.isExpanded = EditorGUI.Foldout(
            foldoutRect,
            property.isExpanded,
            label ?? GUIContent.none,
            true,
            GetDictionaryRootFoldoutStyle());
        EditorGUI.LabelField(countRect, countLabel, GetDictionaryItemCountStyle());

        if (GUI.enabled && DrawDictionaryActionButton(addRect, AddButtonContent))
        {
            int newIndex = property.arraySize;
            property.InsertArrayElementAtIndex(newIndex);
            ResetProperty(property.GetArrayElementAtIndex(newIndex));
        }

        if (!property.isExpanded)
        {
            return;
        }

        Rect bodyRect = new Rect(
            rect.x + 1f,
            headerRect.yMax + CompactListRowSpacing,
            rect.width - 2f,
            Mathf.Max(0f, rect.height - CompactListHeaderHeight - CompactListRowSpacing));
        DrawExpandedValuePanelChrome(bodyRect);

        float currentY = bodyRect.y + CompactListBodyPadding;
        for (int i = 0; i < property.arraySize; i++)
        {
            SerializedProperty elementProperty = property.GetArrayElementAtIndex(i);
            float elementHeight = GetInlinePropertyHeight(elementProperty);
            Rect rowRect = new Rect(
                bodyRect.x + CompactListBodyPadding,
                currentY,
                bodyRect.width - (CompactListBodyPadding * 2f),
                elementHeight);
            Rect handleRect = new Rect(rowRect.x, rowRect.y, CompactListHandleWidth, rowRect.height);
            Rect removeRect = new Rect(rowRect.xMax - ButtonWidth, rowRect.y, ButtonWidth, EditorGUIUtility.singleLineHeight);
            Rect fieldRect = new Rect(
                handleRect.xMax + 3f,
                rowRect.y,
                rowRect.width - CompactListHandleWidth - ButtonWidth - 4f,
                rowRect.height);

            DrawCompactListHandle(handleRect);
            DrawCompactInlineListElementField(fieldRect, elementProperty);

            if (GUI.enabled && DrawDictionaryActionButton(removeRect, RemoveButtonContent))
            {
                DeleteArrayElement(property, i);
                break;
            }

            EditorGUI.DrawRect(
                new Rect(bodyRect.x, rowRect.yMax, bodyRect.width, 1f),
                EditorGUIUtility.isProSkin
                    ? new Color(1f, 1f, 1f, 0.024f)
                    : new Color(0f, 0f, 0f, 0.032f));
            currentY += elementHeight + CompactListRowSpacing;
        }
    }

    private static void DrawCompactInlineListElementField(Rect rect, SerializedProperty property)
    {
        if (property == null)
        {
            return;
        }

        GUIContent label = ShouldUseCompactInlineListField(property)
            || property.propertyType == SerializedPropertyType.Generic
            || property.propertyType == SerializedPropertyType.ManagedReference
            ? new GUIContent(property.displayName)
            : GUIContent.none;
        DrawInlinePropertyField(rect, property, label);
    }

    private static void DrawCompactListHandle(Rect rect)
    {
        float lineWidth = Mathf.Max(4f, rect.width - 4f);
        float startX = rect.x + (rect.width - lineWidth) * 0.5f;
        float centerY = rect.y + (rect.height * 0.5f);
        Color lineColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.16f)
            : new Color(0f, 0f, 0f, 0.18f);
        for (int i = -1; i <= 1; i++)
        {
            EditorGUI.DrawRect(new Rect(startX, centerY + (i * 4f), lineWidth, 1f), lineColor);
        }
    }

    private static void DeleteArrayElement(SerializedProperty property, int index)
    {
        if (property == null || index < 0 || index >= property.arraySize)
        {
            return;
        }

        int previousSize = property.arraySize;
        property.DeleteArrayElementAtIndex(index);
        if (property.arraySize == previousSize)
        {
            property.DeleteArrayElementAtIndex(index);
        }
    }

    private static void DrawCompactInlineEnumField(Rect rect, SerializedProperty property, GUIContent label)
    {
        EditorGUI.BeginProperty(rect, label, property);
        EditorGUI.BeginChangeCheck();
        Rect fieldRect = EditorGUI.PrefixLabel(rect, label ?? GUIContent.none);
        int nextValue = EditorGUI.Popup(fieldRect, property.enumValueIndex, property.enumDisplayNames);
        if (EditorGUI.EndChangeCheck())
        {
            property.enumValueIndex = nextValue;
        }

        EditorGUI.EndProperty();
    }

    private static void DrawCompactInlineObjectField(Rect rect, SerializedProperty property, GUIContent label)
    {
        Type objectType = ResolveObjectReferenceFieldType(property) ?? typeof(Object);
        bool allowSceneObjects = AllowSceneObjectsForInlineProperty(property);

        EditorGUI.BeginProperty(rect, label, property);
        EditorGUI.BeginChangeCheck();
        Object nextValue = EditorGUI.ObjectField(
            rect,
            label ?? GUIContent.none,
            property.objectReferenceValue,
            objectType,
            allowSceneObjects);
        if (EditorGUI.EndChangeCheck())
        {
            property.objectReferenceValue = nextValue;
        }

        EditorGUI.EndProperty();
    }

    private static void DrawCompactInlineVectorField(Rect rect, SerializedProperty property, GUIContent label)
    {
        EditorGUI.BeginProperty(rect, label, property);
        EditorGUI.BeginChangeCheck();
        switch (property.propertyType)
        {
            case SerializedPropertyType.Vector2:
                property.vector2Value = EditorGUI.Vector2Field(rect, label ?? GUIContent.none, property.vector2Value);
                break;
            case SerializedPropertyType.Vector2Int:
                property.vector2IntValue = EditorGUI.Vector2IntField(rect, label ?? GUIContent.none, property.vector2IntValue);
                break;
            case SerializedPropertyType.Vector3:
                property.vector3Value = EditorGUI.Vector3Field(rect, label ?? GUIContent.none, property.vector3Value);
                break;
            case SerializedPropertyType.Vector3Int:
                property.vector3IntValue = EditorGUI.Vector3IntField(rect, label ?? GUIContent.none, property.vector3IntValue);
                break;
            case SerializedPropertyType.Vector4:
                property.vector4Value = EditorGUI.Vector4Field(rect, label ?? GUIContent.none, property.vector4Value);
                break;
            default:
                EditorGUI.PropertyField(rect, property, label ?? GUIContent.none, true);
                break;
        }

        EditorGUI.EndChangeCheck();
        EditorGUI.EndProperty();
    }

    private static Type ResolveObjectReferenceFieldType(SerializedProperty property)
    {
        if (property?.serializedObject?.targetObject == null || string.IsNullOrEmpty(property.propertyPath))
        {
            return null;
        }

        string parentPath = GetParentPropertyPath(property.propertyPath);
        object parentObject = string.IsNullOrEmpty(parentPath)
            ? property.serializedObject.targetObject
            : GetObjectAtPropertyPath(property.serializedObject.targetObject, parentPath);
        if (parentObject == null)
        {
            return null;
        }

        FieldInfo fieldInfo = GetFieldInfoFromType(parentObject.GetType(), property.name);
        Type fieldType = fieldInfo?.FieldType;
        return fieldType != null && typeof(Object).IsAssignableFrom(fieldType)
            ? fieldType
            : null;
    }

    private static bool AllowSceneObjectsForInlineProperty(SerializedProperty property)
    {
        Object targetObject = property?.serializedObject?.targetObject;
        return targetObject != null && !EditorUtility.IsPersistent(targetObject);
    }

    private static string ResolveCustomLabelText(SerializedProperty property)
    {
        if (property?.serializedObject?.targetObject == null || string.IsNullOrEmpty(property.propertyPath))
        {
            return null;
        }

        string parentPath = GetParentPropertyPath(property.propertyPath);
        if (string.IsNullOrEmpty(parentPath))
        {
            return null;
        }

        object parentObject = GetObjectAtPropertyPath(property.serializedObject.targetObject, parentPath);
        if (parentObject == null)
        {
            return null;
        }

        FieldInfo fieldInfo = GetFieldInfoFromType(parentObject.GetType(), property.name);
        return fieldInfo?.GetCustomAttribute<LabelAttribute>()?.Label;
    }

    private static string GetParentPropertyPath(string propertyPath)
    {
        if (string.IsNullOrEmpty(propertyPath))
        {
            return string.Empty;
        }

        int lastDotIndex = propertyPath.LastIndexOf('.');
        return lastDotIndex <= 0 ? string.Empty : propertyPath[..lastDotIndex];
    }

    private static FieldInfo GetFieldInfoFromType(Type type, string fieldName)
    {
        for (Type currentType = type; currentType != null && currentType != typeof(object); currentType = currentType.BaseType)
        {
            FieldInfo fieldInfo = currentType.GetField(fieldName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            if (fieldInfo != null)
            {
                return fieldInfo;
            }
        }

        return null;
    }

    private static void DrawManagedReferenceTypeRow(
        Rect rect,
        SerializedProperty value,
        bool isReadOnly,
        PolymorphicDrawerSettingsAttribute polymorphicSettings,
        TypeSelectorSettingsAttribute typeSelectorSettings)
    {
        GUIContent fieldContent = BuildManagedReferenceCompactFieldContent(value, polymorphicSettings);
        bool hasValue = !string.IsNullOrEmpty(value.managedReferenceFullTypename);
        GUIStyle popupStyle = GetManagedReferenceTypePopupStyle(hasValue);

        using (new EditorGUI.DisabledScope(isReadOnly))
        {
            if (EditorGUI.DropdownButton(rect, fieldContent, FocusType.Passive, popupStyle))
            {
                ShowManagedReferenceTypePicker(rect, value, polymorphicSettings, typeSelectorSettings);
            }
        }
    }

    private static bool ShouldInlineValueChildren(SerializedProperty value)
    {
        if (value == null || !value.hasVisibleChildren)
        {
            return false;
        }

        if (value.isArray && value.propertyType != SerializedPropertyType.String)
        {
            return false;
        }

        return value.propertyType == SerializedPropertyType.Generic
            || value.propertyType == SerializedPropertyType.ManagedReference;
    }

    private static bool TryGetSingleVisibleChildProperty(SerializedProperty value, out SerializedProperty childProperty)
    {
        childProperty = null;
        if (value == null
            || value.propertyType != SerializedPropertyType.Generic
            || value.isArray
            || !value.hasVisibleChildren)
        {
            return false;
        }

        SerializedProperty iterator = value.Copy();
        SerializedProperty endProperty = iterator.GetEndProperty();
        bool enterChildren = true;
        int visibleChildCount = 0;
        while (iterator.NextVisible(enterChildren) && !SerializedProperty.EqualContents(iterator, endProperty))
        {
            visibleChildCount++;
            if (visibleChildCount > 1)
            {
                childProperty = null;
                return false;
            }

            childProperty = iterator.Copy();
            enterChildren = false;
        }

        return visibleChildCount == 1 && childProperty != null;
    }

    private static bool TryGetSingleChildDictionaryProperty(SerializedProperty value, out SerializedProperty dictionaryProperty)
    {
        dictionaryProperty = null;
        if (!TryGetSingleVisibleChildProperty(value, out SerializedProperty childProperty))
        {
            return false;
        }

        if (!IsSerializableDictionaryProperty(childProperty))
        {
            return false;
        }

        dictionaryProperty = childProperty;
        return true;
    }

    private static bool IsSerializableDictionaryProperty(SerializedProperty property)
    {
        return property != null
            && property.FindPropertyRelative(SerializableDictionaryBase.KeysFieldName) != null
            && property.FindPropertyRelative(SerializableDictionaryBase.ValuesFieldName) != null;
    }

    private static bool ShouldDrawOuterValuePanelChrome(SerializedProperty value)
    {
        return !TryGetSingleChildDictionaryProperty(value, out _);
    }

    private static bool ShouldSuppressSingleChildLabel(SerializedProperty property, GUIContent label)
    {
        if (property == null)
        {
            return false;
        }

        if (property.isArray && property.propertyType != SerializedPropertyType.String)
        {
            if (label != null
                && !string.IsNullOrWhiteSpace(label.text)
                && !string.Equals(label.text, property.displayName, StringComparison.Ordinal))
            {
                return false;
            }

            return true;
        }

        return false;
    }

    private static void DrawFoldoutItemChrome(Rect itemRect, Rect headerRect, bool expanded)
    {
        Color borderColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, expanded ? 0.032f : 0.024f)
            : new Color(0f, 0f, 0f, expanded ? 0.058f : 0.046f);
        Color bodyColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, expanded ? 0.007f : 0.005f)
            : new Color(0f, 0f, 0f, expanded ? 0.009f : 0.006f);
        Color headerColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, expanded ? 0.022f : 0.014f)
            : new Color(0f, 0f, 0f, expanded ? 0.028f : 0.018f);

        Rect outerRect = new Rect(itemRect.x, itemRect.y, itemRect.width, itemRect.height);
        Rect innerRect = new Rect(itemRect.x + 1f, itemRect.y + 1f, itemRect.width - 2f, itemRect.height - 2f);
        Rect headerFillRect = new Rect(
            innerRect.x,
            innerRect.y,
            innerRect.width,
            headerRect.height + (ItemVerticalPadding * 2f) + 1f);

        EditorGUI.DrawRect(innerRect, bodyColor);
        EditorGUI.DrawRect(headerFillRect, headerColor);
        EditorGUI.DrawRect(new Rect(outerRect.x, outerRect.y, outerRect.width, 1f), borderColor);
        EditorGUI.DrawRect(new Rect(outerRect.x, outerRect.yMax - 1f, outerRect.width, 1f), borderColor);

        if (!expanded)
        {
            return;
        }

        Rect separatorRect = new Rect(
            itemRect.x + FoldoutItemOuterPadding,
            headerRect.yMax + ItemVerticalPadding + 1f,
            itemRect.width - (FoldoutItemOuterPadding * 2f),
            SeparatorHeight);
        Color separatorColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.030f)
            : new Color(0f, 0f, 0f, 0.038f);
        EditorGUI.DrawRect(separatorRect, separatorColor);
    }

    private static void DrawDictionaryRootChrome(Rect rect)
    {
        Color backgroundColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.009f)
            : new Color(0f, 0f, 0f, 0.012f);
        Color borderColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.032f)
            : new Color(0f, 0f, 0f, 0.048f);

        EditorGUI.DrawRect(rect, backgroundColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - 1f, rect.width, 1f), borderColor);
    }

    private static bool DrawDictionaryActionButton(Rect rect, GUIContent content)
    {
        bool isHover = rect.Contains(Event.current.mousePosition);
        Rect chromeRect = new Rect(rect.x, rect.y + 1f, rect.width, Mathf.Max(0f, rect.height - 2f));
        Color backgroundColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, isHover ? 0.028f : 0.015f)
            : new Color(0f, 0f, 0f, isHover ? 0.045f : 0.026f);
        Color borderColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, isHover ? 0.056f : 0.036f)
            : new Color(0f, 0f, 0f, isHover ? 0.082f : 0.058f);

        EditorGUI.DrawRect(chromeRect, backgroundColor);
        EditorGUI.DrawRect(new Rect(chromeRect.x, chromeRect.y, chromeRect.width, 1f), borderColor);
        EditorGUI.DrawRect(new Rect(chromeRect.x, chromeRect.yMax - 1f, chromeRect.width, 1f), borderColor);
        EditorGUI.DrawRect(new Rect(chromeRect.x, chromeRect.y, 1f, chromeRect.height), borderColor);
        EditorGUI.DrawRect(new Rect(chromeRect.xMax - 1f, chromeRect.y, 1f, chromeRect.height), borderColor);

        GUIStyle style = new GUIStyle(EditorStyles.miniLabel)
        {
            alignment = TextAnchor.MiddleCenter,
            clipping = TextClipping.Clip,
            fontStyle = FontStyle.Normal,
            padding = new RectOffset(0, 0, 0, 0),
            margin = new RectOffset(0, 0, 0, 0)
        };

        if (EditorGUIUtility.isProSkin)
        {
            style.normal.textColor = new Color(0.76f, 0.76f, 0.76f, isHover ? 0.92f : 0.82f);
        }

        GUI.Label(chromeRect, content, style);
        return GUI.Button(rect, GUIContent.none, GUIStyle.none);
    }

    private static void DrawExpandedValuePanelChrome(Rect rect)
    {
        Color panelColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.003f)
            : new Color(0f, 0f, 0f, 0.006f);

        EditorGUI.DrawRect(rect, panelColor);
    }

    private static GUIStyle GetManagedReferenceTypePopupStyle(bool hasValue)
    {
        GUIStyle popupStyle = new GUIStyle(EditorStyles.popup)
        {
            alignment = TextAnchor.MiddleLeft,
            clipping = TextClipping.Clip,
            margin = new RectOffset(0, 0, 0, 0),
            padding = new RectOffset(5, 17, 0, 0)
        };

        if (EditorGUIUtility.isProSkin)
        {
            popupStyle.normal.textColor = hasValue
                ? new Color(0.84f, 0.84f, 0.84f, 0.96f)
                : new Color(0.70f, 0.70f, 0.70f, 0.92f);
        }

        return popupStyle;
    }

    private static void DrawDuplicateKeyBackground(Rect rect)
    {
        Rect highlightRect = new Rect(rect.x, rect.y + 1f, rect.width, Mathf.Max(0f, rect.height - 2f));
        EditorGUI.DrawRect(highlightRect, new Color(1f, 0.8f, 0.8f, 0.4f));
    }

    private static void DrawDuplicateKeyOverlay(Rect rect)
    {
        Color tintColor = new Color(1f, 0.48f, 0.48f, 0.08f);
        Color borderColor = new Color(1f, 0.52f, 0.52f, 0.26f);
        EditorGUI.DrawRect(rect, tintColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.y, rect.width, 1f), borderColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - 1f, rect.width, 1f), borderColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.y, 1f, rect.height), borderColor);
        EditorGUI.DrawRect(new Rect(rect.xMax - 1f, rect.y, 1f, rect.height), borderColor);
    }

    private static float GetInlineLabelWidth(Rect rect)
    {
        return Mathf.Clamp(rect.width * 0.125f, 48f, 88f);
    }

    private static void DrawFoldoutKeyPrefix(Rect rect, string label)
    {
        if (string.IsNullOrWhiteSpace(label))
        {
            return;
        }

        Color backgroundColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.022f)
            : new Color(0f, 0f, 0f, 0.020f);
        Color dividerColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.040f)
            : new Color(0f, 0f, 0f, 0.044f);
        EditorGUI.DrawRect(rect, backgroundColor);
        EditorGUI.DrawRect(new Rect(rect.xMax - 1f, rect.y + 1f, 1f, Mathf.Max(0f, rect.height - 2f)), dividerColor);

        GUIStyle style = new GUIStyle(EditorStyles.miniLabel)
        {
            alignment = TextAnchor.MiddleLeft,
            clipping = TextClipping.Clip,
            fontStyle = FontStyle.Normal,
            padding = new RectOffset(3, 2, 0, 0)
        };

        if (EditorGUIUtility.isProSkin)
        {
            style.normal.textColor = new Color(0.68f, 0.68f, 0.68f, 0.82f);
        }

        EditorGUI.LabelField(rect, label, style);
    }

    private static GUIContent GetExpandedValueLabel(SerializedProperty value, DictionaryDrawerSettingsAttribute settings)
    {
        return ShouldDrawExpandedValueLabel(value)
            ? new GUIContent(string.IsNullOrEmpty(settings.ValueLabel) ? "Value" : settings.ValueLabel)
            : GUIContent.none;
    }

    private static bool ShouldDrawExpandedValueLabel(SerializedProperty value)
    {
        if (value == null)
        {
            return false;
        }

        if (value.propertyType == SerializedPropertyType.ManagedReference
            || value.propertyType == SerializedPropertyType.Generic
            || value.propertyType == SerializedPropertyType.ObjectReference
            || value.propertyType == SerializedPropertyType.ExposedReference)
        {
            return false;
        }

        if (ShouldUseCompactInlineVectorField(value))
        {
            return false;
        }

        if (value.isArray && value.propertyType != SerializedPropertyType.String)
        {
            return false;
        }

        return true;
    }

    private static bool ShouldManagedReferenceBeReadOnly(
        SerializedProperty value,
        bool isDictionaryReadOnly,
        PolymorphicDrawerSettingsAttribute polymorphicSettings)
    {
        return isDictionaryReadOnly
            || (polymorphicSettings?.ReadOnlyIfNotNullReference == true
                && value != null
                && !string.IsNullOrEmpty(value.managedReferenceFullTypename));
    }

    private static void ShowManagedReferenceTypePicker(
        Rect buttonRect,
        SerializedProperty value,
        PolymorphicDrawerSettingsAttribute polymorphicSettings,
        TypeSelectorSettingsAttribute typeSelectorSettings)
    {
        PopupWindow.Show(
            buttonRect,
            new ManagedReferenceTypePickerPopup(
                BuildManagedReferenceAssignableTypesCore(value, value.serializedObject.targetObject, typeSelectorSettings, polymorphicSettings),
                GetManagedReferenceCurrentType(value),
                typeSelectorSettings,
                selectedType => SetManagedReferenceTypeCore(
                    value.serializedObject.targetObjects,
                    value.propertyPath,
                    selectedType,
                    polymorphicSettings)));
    }

    private static void SetManagedReferenceType(
        Object[] targetObjects,
        string propertyPath,
        Type targetType)
    {
        SetManagedReferenceTypeCore(targetObjects, propertyPath, targetType, null);
    }

    private static void SetManagedReferenceTypeCore(
        Object[] targetObjects,
        string propertyPath,
        Type targetType,
        PolymorphicDrawerSettingsAttribute polymorphicSettings = null)
    {
        if (targetObjects == null || targetObjects.Length == 0)
        {
            return;
        }

        for (int i = 0; i < targetObjects.Length; i++)
        {
            Object targetObject = targetObjects[i];
            if (targetObject == null)
            {
                continue;
            }

            SerializedObject serializedObject = new SerializedObject(targetObject);
            SerializedProperty property = serializedObject.FindProperty(propertyPath);
            if (property == null)
            {
                continue;
            }

            object previousValue = property.managedReferenceValue;
            object nextValue = targetType == null
                ? null
                : CreateManagedReferenceInstance(targetType, targetObject, polymorphicSettings);
            if (previousValue != null && nextValue != null)
            {
                CopySharedSerializableFields(previousValue, nextValue);
            }

            property.managedReferenceValue = nextValue;
            serializedObject.ApplyModifiedProperties();
        }

        SyncRuntimeDictionaryAtPath(targetObjects, GetContainingDictionaryPropertyPath(propertyPath));
    }

    private static void SyncRuntimeDictionaryAtPath(Object[] targetObjects, string dictionaryPropertyPath)
    {
        if (string.IsNullOrEmpty(dictionaryPropertyPath) || targetObjects == null)
        {
            return;
        }

        foreach (Object targetObject in targetObjects)
        {
            if (targetObject == null)
            {
                continue;
            }

            if (GetObjectAtPropertyPath(targetObject, dictionaryPropertyPath) is SerializableDictionaryBase dictionary)
            {
                dictionary.OnAfterDeserialize();
                EditorUtility.SetDirty(targetObject);
            }
        }
    }

    private static string GetContainingDictionaryPropertyPath(string propertyPath)
    {
        if (string.IsNullOrEmpty(propertyPath))
        {
            return string.Empty;
        }

        string marker = $".{SerializableDictionaryBase.ValuesFieldName}.Array.data[";
        int markerIndex = propertyPath.LastIndexOf(marker, StringComparison.Ordinal);
        return markerIndex > 0 ? propertyPath[..markerIndex] : string.Empty;
    }

    private static object GetObjectAtPropertyPath(object rootObject, string propertyPath)
    {
        if (rootObject == null || string.IsNullOrEmpty(propertyPath))
        {
            return null;
        }

        object current = rootObject;
        string normalizedPath = propertyPath.Replace(".Array.data[", "[", StringComparison.Ordinal);
        string[] segments = normalizedPath.Split('.');
        for (int i = 0; i < segments.Length && current != null; i++)
        {
            string segment = segments[i];
            int bracketIndex = segment.IndexOf('[');
            if (bracketIndex >= 0)
            {
                string memberName = segment[..bracketIndex];
                int endBracketIndex = segment.IndexOf(']', bracketIndex);
                int index = int.Parse(segment.Substring(bracketIndex + 1, endBracketIndex - bracketIndex - 1));
                current = GetIndexedValue(GetMemberValue(current, memberName), index);
            }
            else
            {
                current = GetMemberValue(current, segment);
            }
        }

        return current;
    }

    private static object GetMemberValue(object source, string memberName)
    {
        if (source == null || string.IsNullOrEmpty(memberName))
        {
            return null;
        }

        for (Type type = source.GetType(); type != null; type = type.BaseType)
        {
            FieldInfo field = type.GetField(memberName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            if (field != null)
            {
                return field.GetValue(source);
            }

            PropertyInfo property = type.GetProperty(memberName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            if (property != null)
            {
                return property.GetValue(source);
            }
        }

        return null;
    }

    private static object GetIndexedValue(object source, int index)
    {
        if (source is IList list && index >= 0 && index < list.Count)
        {
            return list[index];
        }

        return null;
    }

    private static List<Type> GetManagedReferenceAssignableTypes(SerializedProperty value)
    {
        return BuildManagedReferenceAssignableTypes(value, value?.serializedObject?.targetObject, null);
    }

    private static List<Type> BuildManagedReferenceAssignableTypes(
        SerializedProperty value,
        Object contextObject,
        TypeSelectorSettingsAttribute typeSelectorSettings)
    {
        return BuildManagedReferenceAssignableTypesCore(value, contextObject, typeSelectorSettings, null);
    }

    private static List<Type> BuildManagedReferenceAssignableTypesCore(
        SerializedProperty value,
        Object contextObject,
        TypeSelectorSettingsAttribute typeSelectorSettings,
        PolymorphicDrawerSettingsAttribute polymorphicSettings)
    {
        List<Type> candidateTypes = new List<Type>();
        Type baseType = ResolveManagedReferenceBaseType(value);
        if (baseType == null)
        {
            return candidateTypes;
        }

        if (IsManagedReferenceCandidateType(baseType)
            && PassesNonDefaultConstructorPreference(baseType, polymorphicSettings)
            && PassesTypeSelectorFilter(baseType, contextObject, typeSelectorSettings))
        {
            candidateTypes.Add(baseType);
        }

        foreach (Type candidateType in TypeCache.GetTypesDerivedFrom(baseType))
        {
            if (IsManagedReferenceCandidateType(candidateType)
                && PassesNonDefaultConstructorPreference(candidateType, polymorphicSettings)
                && PassesTypeSelectorFilter(candidateType, contextObject, typeSelectorSettings))
            {
                candidateTypes.Add(candidateType);
            }
        }

        candidateTypes.Sort((left, right) => string.Compare(GetManagedReferenceDisplayName(left), GetManagedReferenceDisplayName(right), StringComparison.Ordinal));
        return candidateTypes;
    }

    private static Type ResolveManagedReferenceBaseType(SerializedProperty value)
    {
        if (value == null)
        {
            return null;
        }

        Type baseType = ResolveManagedReferenceTypeName(value.managedReferenceFieldTypename);
        if (baseType != null)
        {
            return baseType;
        }

        Type currentType = GetManagedReferenceCurrentType(value);
        return currentType?.BaseType;
    }

    private static Type GetManagedReferenceCurrentType(SerializedProperty value)
    {
        return ResolveManagedReferenceTypeName(value?.managedReferenceFullTypename);
    }

    private static Type ResolveManagedReferenceTypeName(string unityTypeName)
    {
        if (string.IsNullOrEmpty(unityTypeName))
        {
            return null;
        }

        string[] parts = unityTypeName.Split(' ');
        if (parts.Length != 2)
        {
            return null;
        }

        string assemblyName = parts[0];
        string fullTypeName = parts[1];
        Type resolvedType = Type.GetType($"{fullTypeName}, {assemblyName}", false);
        if (resolvedType != null)
        {
            return resolvedType;
        }

        Assembly[] assemblies = AppDomain.CurrentDomain.GetAssemblies();
        for (int i = 0; i < assemblies.Length; i++)
        {
            Assembly assembly = assemblies[i];
            if (!string.Equals(assembly.GetName().Name, assemblyName, StringComparison.Ordinal))
            {
                continue;
            }

            resolvedType = assembly.GetType(fullTypeName, false);
            if (resolvedType != null)
            {
                return resolvedType;
            }
        }

        return null;
    }

    private static bool IsManagedReferenceCandidateType(Type candidateType)
    {
        return candidateType != null
            && !candidateType.IsAbstract
            && !candidateType.IsInterface
            && !candidateType.IsGenericTypeDefinition
            && !typeof(UnityEngine.Object).IsAssignableFrom(candidateType)
            && candidateType.IsDefined(typeof(SerializableAttribute), false);
    }

    private static bool PassesNonDefaultConstructorPreference(
        Type candidateType,
        PolymorphicDrawerSettingsAttribute polymorphicSettings)
    {
        if (candidateType == null || HasDefaultConstructor(candidateType))
        {
            return true;
        }

        return polymorphicSettings?.NonDefaultConstructorPreference != NonDefaultConstructorPreference.Exclude;
    }

    private static bool HasDefaultConstructor(Type candidateType)
    {
        if (candidateType == null)
        {
            return false;
        }

        return candidateType.IsValueType
            || candidateType.GetConstructor(
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic,
                null,
                Type.EmptyTypes,
                null) != null;
    }

    private static object CreateManagedReferenceInstance(
        Type targetType,
        Object contextObject,
        PolymorphicDrawerSettingsAttribute polymorphicSettings)
    {
        if (TryCreateManagedReferenceInstanceFromCallback(targetType, contextObject, polymorphicSettings, out object customInstance))
        {
            return customInstance;
        }

        if (TryCreateManagedReferenceInstanceFromPreference(targetType, polymorphicSettings, out object preferredInstance))
        {
            return preferredInstance;
        }

        if (TryCreateManagedReferenceInstanceFromConstructors(targetType, out object constructedInstance))
        {
            LogNonDefaultConstructorPreferenceFallback(targetType, polymorphicSettings, "使用非默认构造函数创建");
            return constructedInstance;
        }

        if (TryCreateManagedReferenceInstanceWithoutConstructor(targetType, out object uninitializedInstance))
        {
            LogNonDefaultConstructorPreferenceFallback(targetType, polymorphicSettings, "使用未初始化对象创建");
            return uninitializedInstance;
        }

        throw new InvalidOperationException($"无法为多态值类型 {targetType.FullName} 创建实例。");
    }

    private static bool TryCreateManagedReferenceInstanceFromPreference(
        Type targetType,
        PolymorphicDrawerSettingsAttribute polymorphicSettings,
        out object instance)
    {
        instance = null;
        NonDefaultConstructorPreference preference = polymorphicSettings?.NonDefaultConstructorPreference
            ?? NonDefaultConstructorPreference.ConstructIdeal;
        if (HasDefaultConstructor(targetType))
        {
            return false;
        }

        switch (preference)
        {
            case NonDefaultConstructorPreference.Exclude:
                throw new InvalidOperationException($"多态值类型 {targetType.FullName} 没有默认构造函数，当前已按 Exclude 策略排除。");
            case NonDefaultConstructorPreference.PreferUninitialized:
                return TryCreateManagedReferenceInstanceWithoutConstructor(targetType, out instance);
            case NonDefaultConstructorPreference.LogWarning:
            case NonDefaultConstructorPreference.ConstructIdeal:
            default:
                return false;
        }
    }

    private static bool TryCreateManagedReferenceInstanceFromConstructors(Type targetType, out object instance)
    {
        instance = null;
        if (targetType == null)
        {
            return false;
        }

        ConstructorInfo[] constructors = targetType.GetConstructors(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
        Array.Sort(constructors, CompareConstructorsForManagedReferenceCreation);

        for (int i = 0; i < constructors.Length; i++)
        {
            ConstructorInfo constructor = constructors[i];
            try
            {
                instance = constructor.Invoke(BuildManagedReferenceConstructorArguments(constructor.GetParameters()));
                return true;
            }
            catch
            {
                // 继续尝试参数更多的构造函数，直到找到一个当前上下文能默认创建的实例。
            }
        }

        return false;
    }

    private static bool TryCreateManagedReferenceInstanceWithoutConstructor(Type targetType, out object instance)
    {
        instance = null;
        if (targetType == null || targetType.IsValueType)
        {
            return false;
        }

        try
        {
            instance = FormatterServices.GetUninitializedObject(targetType);
            return instance != null;
        }
        catch
        {
            return false;
        }
    }

    private static int CompareConstructorsForManagedReferenceCreation(ConstructorInfo left, ConstructorInfo right)
    {
        int parameterCountComparison = left.GetParameters().Length.CompareTo(right.GetParameters().Length);
        if (parameterCountComparison != 0)
        {
            return parameterCountComparison;
        }

        return string.Compare(left.ToString(), right.ToString(), StringComparison.Ordinal);
    }

    private static object[] BuildManagedReferenceConstructorArguments(ParameterInfo[] parameters)
    {
        if (parameters == null || parameters.Length == 0)
        {
            return Array.Empty<object>();
        }

        object[] arguments = new object[parameters.Length];
        for (int i = 0; i < parameters.Length; i++)
        {
            ParameterInfo parameter = parameters[i];
            if (parameter.HasDefaultValue)
            {
                arguments[i] = parameter.DefaultValue;
                continue;
            }

            Type parameterType = parameter.ParameterType;
            arguments[i] = parameterType.IsValueType ? Activator.CreateInstance(parameterType) : null;
        }

        return arguments;
    }

    private static bool TryCreateManagedReferenceInstanceFromCallback(
        Type targetType,
        Object contextObject,
        PolymorphicDrawerSettingsAttribute polymorphicSettings,
        out object instance)
    {
        instance = null;
        if (targetType == null
            || contextObject == null
            || polymorphicSettings == null
            || string.IsNullOrWhiteSpace(polymorphicSettings.CreateInstanceFunction))
        {
            return false;
        }

        MethodInfo method = FindTypeCallbackMethod(
            contextObject.GetType(),
            polymorphicSettings.CreateInstanceFunction,
            typeof(object),
            typeof(Type));
        if (method == null)
        {
            return false;
        }

        object callbackTarget = method.IsStatic ? null : contextObject;
        object[] arguments = method.GetParameters().Length == 0 ? Array.Empty<object>() : new object[] { targetType };
        object callbackResult;
        try
        {
            callbackResult = method.Invoke(callbackTarget, arguments);
        }
        catch (TargetInvocationException exception)
        {
            Exception innerException = exception.InnerException ?? exception;
            Debug.LogWarning(
                $"SerializableDictionary 多态值自定义创建函数 {method.Name} 为类型 {targetType.FullName} 创建实例时失败，已回退到默认创建策略：{innerException.Message}");
            return false;
        }
        catch (Exception exception)
        {
            Debug.LogWarning(
                $"SerializableDictionary 多态值自定义创建函数 {method.Name} 为类型 {targetType.FullName} 创建实例时失败，已回退到默认创建策略：{exception.Message}");
            return false;
        }

        if (callbackResult == null || !targetType.IsInstanceOfType(callbackResult))
        {
            return false;
        }

        instance = callbackResult;
        return true;
    }

    private static void LogNonDefaultConstructorPreferenceFallback(
        Type targetType,
        PolymorphicDrawerSettingsAttribute polymorphicSettings,
        string strategyDescription)
    {
        if (targetType == null
            || polymorphicSettings?.NonDefaultConstructorPreference != NonDefaultConstructorPreference.LogWarning
            || HasDefaultConstructor(targetType))
        {
            return;
        }

        Debug.LogWarning($"SerializableDictionary 多态值类型 {targetType.FullName} 没有默认构造函数，已退化为 {strategyDescription}。");
    }

    private static bool PassesTypeSelectorFilter(
        Type candidateType,
        Object contextObject,
        TypeSelectorSettingsAttribute typeSelectorSettings)
    {
        if (candidateType == null
            || contextObject == null
            || typeSelectorSettings == null
            || string.IsNullOrWhiteSpace(typeSelectorSettings.FilterTypesFunction))
        {
            return true;
        }

        MethodInfo method = FindTypeCallbackMethod(
            contextObject.GetType(),
            typeSelectorSettings.FilterTypesFunction,
            typeof(bool),
            typeof(Type));
        if (method == null)
        {
            return true;
        }

        object callbackTarget = method.IsStatic ? null : contextObject;
        object[] arguments = method.GetParameters().Length == 0 ? Array.Empty<object>() : new object[] { candidateType };
        object callbackResult = method.Invoke(callbackTarget, arguments);
        return callbackResult is not bool result || result;
    }

    private static MethodInfo FindTypeCallbackMethod(
        Type contextType,
        string methodName,
        Type preferredReturnType,
        Type parameterType)
    {
        if (contextType == null || string.IsNullOrWhiteSpace(methodName))
        {
            return null;
        }

        const BindingFlags flags = BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic;
        for (Type type = contextType; type != null; type = type.BaseType)
        {
            MethodInfo[] methods = type.GetMethods(flags);
            for (int i = 0; i < methods.Length; i++)
            {
                MethodInfo method = methods[i];
                if (!string.Equals(method.Name, methodName, StringComparison.Ordinal))
                {
                    continue;
                }

                ParameterInfo[] parameters = method.GetParameters();
                bool zeroParameterMatch = parameters.Length == 0;
                bool typeParameterMatch = parameters.Length == 1 && parameters[0].ParameterType == parameterType;
                if (!zeroParameterMatch && !typeParameterMatch)
                {
                    continue;
                }

                if (preferredReturnType == typeof(bool) && method.ReturnType != typeof(bool))
                {
                    continue;
                }

                if (preferredReturnType == typeof(object) && method.ReturnType == typeof(void))
                {
                    continue;
                }

                return method;
            }
        }

        return null;
    }

    private static void CopySharedSerializableFields(object source, object destination)
    {
        if (source == null || destination == null)
        {
            return;
        }

        Dictionary<string, FieldInfo> sourceFields = GetSerializableFieldMap(source.GetType());
        Dictionary<string, FieldInfo> destinationFields = GetSerializableFieldMap(destination.GetType());
        foreach (KeyValuePair<string, FieldInfo> destinationPair in destinationFields)
        {
            if (!sourceFields.TryGetValue(destinationPair.Key, out FieldInfo sourceField))
            {
                continue;
            }

            if (!destinationPair.Value.FieldType.IsAssignableFrom(sourceField.FieldType))
            {
                continue;
            }

            destinationPair.Value.SetValue(destination, sourceField.GetValue(source));
        }
    }

    private static Dictionary<string, FieldInfo> GetSerializableFieldMap(Type type)
    {
        Dictionary<string, FieldInfo> fieldMap = new Dictionary<string, FieldInfo>();
        for (Type currentType = type; currentType != null && currentType != typeof(object); currentType = currentType.BaseType)
        {
            FieldInfo[] fields = currentType.GetFields(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly);
            for (int i = 0; i < fields.Length; i++)
            {
                FieldInfo field = fields[i];
                if (!IsSerializableField(field) || fieldMap.ContainsKey(field.Name))
                {
                    continue;
                }

                fieldMap.Add(field.Name, field);
            }
        }

        return fieldMap;
    }

    private static bool IsSerializableField(FieldInfo field)
    {
        return field != null
            && !field.IsStatic
            && !field.IsNotSerialized
            && (field.IsPublic || field.IsDefined(typeof(SerializeField), false) || field.IsDefined(typeof(SerializeReference), false));
    }

    private static string GetManagedReferenceTypeName(SerializedProperty property)
    {
        Type currentType = GetManagedReferenceCurrentType(property);
        return currentType == null ? "None" : GetManagedReferenceDisplayName(currentType);
    }

    private static GUIContent GetManagedReferenceTypeContent(SerializedProperty property)
    {
        return BuildManagedReferenceTypeContent(property, null);
    }

    private static GUIContent BuildManagedReferenceTypeContent(
        SerializedProperty property,
        PolymorphicDrawerSettingsAttribute polymorphicSettings = null)
    {
        Type baseType = ResolveManagedReferenceBaseType(property);
        Type currentType = GetManagedReferenceCurrentType(property);
        string currentTypeName = currentType == null ? "None" : GetManagedReferenceDisplayName(currentType);
        bool showBaseType = polymorphicSettings?.ShowBaseType == true && baseType != null;

        if (currentType == null)
        {
            string label = showBaseType
                ? $"None ({GetManagedReferenceDisplayName(baseType)})"
                : "None";
            string tooltip = showBaseType
                ? $"None ({GetFriendlyManagedReferenceTypeName(baseType)})"
                : "当前未选择具体派生类型。";
            return new GUIContent(label, tooltip);
        }

        string text = showBaseType
            ? $"{currentTypeName} ({GetManagedReferenceDisplayName(baseType)})"
            : currentTypeName;
        string fullTypeName = GetFriendlyManagedReferenceTypeName(currentType);
        string tooltipText = showBaseType
            ? $"{fullTypeName} ({GetFriendlyManagedReferenceTypeName(baseType)})"
            : fullTypeName;
        return new GUIContent(text, tooltipText);
    }

    private static GUIContent BuildManagedReferenceCompactFieldContent(
        SerializedProperty property,
        PolymorphicDrawerSettingsAttribute polymorphicSettings)
    {
        GUIContent content = BuildManagedReferenceTypeContent(property, polymorphicSettings);
        Type currentType = GetManagedReferenceCurrentType(property);
        string compactText = string.IsNullOrWhiteSpace(content?.text)
            ? (currentType == null ? "None" : GetManagedReferenceDisplayName(currentType))
            : content.text;
        string tooltip = content?.tooltip ?? string.Empty;
        if (currentType != null)
        {
            string subtitle = GetManagedReferenceDisplaySubtitle(currentType);
            if (!string.IsNullOrWhiteSpace(subtitle))
            {
                tooltip = string.IsNullOrWhiteSpace(tooltip)
                    ? subtitle
                    : $"{subtitle}\n{tooltip}";
            }
        }
        else if (!string.IsNullOrWhiteSpace(content?.tooltip))
        {
            tooltip = content.tooltip;
        }

        return new GUIContent(compactText, tooltip);
    }

    internal static string GetManagedReferenceDisplayName(Type type)
    {
        if (type == null)
        {
            return "None";
        }

        ManagedReferenceTypeDisplayNameAttribute displayNameAttribute = type.GetCustomAttribute<ManagedReferenceTypeDisplayNameAttribute>(false);
        if (displayNameAttribute != null && !string.IsNullOrWhiteSpace(displayNameAttribute.DisplayName))
        {
            return displayNameAttribute.DisplayName;
        }

        return ObjectNames.NicifyVariableName(type.Name);
    }

    internal static string GetManagedReferenceDisplaySubtitle(Type type)
    {
        if (type == null)
        {
            return "当前未选择具体类型";
        }

        ManagedReferenceTypeDisplayNameAttribute displayNameAttribute = type.GetCustomAttribute<ManagedReferenceTypeDisplayNameAttribute>(false);
        if (displayNameAttribute != null && !string.IsNullOrWhiteSpace(displayNameAttribute.Subtitle))
        {
            return displayNameAttribute.Subtitle;
        }

        return GetFriendlyManagedReferenceTypeName(type);
    }

    private static string BuildManagedReferenceSubtitle(
        Type baseType,
        Type currentType,
        PolymorphicDrawerSettingsAttribute polymorphicSettings)
    {
        if (currentType == null)
        {
            if (polymorphicSettings?.ShowBaseType == true && baseType != null)
            {
                return $"基类：{GetManagedReferenceDisplaySubtitle(baseType)}";
            }

            return "当前未选择具体类型";
        }

        string subtitle = GetManagedReferenceDisplaySubtitle(currentType);
        if (polymorphicSettings?.ShowBaseType == true && baseType != null && currentType != baseType)
        {
            return $"{subtitle}  |  基类：{GetManagedReferenceDisplayName(baseType)}";
        }

        return subtitle;
    }

    internal static string GetFriendlyManagedReferenceTypeName(Type type)
    {
        if (type == null)
        {
            return "None";
        }

        return type.FullName?.Replace('+', '.') ?? type.Name;
    }

    private DictionaryDrawerSettingsAttribute GetSettings()
    {
        return fieldInfo?.GetCustomAttribute<DictionaryDrawerSettingsAttribute>()
            ?? new DictionaryDrawerSettingsAttribute();
    }

    private PolymorphicDrawerSettingsAttribute GetPolymorphicSettings()
    {
        return fieldInfo?.GetCustomAttribute<PolymorphicDrawerSettingsAttribute>()
            ?? new PolymorphicDrawerSettingsAttribute();
    }

    private TypeSelectorSettingsAttribute GetTypeSelectorSettings()
    {
        return fieldInfo?.GetCustomAttribute<TypeSelectorSettingsAttribute>()
            ?? new TypeSelectorSettingsAttribute();
    }

    private void EnsureDefaultFoldoutState(SerializedProperty property, DictionaryDrawerSettingsAttribute settings)
    {
        if (settings.DisplayMode == DictionaryDisplayOptions.OneLine)
        {
            return;
        }

        string targetKey = GetTargetObjectStateKey(property.serializedObject.targetObject);
        string stateKey = $"{targetKey}::{property.propertyPath}";
        if (!FoldoutStatesInitialized.Add(stateKey))
        {
            return;
        }

        if (settings.DisplayMode == DictionaryDisplayOptions.ExpandedFoldout)
        {
            property.isExpanded = true;
        }
        else if (settings.DisplayMode == DictionaryDisplayOptions.CollapsedFoldout)
        {
            property.isExpanded = false;
        }
    }

    private void SyncRuntimeDictionary(SerializedProperty property)
    {
        property.serializedObject.ApplyModifiedProperties();

        foreach (Object targetObject in property.serializedObject.targetObjects)
        {
            if (fieldInfo?.GetValue(targetObject) is SerializableDictionaryBase dictionary)
            {
                dictionary.OnAfterDeserialize();
                EditorUtility.SetDirty(targetObject);
            }
        }
    }

    private static string GetTargetObjectStateKey(Object targetObject)
    {
        return targetObject == null ? "null" : targetObject.GetHashCode().ToString();
    }
}
