using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace FantasyWord.GameCore
{
    public class MarkdownDocument : IDocument
    {
        public string Title => m_title;
        public string Content => m_htmlContent;
        public string FilePath => m_filePath;
        public string RelativeFilePath => m_relativeFilePath;
        public string BaseFolder => m_baseFolder;
        public string LastModified => m_lastModified;
        public bool IsProtected => m_protected;
        public string[] Categories => m_categories != null ? (string[])m_categories.Clone() : System.Array.Empty<string>();
        public string RawContent => m_markdownContent;

        private string m_title;
        private string m_markdownContent;
        private string m_htmlContent;
        private string m_filePath;
        private string m_relativeFilePath;
        private string m_lastModified;
        private string[] m_categories;
        private bool m_protected = false;
        private string m_baseFolder;

        public MarkdownDocument(string baseFolder, string filePath)
        {
            m_baseFolder = Path.GetFullPath(baseFolder);
            SetPath(filePath);
            Reload();
        }

        private void SetPath(string filePath)
        {
            m_filePath = Path.GetFullPath(filePath);
            ComputeLastModified();
            ComputeRelativePath();
            SetCategoriesAndTitle();
        }

        private void ComputeLastModified()
        {
            m_lastModified = File.GetLastWriteTime(m_filePath).ToString("yyyy-MM-dd HH:mm:ss");
        }

        private void ComputeRelativePath()
        {
            m_relativeFilePath = Path.GetRelativePath(m_baseFolder, m_filePath);
        }

        private void SetCategoriesAndTitle()
        {
            m_categories = m_relativeFilePath.Split(Path.DirectorySeparatorChar);
            m_title = m_categories.Last();
            m_protected = m_categories.FirstOrDefault() == "Mythril2D";
        }

        private void GenerateHTMLContent()
        {
            string content = m_markdownContent.Trim();

            // Code blocks
            content = Regex.Replace(content, @"```(.*?)\n([\s\S]*?)```", match => $"<code>{System.Net.WebUtility.HtmlEncode(match.Groups[2].Value).TrimEnd()}</code>");

            // Inline code
            content = Regex.Replace(content, @"`([^`]+)`", match => $"<code>{System.Net.WebUtility.HtmlEncode(match.Groups[1].Value)}</code>");

            // Headers
            content = Regex.Replace(content, @"^# (.*?)$", "<color=#FFC300><size=18><b>$1</b></size></color>", RegexOptions.Multiline);
            content = Regex.Replace(content, @"^## (.*?)$", "<size=16><b>$1</b></size>", RegexOptions.Multiline);
            content = Regex.Replace(content, @"^### (.*?)$", "<size=15><b>$1</b></size>", RegexOptions.Multiline);
            content = Regex.Replace(content, @"^#### (.*?)$", "<size=14><b>$1</b></size>", RegexOptions.Multiline);
            content = Regex.Replace(content, @"^##### (.*?)$", "<size=14><b>$1</b></size>", RegexOptions.Multiline);
            content = Regex.Replace(content, @"^###### (.*?)$", "<size=14><b>$1</b></size>", RegexOptions.Multiline);

            // Links: Convert [text](url) to <a href="url">text</a>
            content = Regex.Replace(content, @"\[(.*?)\]\((.*?)\)", "<a href=\"$2\">$1</a>");

            // Block quotes
            content = Regex.Replace(content, @"^> (.*?)$", "<color=#8E8E8E><i>$1</i></color>", RegexOptions.Multiline);

            // Bold: Convert **text** or __text__ to <b>text</b>
            content = Regex.Replace(content, @"(?<!<code>)\*\*(.*?)\*\*(?!<\/code>)", "<b>$1</b>");
            content = Regex.Replace(content, @"(?<!<code>*)__(.*?)__(?!<\/code>)", "<b>$1</b>");

            // Italic: Convert *text* or _text_ to <i>text</i>
            content = Regex.Replace(content, @"(?<!<code>[^<]*)\*(.*?)\*(?![^<]*<\/code>)", "<i>$1</i>");
            content = Regex.Replace(content, @"(?<!<code>[^<]*)_(.*?)_(?![^<]*<\/code>)", "<i>$1</i>");

            // Strikethrough: Convert ~~text~~ to <s>text</s>
            content = Regex.Replace(content, @"(?<!<code>)~~(.*?)~~(?!<\/code>)", "<s>$1</s>");

            // Apply code style
            content = Regex.Replace(content, @"<code>(.*?)</code>", "<color=#add8e6ff><b>$1</b></color>");

            m_htmlContent = content;
        }

        public void MovePath(string newPath) => SetPath(newPath);

        public void Reload()
        {
            m_markdownContent = File.ReadAllText(m_filePath);

            // Content of the "header 1" is used as the title
            m_title = Regex.Match(m_markdownContent, @"^# (.*?)$", RegexOptions.Multiline).Groups[1].Value.Trim();

            GenerateHTMLContent();
            ComputeLastModified();
        }
    }
}

