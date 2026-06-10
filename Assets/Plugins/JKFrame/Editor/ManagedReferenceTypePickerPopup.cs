using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.IMGUI.Controls;
using UnityEngine;

/// <summary>
/// SerializeReference 类型选择弹窗：提供搜索和单击选择，用于把多态字典值的类型切换体验继续拉近 Odin。
/// </summary>
public sealed class ManagedReferenceTypePickerPopup : PopupWindowContent
{
    private const float PopupWidth = 424f;
    private const float PopupHeight = 320f;
    private const float ToolbarHeight = 22f;
    private const float RowHeight = 18f;
    private const float HeaderHeight = 17f;
    private const float SearchHeight = 18f;
    private const float Padding = 4f;
    private const float RowSeparatorHeight = 1f;
    private const float GroupedRowIndent = 18f;
    private const float TreeIndentWidth = 14f;
    private const float TreeGuideStartX = 12f;

    private readonly IReadOnlyList<Type> candidateTypes;
    private readonly Type currentType;
    private readonly Action<Type> onTypeSelected;
    private readonly TypeSelectorSettingsAttribute settings;
    private readonly SearchField searchField = new SearchField();
    private readonly Dictionary<string, bool> categoryExpandedStates = new Dictionary<string, bool>(StringComparer.Ordinal);

    private Vector2 scrollPosition;
    private string searchText = string.Empty;

    private readonly struct VisibleEntry
    {
        public VisibleEntry(string header)
        {
            Header = header;
            CandidateType = null;
            IsHeader = true;
        }

        public VisibleEntry(Type candidateType)
        {
            Header = string.Empty;
            CandidateType = candidateType;
            IsHeader = false;
        }

        public string Header { get; }

        public Type CandidateType { get; }

        public bool IsHeader { get; }

        public float Height => IsHeader ? HeaderHeight : RowHeight;
    }

    public ManagedReferenceTypePickerPopup(
        IReadOnlyList<Type> candidateTypes,
        Type currentType,
        TypeSelectorSettingsAttribute settings,
        Action<Type> onTypeSelected,
        string initialSearchText = "")
    {
        this.candidateTypes = candidateTypes ?? Array.Empty<Type>();
        this.currentType = currentType;
        this.settings = settings ?? new TypeSelectorSettingsAttribute();
        this.onTypeSelected = onTypeSelected;
        searchText = initialSearchText ?? string.Empty;
    }

    public override Vector2 GetWindowSize()
    {
        return new Vector2(PopupWidth, PopupHeight);
    }

    public override void OnGUI(Rect rect)
    {
        GUI.BeginGroup(rect);
        try
        {
            Rect localRect = new Rect(0f, 0f, rect.width, rect.height);
            Rect toolbarRect = new Rect(Padding, Padding, localRect.width - (Padding * 2f), ToolbarHeight);

            Rect searchBadgeRect = new Rect(localRect.width - Padding - 44f, toolbarRect.yMax + 3f, 44f, SearchHeight);
            Rect searchRect = new Rect(Padding, toolbarRect.yMax + 3f, localRect.width - (Padding * 2f) - 48f, SearchHeight);
            searchText = searchField.OnGUI(searchRect, searchText);

            List<VisibleEntry> entries = BuildVisibleEntries(candidateTypes, searchText, settings);
            int visibleTypeCount = CountVisibleTypes(entries);
            DrawToolbar(toolbarRect, visibleTypeCount);
            DrawSearchResultBadge(searchBadgeRect, visibleTypeCount);

            Rect listRect = new Rect(
                Padding,
                searchRect.yMax + Padding,
                localRect.width - (Padding * 2f),
                localRect.height - toolbarRect.height - searchRect.height - (Padding * 4f) - 3f);

            GUI.Box(listRect, GUIContent.none);

            Rect contentRect = new Rect(0f, 0f, listRect.width - 16f, GetContentHeight(entries, settings.ShowNoneItem));
            scrollPosition = GUI.BeginScrollView(listRect, scrollPosition, contentRect);

            float y = 0f;
            if (settings.ShowNoneItem)
            {
                DrawTypeRow(new Rect(0f, y, contentRect.width, RowHeight), "None", null, false, 0);
                y += RowHeight;
            }

            bool hasVisibleTypes = entries.Count > 0;
            bool hasGroupedHeaders = entries.Exists(entry => entry.IsHeader);
            bool currentCategoryExpanded = true;
            int currentCategoryDepth = 0;
            for (int i = 0; i < entries.Count; i++)
            {
                VisibleEntry entry = entries[i];
                if (entry.IsHeader)
                {
                    int typeCount = GetCategoryVisibleTypeCount(entries, i);
                    currentCategoryDepth = GetHeaderDepth(entries, i);
                    currentCategoryExpanded = GetCategoryExpandedState(entry.Header);
                    bool nextExpanded = DrawHeaderRow(
                        new Rect(0f, y, contentRect.width, HeaderHeight),
                        GetHeaderDisplayLabel(entries, i),
                        typeCount,
                        currentCategoryExpanded,
                        currentCategoryDepth);
                    if (nextExpanded != currentCategoryExpanded)
                    {
                        categoryExpandedStates[entry.Header] = nextExpanded;
                        currentCategoryExpanded = nextExpanded;
                    }

                    y += HeaderHeight;
                    continue;
                }

                if (hasGroupedHeaders && !currentCategoryExpanded)
                {
                    continue;
                }

                DrawTypeRow(
                    new Rect(0f, y, contentRect.width, RowHeight),
                    SerializableDictionaryDrawer.GetManagedReferenceDisplayName(entry.CandidateType),
                    entry.CandidateType,
                    hasGroupedHeaders,
                    currentCategoryDepth);
                y += RowHeight;
            }

            if (!hasVisibleTypes)
            {
                Rect emptyRect = new Rect(Padding, y + 2f, contentRect.width - (Padding * 2f), RowHeight + 10f);
                GUI.Label(
                    new Rect(emptyRect.x + (emptyRect.width * 0.5f) - 8f, emptyRect.y + 2f, 16f, 16f),
                    EditorGUIUtility.IconContent("Search Icon"));
                EditorGUI.LabelField(
                    new Rect(emptyRect.x, emptyRect.y + 18f, emptyRect.width, 16f),
                    "没有匹配的可序列化派生类型",
                    EditorStyles.centeredGreyMiniLabel);
            }

            GUI.EndScrollView();
        }
        finally
        {
            GUI.EndGroup();
        }
    }

    private void DrawToolbar(Rect rect, int visibleTypeCount)
    {
        Color backgroundColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.025f)
            : new Color(0f, 0f, 0f, 0.020f);
        Color borderColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.08f)
            : new Color(0f, 0f, 0f, 0.08f);

        EditorGUI.DrawRect(rect, backgroundColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - 1f, rect.width, 1f), borderColor);

        Rect titleRect = new Rect(rect.x + 8f, rect.y + 2f, 88f, 16f);
        Rect subtitleRect = new Rect(rect.x + 78f, rect.y + 4f, rect.width - 128f, 12f);
        Rect badgeRect = new Rect(rect.xMax - 38f, rect.y + 4f, 30f, 14f);
        EditorGUI.LabelField(titleRect, "选择类型", EditorStyles.label);
        DrawToolbarBadge(badgeRect, visibleTypeCount.ToString());

        string subtitle = currentType == null
            ? "当前值为空"
            : $"当前：{SerializableDictionaryDrawer.GetManagedReferenceDisplayName(currentType)}";
        EditorGUI.LabelField(subtitleRect, subtitle, EditorStyles.miniLabel);
    }

    private static void DrawToolbarBadge(Rect rect, string label)
    {
        Color backgroundColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.05f)
            : new Color(0f, 0f, 0f, 0.05f);
        Color borderColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.08f)
            : new Color(0f, 0f, 0f, 0.08f);

        EditorGUI.DrawRect(rect, backgroundColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - 1f, rect.width, 1f), borderColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.y, rect.width, 1f), borderColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.y, 1f, rect.height), borderColor);
        EditorGUI.DrawRect(new Rect(rect.xMax - 1f, rect.y, 1f, rect.height), borderColor);

        GUIStyle style = new GUIStyle(EditorStyles.miniLabel)
        {
            alignment = TextAnchor.MiddleCenter,
            clipping = TextClipping.Clip
        };
        EditorGUI.LabelField(rect, label, style);
    }

    private static void DrawSearchResultBadge(Rect rect, int visibleTypeCount)
    {
        Color backgroundColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.035f)
            : new Color(0f, 0f, 0f, 0.040f);
        EditorGUI.DrawRect(rect, backgroundColor);
        EditorGUI.LabelField(rect, visibleTypeCount.ToString(), EditorStyles.centeredGreyMiniLabel);
    }

    private static int CountVisibleTypes(IReadOnlyList<VisibleEntry> entries)
    {
        int count = 0;
        for (int i = 0; i < entries.Count; i++)
        {
            if (!entries[i].IsHeader)
            {
                count++;
            }
        }

        return count;
    }

    private float GetContentHeight(IReadOnlyList<VisibleEntry> entries, bool includeNoneRow)
    {
        float totalHeight = includeNoneRow ? RowHeight : 0f;
        bool currentCategoryExpanded = true;
        bool hasHeaders = false;
        for (int i = 0; i < entries.Count; i++)
        {
            if (entries[i].IsHeader)
            {
                hasHeaders = true;
                break;
            }
        }

        for (int i = 0; i < entries.Count; i++)
        {
            VisibleEntry entry = entries[i];
            if (entry.IsHeader)
            {
                totalHeight += entry.Height;
                currentCategoryExpanded = GetCategoryExpandedState(entry.Header);
                continue;
            }

            if (!currentCategoryExpanded && hasHeaders)
            {
                continue;
            }

            totalHeight += entry.Height;
        }

        return Mathf.Max(RowHeight * 3f, totalHeight);
    }

    private bool GetCategoryExpandedState(string categoryKey)
    {
        if (string.IsNullOrWhiteSpace(categoryKey))
        {
            return true;
        }

        return !categoryExpandedStates.TryGetValue(categoryKey, out bool expanded) || expanded;
    }

    private static int GetCategoryVisibleTypeCount(IReadOnlyList<VisibleEntry> entries, int headerIndex)
    {
        int count = 0;
        for (int i = headerIndex + 1; i < entries.Count; i++)
        {
            if (entries[i].IsHeader)
            {
                break;
            }

            count++;
        }

        return count;
    }

    private static bool IsMatch(Type candidateType, string filter)
    {
        if (candidateType == null || string.IsNullOrWhiteSpace(filter))
        {
            return candidateType != null;
        }

        string normalizedFilter = filter.Trim();
        string fullName = SerializableDictionaryDrawer.GetFriendlyManagedReferenceTypeName(candidateType);
        string displayName = SerializableDictionaryDrawer.GetManagedReferenceDisplayName(candidateType);
        return fullName.IndexOf(normalizedFilter, StringComparison.OrdinalIgnoreCase) >= 0
            || displayName.IndexOf(normalizedFilter, StringComparison.OrdinalIgnoreCase) >= 0
            || candidateType.Name.IndexOf(normalizedFilter, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static List<VisibleEntry> BuildVisibleEntries(
        IReadOnlyList<Type> candidateTypes,
        string filter,
        TypeSelectorSettingsAttribute settings)
    {
        List<VisibleEntry> entries = new List<VisibleEntry>();
        settings ??= new TypeSelectorSettingsAttribute();
        string currentCategory = null;
        for (int i = 0; i < candidateTypes.Count; i++)
        {
            Type candidateType = candidateTypes[i];
            if (!IsMatch(candidateType, filter))
            {
                continue;
            }

            string category = GetCategoryLabel(candidateType, settings);
            if (settings.ShowCategories && !string.Equals(currentCategory, category, StringComparison.Ordinal))
            {
                entries.Add(new VisibleEntry(category));
                currentCategory = category;
            }

            entries.Add(new VisibleEntry(candidateType));
        }

        if (!settings.ShowCategories)
        {
            return entries;
        }

        int headerCount = 0;
        for (int i = 0; i < entries.Count; i++)
        {
            if (entries[i].IsHeader)
            {
                headerCount++;
            }
        }

        if (headerCount <= 1)
        {
            entries.RemoveAll(entry => entry.IsHeader);
        }

        return entries;
    }

    private static string GetCategoryLabel(Type candidateType, TypeSelectorSettingsAttribute settings)
    {
        if (candidateType == null)
        {
            return "None";
        }

        if (settings != null && !settings.PreferNamespaces)
        {
            return ObjectNames.NicifyVariableName(candidateType.Assembly.GetName().Name);
        }

        return string.IsNullOrWhiteSpace(candidateType.Namespace)
            ? "Global"
            : candidateType.Namespace;
    }

    private static int GetHeaderDepth(IReadOnlyList<VisibleEntry> entries, int headerIndex)
    {
        if (entries == null || headerIndex < 0 || headerIndex >= entries.Count || !entries[headerIndex].IsHeader)
        {
            return 0;
        }

        string header = entries[headerIndex].Header;
        string parentHeader = null;
        for (int i = 0; i < headerIndex; i++)
        {
            if (!entries[i].IsHeader)
            {
                continue;
            }

            string candidateHeader = entries[i].Header;
            if (string.IsNullOrWhiteSpace(candidateHeader)
                || !header.StartsWith(candidateHeader + ".", StringComparison.Ordinal)
                || (parentHeader != null && candidateHeader.Length <= parentHeader.Length))
            {
                continue;
            }

            parentHeader = candidateHeader;
        }

        if (string.IsNullOrWhiteSpace(parentHeader))
        {
            return 0;
        }

        for (int i = 0; i < headerIndex; i++)
        {
            if (entries[i].IsHeader && string.Equals(entries[i].Header, parentHeader, StringComparison.Ordinal))
            {
                return GetHeaderDepth(entries, i) + 1;
            }
        }

        return 1;
    }

    private static string GetHeaderDisplayLabel(IReadOnlyList<VisibleEntry> entries, int headerIndex)
    {
        if (entries == null || headerIndex < 0 || headerIndex >= entries.Count || !entries[headerIndex].IsHeader)
        {
            return string.Empty;
        }

        string header = entries[headerIndex].Header;
        string parentHeader = null;
        for (int i = 0; i < headerIndex; i++)
        {
            if (!entries[i].IsHeader)
            {
                continue;
            }

            string candidateHeader = entries[i].Header;
            if (string.IsNullOrWhiteSpace(candidateHeader)
                || !header.StartsWith(candidateHeader + ".", StringComparison.Ordinal)
                || (parentHeader != null && candidateHeader.Length <= parentHeader.Length))
            {
                continue;
            }

            parentHeader = candidateHeader;
        }

        if (string.IsNullOrWhiteSpace(parentHeader))
        {
            return header;
        }

        return header[(parentHeader.Length + 1)..];
    }

    private static bool DrawHeaderRow(Rect rect, string label, int typeCount, bool expanded, int depth)
    {
        Color backgroundColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.032f)
            : new Color(0f, 0f, 0f, 0.036f);
        Color borderColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.055f)
            : new Color(0f, 0f, 0f, 0.065f);
        EditorGUI.DrawRect(rect, backgroundColor);
        EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - 1f, rect.width, 1f), borderColor);

        float indent = depth * TreeIndentWidth;
        DrawTreeGuides(rect, depth, false);

        Rect arrowRect = new Rect(rect.x + 6f + indent, rect.y + 1f, 12f, rect.height - 2f);
        Rect textRect = new Rect(rect.x + 20f + indent, rect.y, rect.width - 78f - indent, rect.height);
        Rect badgeRect = new Rect(rect.xMax - 30f, rect.y + 2f, 22f, rect.height - 4f);
        GUIStyle headerStyle = new GUIStyle(EditorStyles.miniBoldLabel)
        {
            alignment = TextAnchor.MiddleLeft,
            clipping = TextClipping.Clip
        };
        if (EditorGUIUtility.isProSkin)
        {
            headerStyle.normal.textColor = new Color(0.82f, 0.82f, 0.82f, 0.92f);
        }

        Rect toggleRect = new Rect(rect.x, rect.y, rect.width, rect.height);
        if (Event.current.type == EventType.MouseDown && toggleRect.Contains(Event.current.mousePosition))
        {
            expanded = !expanded;
            Event.current.Use();
        }

        EditorGUI.LabelField(arrowRect, EditorGUIUtility.IconContent(expanded ? "IN foldout on" : "IN foldout"), EditorStyles.label);
        EditorGUI.LabelField(textRect, label, headerStyle);
        DrawToolbarBadge(badgeRect, typeCount.ToString());
        return expanded;
    }

    private void DrawTypeRow(Rect rect, string label, Type candidateType, bool isGrouped, int headerDepth)
    {
        bool isCurrent = currentType == candidateType;
        bool isHover = rect.Contains(Event.current.mousePosition);
        Color rowBackground = GetRowBackgroundColor(isCurrent, isHover);
        EditorGUI.DrawRect(rect, rowBackground);
        if (isCurrent)
        {
            Color currentDividerColor = EditorGUIUtility.isProSkin
                ? new Color(1f, 1f, 1f, 0.12f)
                : new Color(0f, 0f, 0f, 0.14f);
            EditorGUI.DrawRect(new Rect(rect.x, rect.y, 1f, rect.height), currentDividerColor);
        }

        DrawRowSeparator(rect);

        if (GUI.Button(rect, GUIContent.none, GUIStyle.none))
        {
            onTypeSelected?.Invoke(candidateType);
            editorWindow?.Close();
            return;
        }

        float indent = candidateType != null && isGrouped ? GroupedRowIndent + (headerDepth * TreeIndentWidth) : 0f;
        if (candidateType != null && isGrouped)
        {
            DrawTreeGuides(rect, headerDepth + 1, true);
        }

        Rect contentRect = new Rect(rect.x + 14f + indent, rect.y + 1f, rect.width - 22f - indent, rect.height - 2f);
        if (candidateType == null)
        {
            Rect emptyRect = new Rect(contentRect.x, contentRect.y + 1f, contentRect.width - 4f, 16f);
            EditorGUI.LabelField(emptyRect, "None", EditorStyles.label);
            return;
        }

        GUIStyle labelStyle = new GUIStyle(EditorStyles.label)
        {
            clipping = TextClipping.Clip
        };
        if (EditorGUIUtility.isProSkin)
        {
            labelStyle.normal.textColor = isCurrent
                ? new Color(0.88f, 0.88f, 0.88f, 0.98f)
                : new Color(0.80f, 0.80f, 0.80f, 0.94f);
        }
        Rect titleRect = new Rect(contentRect.x, contentRect.y, contentRect.width - 8f, 16f);
        EditorGUI.LabelField(titleRect, label, labelStyle);
    }

    private static Color GetRowBackgroundColor(bool isCurrent, bool isHover)
    {
        if (isCurrent)
        {
            return EditorGUIUtility.isProSkin
                ? new Color(1f, 1f, 1f, 0.050f)
                : new Color(0f, 0f, 0f, 0.045f);
        }

        if (isHover)
        {
            return EditorGUIUtility.isProSkin
                ? new Color(1f, 1f, 1f, 0.045f)
                : new Color(0f, 0f, 0f, 0.035f);
        }

        return EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.010f)
            : new Color(0f, 0f, 0f, 0.008f);
    }

    private static void DrawRowSeparator(Rect rect)
    {
        Color separatorColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.05f)
            : new Color(0f, 0f, 0f, 0.06f);
        EditorGUI.DrawRect(
            new Rect(rect.x + 6f, rect.yMax - RowSeparatorHeight, rect.width - 12f, RowSeparatorHeight),
            separatorColor);
    }

    private static void DrawTreeGuides(Rect rect, int depth, bool drawLeafConnector)
    {
        Color guideColor = EditorGUIUtility.isProSkin
            ? new Color(1f, 1f, 1f, 0.060f)
            : new Color(0f, 0f, 0f, 0.080f);

        if (depth <= 0)
        {
            return;
        }

        for (int level = 0; level < depth; level++)
        {
            float guideX = rect.x + TreeGuideStartX + (level * TreeIndentWidth);
            EditorGUI.DrawRect(new Rect(guideX, rect.y, 1f, rect.height), guideColor);
        }

        if (!drawLeafConnector)
        {
            return;
        }

        float connectorX = rect.x + TreeGuideStartX + ((depth - 1) * TreeIndentWidth);
        EditorGUI.DrawRect(new Rect(connectorX, rect.center.y, TreeIndentWidth - 2f, 1f), guideColor);
    }

}
