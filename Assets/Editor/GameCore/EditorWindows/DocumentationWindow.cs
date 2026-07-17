using System;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// 文档窗口可展示和编辑的文档合同，隐藏 Markdown 文件来源和缓存细节。
    /// </summary>
    public interface IDocument
    {
        string Title { get; }
        string RawContent { get; }
        string Content { get; }
        string FilePath { get; }
        string BaseFolder { get; }
        string LastModified { get; }
        string RelativeFilePath { get; }
        bool IsProtected { get; }
        string[] Categories { get; }

        void MovePath(string newPath);
        void Reload();
    }

    /// <summary>
    /// FantasyWord 编辑器文档窗口，支持搜索、预览、编辑和创建项目 Markdown 文档。
    /// </summary>
    public class DocumentationWindow : EditorWindow
    {
        private static IDocument[] m_documents = null;
        private string m_searchString = "";
        private IDocument m_selectedDocument = null;
        private IDocument[] m_cachedFilteredDocuments = null;
        private string m_previousSearchString = "";
        private string m_defaultPage = null;
        private string m_documentationPath = null;
        private FileSystemWatcher m_watcher = null;

        private Vector2 m_listScrollPosition;
        private Vector2 m_contentScrollPosition;

        private bool m_searchInPath = true;
        private bool m_searchInTitle = true;
        private bool m_searchInContent = true;
        private bool m_forceCachingFilteredDocuments = false;

        private bool m_isEditing = false;
        private string m_editingContent = "";
        private bool m_allowedEditingProtectedDocuments = false;

        [MenuItem("Window/FantasyWord/Documentation")]
        public static void ShowWindowMenuItem() => ShowWindow(null);

        public static void ShowWindow(string defaultPage = null)
        {
            DocumentationWindow window = GetWindow<DocumentationWindow>();
            window.titleContent = new GUIContent("Documentation");
            if (window.Init(defaultPage ?? "Getting Started"))
            {
                window.Show();
            }
            else
            {
                EditorUtility.DisplayDialog("Error", $"Could not find the FantasyWord documentation folder. Please make sure the '{DocumentationUtil.kDocumentationRootFile}' file is in the project directory or any of its subdirectories.", "OK");
            }
        }

        private bool Init(string defaultPage = null)
        {
            m_documents = null;
            m_defaultPage = defaultPage;
            m_documentationPath = DocumentationUtil.GetDocumentationFolderPath();

            return m_documentationPath != null;
        }

        private void OnEnable()
        {
            // Check if we need to reinitialize (after editor restart)
            if (!Init())
            {
                Close(); // Force closing the window
            }
        }

        private void WatchDocumentChanges()
        {
            m_watcher = new FileSystemWatcher(m_documentationPath)
            {
                NotifyFilter = NotifyFilters.Attributes
                             | NotifyFilters.CreationTime
                             | NotifyFilters.DirectoryName
                             | NotifyFilters.FileName
                             | NotifyFilters.LastAccess
                             | NotifyFilters.LastWrite
                             | NotifyFilters.Security
                             | NotifyFilters.Size,
                Filter = "*.md",
                IncludeSubdirectories = true,
                EnableRaisingEvents = true
            };

            m_watcher.Changed += OnChanged;
            m_watcher.Created += OnCreated;
            m_watcher.Deleted += OnDeleted;
            m_watcher.Error += OnError;
        }

        private void OnChanged(object sender, FileSystemEventArgs e)
        {
            if (e.ChangeType == WatcherChangeTypes.Changed)
            {
                FindDocumentByPath(e.FullPath)?.Reload();
            }
        }

        private void OnCreated(object sender, FileSystemEventArgs e)
        {
            m_documents = m_documents.Append(new MarkdownDocument(m_documentationPath, e.FullPath)).ToArray();
            LoadDocumentationFiles();
        }

        private void OnDeleted(object sender, FileSystemEventArgs e)
        {
            IDocument deletedDocument = FindDocumentByPath(e.FullPath);

            if (m_selectedDocument == deletedDocument)
            {
                m_selectedDocument = null;
            }

            LoadDocumentationFiles();
            m_isEditing = false;
        }

        private void OnError(object sender, ErrorEventArgs e) => Debug.LogError(e.GetException());

        public void LoadDocumentationFiles()
        {
            string previouslySelectedTitle = m_selectedDocument?.Title;

            string[] filePaths = Directory.GetFiles(m_documentationPath, "*.md", SearchOption.AllDirectories);
            m_documents = filePaths.Select(filePath => new MarkdownDocument(m_documentationPath, filePath)).ToArray();
            m_forceCachingFilteredDocuments = true;

            TryToSelectDocument(previouslySelectedTitle);
        }

        private IDocument FindDocumentByTitle(string title)
        {
            return m_documents.FirstOrDefault(doc => doc.Title == title);
        }

        private IDocument FindDocumentByPath(string path)
        {
            string fullPath = Path.GetFullPath(path);
            return m_documents.FirstOrDefault(doc => Path.GetFullPath(doc.FilePath) == fullPath);
        }

        private void TryToSelectDocument(string title)
        {
            if (m_documents != null && !string.IsNullOrEmpty(title))
            {
                m_selectedDocument = FindDocumentByTitle(title);
            }
        }

        private void OnGUI()
        {
            GUILayout.BeginHorizontal();

            GUI.enabled = !m_isEditing;
            DrawDocumentListPanel();
            GUI.enabled = true;

            DrawDocumentContentPanel();

            GUILayout.EndHorizontal();
        }

        private void DrawDocumentListPanel()
        {
            if (m_documents == null)
            {
                LoadDocumentationFiles();
                TryToSelectDocument(m_defaultPage);
                WatchDocumentChanges();
            }

            GUILayout.BeginVertical(GUILayout.Width(250));

            DrawSearchField();
            DrawDocumentList();

            GUILayout.EndVertical();
        }

        private void DrawSearchField()
        {
            GUILayout.BeginHorizontal();

            m_previousSearchString = m_searchString;
            m_searchString = GUILayout.TextField(m_searchString, EditorStyles.toolbarSearchField);
            if (GUILayout.Button("Clear", EditorStyles.toolbarButton, GUILayout.Width(40)))
            {
                m_searchString = "";
                m_cachedFilteredDocuments = null;
            }

            GUILayout.EndHorizontal();

            GUILayout.BeginHorizontal();

            GUILayout.Label("Search in:", EditorStyles.label);
            m_searchInPath = GUILayout.Toggle(m_searchInPath, "Path", EditorStyles.toggle);
            m_searchInTitle = GUILayout.Toggle(m_searchInTitle, "Title", EditorStyles.toggle);
            m_searchInContent = GUILayout.Toggle(m_searchInContent, "Content", EditorStyles.toggle);

            GUILayout.EndHorizontal();

            if (!string.IsNullOrEmpty(m_searchString))
            {
                string sanitizedPath = SanitizePath(m_searchString);
                if (GUILayout.Button($"Create Page: \"{sanitizedPath}.md\"", EditorStyles.toolbarButton))
                {
                    CreateNewMarkdownDocument(sanitizedPath);
                    LoadDocumentationFiles();
                }
            }

            if (string.IsNullOrEmpty(m_searchString))
            {
                m_cachedFilteredDocuments = null;
            }
            else if (m_forceCachingFilteredDocuments || m_previousSearchString != m_searchString)
            {
                m_forceCachingFilteredDocuments = false;
                m_cachedFilteredDocuments = FilterDocuments();
                AutoSelectFirstSearchResult();
            }
        }

        private IDocument[] FilterDocuments()
        {
            return m_documents
                .Where(document => (m_searchInTitle && document.Title.IndexOf(m_searchString, StringComparison.OrdinalIgnoreCase) >= 0) ||
                                   (m_searchInContent && Regex.Replace(document.Content, "<.*?>", string.Empty).IndexOf(m_searchString, StringComparison.OrdinalIgnoreCase) >= 0) ||
                                   (m_searchInPath && document.RelativeFilePath.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar).IndexOf(m_searchString.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar), StringComparison.OrdinalIgnoreCase) >= 0))
                .OrderByDescending(document => Regex.Matches(document.Content, Regex.Escape(m_searchString), RegexOptions.IgnoreCase).Count)
                .ThenBy(document => document.Title)
                .ToArray();
        }

        private void AutoSelectFirstSearchResult()
        {
            if (m_cachedFilteredDocuments.Length > 0 && !m_cachedFilteredDocuments.Contains(m_selectedDocument))
            {
                m_selectedDocument = m_cachedFilteredDocuments[0];
            }
        }

        private void DrawDocumentList()
        {
            var filteredDocuments = m_cachedFilteredDocuments ?? m_documents;

            m_listScrollPosition = EditorGUILayout.BeginScrollView(m_listScrollPosition);

            string[] documentTitles = filteredDocuments.Select(document => document.Title).ToArray();
            int previousSelectedIndex = Array.IndexOf(filteredDocuments, m_selectedDocument);
            int newSelectedIndex = GUILayout.SelectionGrid(previousSelectedIndex, documentTitles, 1, EditorStyles.objectField);

            EditorGUILayout.EndScrollView();

            if (newSelectedIndex >= 0 && previousSelectedIndex != newSelectedIndex)
            {
                m_selectedDocument = filteredDocuments[newSelectedIndex];
                GUI.FocusControl(null);
                m_contentScrollPosition = Vector2.zero;
            }
        }

        private void DrawDocumentContentPanel()
        {
            GUILayout.BeginVertical();

            if (m_selectedDocument != null)
            {
                DrawBreadcrumb();
                m_contentScrollPosition = GUILayout.BeginScrollView(m_contentScrollPosition);

                if (m_isEditing)
                {
                    DrawEditingContent();
                }
                else
                {
                    DrawDocumentContent();
                }

                GUILayout.EndScrollView();
                DrawDocumentActionButtons();
            }
            else
            {
                DrawNoDocumentSelectedMessage();
            }

            GUILayout.EndVertical();
        }

        private void DrawEditingContent()
        {
            GUIStyle textStyle = new(GUI.skin.textField)
            {
                stretchWidth = true,
                stretchHeight = true,
                richText = false,
                padding = new RectOffset(10, 10, 10, 10),
                margin = new RectOffset(5, 5, 5, 5),
                fontSize = 14,
                alignment = TextAnchor.UpperLeft,
                wordWrap = true
            };

            m_editingContent = EditorGUILayout.TextArea(m_editingContent, textStyle, GUILayout.ExpandHeight(true));
        }

        private void DrawDocumentContent()
        {
            GUIStyle textStyle = new(GUI.skin.textField)
            {
                stretchWidth = true,
                stretchHeight = true,
                richText = true,
                padding = new RectOffset(10, 10, 10, 10),
                margin = new RectOffset(5, 5, 5, 5),
                fontSize = 14,
                alignment = TextAnchor.UpperLeft,
                wordWrap = true
            };

            string highlightedContent = HighlightSearchString(m_selectedDocument.Content, m_searchString);
            string text = EditorGUILayout.TextArea(highlightedContent, textStyle, GUILayout.ExpandHeight(true));
            if (text != highlightedContent)
            {
                GUI.FocusControl(null);
            }
        }

        private void DrawDocumentActionButtons()
        {
            GUILayout.BeginHorizontal();

            string suffix = "";

            if (m_isEditing && m_selectedDocument.RawContent != m_editingContent)
            {
                suffix = " (unsaved changes)";
            }

            GUILayout.Label("Last modified: " + m_selectedDocument.LastModified + suffix, EditorStyles.miniLabel);

            GUILayout.FlexibleSpace();
            if (m_isEditing)
            {
                DrawEditingButtons();
            }
            else
            {
                DrawViewButtons();
            }
            GUILayout.EndHorizontal();
        }

        private void DrawEditingButtons()
        {
            GUI.enabled = m_selectedDocument.RawContent != m_editingContent;
            if (GUILayout.Button("Save", GUILayout.Width(80)))
            {
                GUI.FocusControl(null);
                SaveDocument(m_selectedDocument);
            }
            if (GUILayout.Button("Save & Exit", GUILayout.Width(80)))
            {
                GUI.FocusControl(null);
                SaveDocument(m_selectedDocument);
                m_selectedDocument.Reload();
                m_isEditing = false;
            }
            GUI.enabled = true;
            if (GUILayout.Button("Exit", GUILayout.Width(80)))
            {
                string previousContent = m_selectedDocument.RawContent;
                bool didContentChange = m_editingContent != previousContent;
                if (!didContentChange || EditorUtility.DisplayDialog("Stop Editing", "Are you sure you want to stop editing? Any unsaved changes will be lost.", "Cancel", "Stop Editing"))
                {
                    GUI.FocusControl(null);
                    m_editingContent = "";
                    m_isEditing = false;
                }
            }
        }

        private void DrawViewButtons()
        {
            if (GUILayout.Button("Edit", GUILayout.Width(80)))
            {
                if (!m_selectedDocument.IsProtected || m_allowedEditingProtectedDocuments || EditorUtility.DisplayDialog("Edit Document", "This document is protected (FantasyWord built-in documentation). Any saved change will override the original content. Are you sure you want to edit this document?", "Edit", "Cancel"))
                {
                    // Remember if the user has edited a protected document before
                    if (m_selectedDocument.IsProtected)
                    {
                        m_allowedEditingProtectedDocuments = true;
                    }

                    GUI.FocusControl(null);
                    m_isEditing = true;
                    m_editingContent = m_selectedDocument.RawContent;
                }
            }
            GUI.enabled = !m_selectedDocument.IsProtected;
            if (GUILayout.Button("Delete", GUILayout.Width(80)))
            {
                if (EditorUtility.DisplayDialog("Delete Document", "Are you sure you want to delete this document?", "Delete", "Cancel"))
                {
                    DeleteDocument(m_selectedDocument);
                }
            }
            GUI.enabled = true;
            if (GUILayout.Button("Help", GUILayout.Width(80)))
            {
                if (EditorUtility.DisplayDialog("Need Help?", "If you have any questions or feedback, feel free to join our Discord server for support and community discussions.", "Join Discord", "Cancel"))
                {
                    Application.OpenURL("https://discord.gg/6yHcwnZpyR");
                }
            }
            if (GUILayout.Button("Leave a Review ❤️", GUILayout.Width(130)))
            {
                Application.OpenURL("https://assetstore.unity.com/packages/templates/systems/2d-action-rpg-engine-mythril2d-249375#reviews");
            }
        }

        private void SaveDocument(IDocument document)
        {
            File.WriteAllText(document.FilePath, m_editingContent);
        }

        private void TryDeleteFile(string filePath)
        {
            if (File.Exists(filePath))
            {
                File.Delete(filePath);
            }
        }

        private void DeleteDocument(IDocument document)
        {
            string filePath = document.FilePath;

            TryDeleteFile(filePath);
            TryDeleteFile(filePath + ".meta");

            AssetDatabase.Refresh();
        }

        private void DrawNoDocumentSelectedMessage()
        {
            GUILayout.FlexibleSpace();
            GUILayout.BeginHorizontal();
            GUILayout.FlexibleSpace();
            if (m_cachedFilteredDocuments != null && m_cachedFilteredDocuments.Length == 0)
            {
                GUILayout.Label("No documents found", EditorStyles.boldLabel);
            }
            else
            {
                GUILayout.Label("Select a document from the list to view its content", EditorStyles.boldLabel);
            }
            GUILayout.FlexibleSpace();
            GUILayout.EndHorizontal();
            GUILayout.FlexibleSpace();
        }

        private string HighlightSearchString(string content, string searchString)
        {
            if (string.IsNullOrEmpty(searchString) || !m_searchInContent)
            {
                return content;
            }

            string pattern = $"(?!<[^>]*)({Regex.Escape(searchString)})(?![^<]*>)";
            string replacement = $"<mark=#FFFF0020>$1</mark>";
            return Regex.Replace(content, pattern, replacement, RegexOptions.IgnoreCase);
        }

        private string SanitizePath(string title)
        {
            return Regex.Replace(title, @"[^a-zA-Z0-9\s\-_\\/]", "");
        }

        private void CreateNewMarkdownDocument(string sanitizedPath)
        {
            if (string.IsNullOrWhiteSpace(sanitizedPath))
            {
                Debug.LogWarning("Page name cannot be empty.");
                return;
            }

            string filePath = Path.Combine(m_documentationPath, sanitizedPath) + ".md";
            string directoryPath = Path.GetDirectoryName(filePath);

            if (File.Exists(filePath))
            {
                Debug.LogWarning("A document with this title already exists.");
                return;
            }

            // Create the directory if it doesn't exist
            if (!Directory.Exists(directoryPath))
            {
                Directory.CreateDirectory(directoryPath);
            }

            string title = sanitizedPath.Split('/', '\\').Last();
            title = string.Join(" ", title.Split('-', '_').Select(word => char.ToUpper(word[0]) + word.Substring(1)));
            string content = $"# {title}\n\n";
            
            File.WriteAllText(filePath, content);
            AssetDatabase.Refresh();
        }

        private void DrawBreadcrumb()
        {
            if (m_selectedDocument != null && m_selectedDocument.Categories != null && m_selectedDocument.Categories.Length > 0)
            {
                GUILayout.BeginHorizontal();

                string[] categories = new string[] { "Root" }.Concat(m_selectedDocument.Categories).ToArray();

                for (int i = 0; i < categories.Length; i++)
                {
                    bool isFolder = i < categories.Length - 1;

                    if (GUILayout.Button(categories[i], EditorStyles.miniButton))
                    {
                        if (isFolder)
                        {
                            string folderPath = Path.Combine(new string[] { m_selectedDocument.BaseFolder }.Concat(m_selectedDocument.Categories.Take(i + 1)).ToArray());
                            EditorUtility.RevealInFinder(folderPath);
                        }
                        else
                        {
                            EditorUtility.OpenWithDefaultApp(m_selectedDocument.FilePath);
                        }
                    }

                    if (isFolder)
                    {
                        GUILayout.Label(">", EditorStyles.miniLabel);
                    }
                }

                GUILayout.FlexibleSpace();

                GUILayout.EndHorizontal();
            }
        }
    }
}

