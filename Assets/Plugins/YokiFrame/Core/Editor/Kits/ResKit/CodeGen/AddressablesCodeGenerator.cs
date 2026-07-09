using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEngine;

namespace YokiFrame.EditorTools
{
    public static class AddressablesCodeGenerator
    {
        private const string GeneratedDirectory = "Assets/Scripts/GameCore/Runtime/Resources/Generated";
        private const string ResourceOutputPath = GeneratedDirectory + "/FWRes.g.cs";
        private const string SceneOutputPath = GeneratedDirectory + "/FWScene.g.cs";
        private const string TextOutputPath = GeneratedDirectory + "/FWText.g.cs";

        private static readonly HashSet<string> sReservedIdentifiers = new(StringComparer.Ordinal)
        {
            "Paths"
        };

        private static readonly HashSet<string> sCSharpKeywords = new(StringComparer.Ordinal)
        {
            "abstract", "as", "base", "bool", "break", "byte", "case", "catch", "char", "checked", "class",
            "const", "continue", "decimal", "default", "delegate", "do", "double", "else", "enum", "event",
            "explicit", "extern", "false", "finally", "fixed", "float", "for", "foreach", "goto", "if",
            "implicit", "in", "int", "interface", "internal", "is", "lock", "long", "namespace", "new", "null",
            "object", "operator", "out", "override", "params", "private", "protected", "public", "readonly",
            "ref", "return", "sbyte", "sealed", "short", "sizeof", "stackalloc", "static", "string", "struct",
            "switch", "this", "throw", "true", "try", "typeof", "uint", "ulong", "unchecked", "unsafe", "ushort",
            "using", "virtual", "void", "volatile", "while"
        };

        [MenuItem("YokiFrame/Tools/Generate/资源与场景强类型入口")]
        public static void GenerateAll()
        {
            EnsureGeneratedDirectory();

            var resourceReport = GenerateResourceCode();
            var sceneCount = GenerateSceneCode();
            var textCount = GenerateTextCode();

            AssetDatabase.Refresh();

            if (resourceReport.SettingsMissing)
            {
                Debug.LogWarning(
                    $"[FWResGen] 未找到 Addressables 配置资产，已生成空的 FWRes；场景入口 {sceneCount} 项、文本入口 {textCount} 项已刷新。");
                return;
            }

            Debug.Log(
                $"[FWResGen] 资源入口 {resourceReport.ResourceCount} 项、跳过 Addressables 场景 {resourceReport.SkippedSceneCount} 项、场景入口 {sceneCount} 项、文本入口 {textCount} 项已刷新。");
        }

        private static GenerationReport GenerateResourceCode()
        {
            var settings = AddressableAssetSettingsDefaultObject.Settings;
            if (settings == null)
            {
                WriteFileIfChanged(ResourceOutputPath, BuildEmptyResourceCode());
                return new GenerationReport(settingsMissing: true, resourceCount: 0, skippedSceneCount: 0);
            }

            var resources = CollectEntries(settings, out var skippedSceneCount);
            var content = BuildResourceCode(resources);
            WriteFileIfChanged(ResourceOutputPath, content);
            return new GenerationReport(settingsMissing: false, resourceCount: resources.Count, skippedSceneCount: skippedSceneCount);
        }

        private static int GenerateSceneCode()
        {
            var scenes = CollectScenes();
            var content = BuildSceneCode(scenes);
            WriteFileIfChanged(SceneOutputPath, content);
            return scenes.Count;
        }

        private static int GenerateTextCode()
        {
            var validationReport = ValidateLocalizationFiles();
            if (!validationReport.IsValid)
            {
                foreach (var error in validationReport.Errors)
                {
                    Debug.LogError(error);
                }

                throw new InvalidOperationException("[FWTextGen] 本地化数据源校验失败，已停止生成 FWText。");
            }

            var entries = CollectTextEntries();
            var content = BuildTextCode(entries);
            WriteFileIfChanged(TextOutputPath, content);
            return entries.Count;
        }

        public static LocalizationValidationReport ValidateLocalizationFiles()
        {
            return ValidateLocalizationFiles(EnumerateLocalizationJsonFiles());
        }

        public static LocalizationValidationReport ValidateLocalizationFiles(IEnumerable<string> filePaths)
        {
            var errors = new List<string>();
            var seenTextIds = new Dictionary<int, string>();
            var seenTextKeys = new Dictionary<string, string>(StringComparer.Ordinal);

            foreach (var filePath in filePaths.OrderBy(path => path, StringComparer.OrdinalIgnoreCase))
            {
                LocalizationData data;
                try
                {
                    data = JsonUtility.FromJson<LocalizationData>(File.ReadAllText(filePath));
                }
                catch (Exception exception)
                {
                    errors.Add($"[FWTextGen] 本地化文件无法解析：{filePath}，原因：{exception.Message}");
                    continue;
                }

                if (data == null)
                {
                    errors.Add($"[FWTextGen] 本地化文件为空或格式不正确：{filePath}");
                    continue;
                }

                var languageCount = ValidateLanguages(filePath, data.languages, errors);
                ValidateTexts(filePath, data.texts, languageCount, seenTextIds, seenTextKeys, errors);
            }

            return new LocalizationValidationReport(errors);
        }

        private static List<ResourceEntryInfo> CollectEntries(AddressableAssetSettings settings, out int skippedSceneCount)
        {
            skippedSceneCount = 0;
            var entries = new List<ResourceEntryInfo>();
            var seenAddresses = new HashSet<string>(StringComparer.Ordinal);

            foreach (var group in settings.groups.Where(group => group != null).OrderBy(group => group.Name, StringComparer.OrdinalIgnoreCase))
            {
                var gatheredEntries = new List<AddressableAssetEntry>();
                group.GatherAllAssets(gatheredEntries, includeSelf: false, recurseAll: true, includeSubObjects: true);

                foreach (var entry in gatheredEntries)
                {
                    if (entry == null || string.IsNullOrWhiteSpace(entry.address))
                    {
                        continue;
                    }

                    if (!seenAddresses.Add($"{group.Name}|{entry.address}"))
                    {
                        continue;
                    }

                    if (string.IsNullOrWhiteSpace(entry.AssetPath) || AssetDatabase.IsValidFolder(entry.AssetPath))
                    {
                        continue;
                    }

                    if (entry.IsScene)
                    {
                        skippedSceneCount++;
                        continue;
                    }

                    var assetType = entry.MainAssetType;
                    if (assetType == null || assetType == typeof(DefaultAsset))
                    {
                        Debug.LogWarning($"[FWResGen] 跳过无法确定运行时类型的资源：{entry.address} ({entry.AssetPath})");
                        continue;
                    }

                    var stableKey = !string.IsNullOrWhiteSpace(entry.guid)
                        ? entry.guid
                        : $"{group.Name}|{entry.address}|{entry.AssetPath}|{assetType.FullName}";

                    var parentAddress = entry.IsSubAsset
                        ? entry.ParentEntry?.address ?? ExtractParentAddress(entry.address)
                        : entry.address;

                    var subAssetName = entry.IsSubAsset
                        ? ExtractSubAssetName(entry.address)
                        : string.Empty;

                    entries.Add(new ResourceEntryInfo
                    {
                        GroupName = string.IsNullOrWhiteSpace(group.Name) ? "Default" : group.Name,
                        Address = entry.address,
                        ParentAddress = parentAddress,
                        SubAssetName = subAssetName,
                        StableKey = stableKey,
                        TypeName = ToGlobalTypeName(assetType),
                        IsPrefab = !entry.IsSubAsset && typeof(GameObject).IsAssignableFrom(assetType),
                        IsSubAsset = entry.IsSubAsset
                    });
                }
            }

            return AssignIdentifiers(entries);
        }

        private static List<ResourceEntryInfo> AssignIdentifiers(List<ResourceEntryInfo> entries)
        {
            var grouped = entries
                .GroupBy(entry => entry.GroupName)
                .OrderBy(group => group.Key, StringComparer.OrdinalIgnoreCase)
                .ToList();

            var usedGroupIdentifiers = new HashSet<string>(StringComparer.Ordinal);
            foreach (var group in grouped)
            {
                var groupIdentifier = MakeUniqueIdentifier(
                    SanitizeIdentifier(group.Key, "Group"),
                    group.Key,
                    usedGroupIdentifiers);

                var usedEntryIdentifiers = new HashSet<string>(StringComparer.Ordinal);
                foreach (var reserved in sReservedIdentifiers)
                {
                    usedEntryIdentifiers.Add(reserved);
                }

                foreach (var entry in group.OrderBy(item => item.Address, StringComparer.OrdinalIgnoreCase))
                {
                    var baseIdentifier = SanitizeIdentifier(entry.Address, entry.IsSubAsset ? "SubAsset" : "Asset");
                    entry.GroupIdentifier = groupIdentifier;
                    entry.Identifier = MakeUniqueIdentifier(baseIdentifier, entry.StableKey, usedEntryIdentifiers);
                }
            }

            return entries
                .OrderBy(entry => entry.GroupName, StringComparer.OrdinalIgnoreCase)
                .ThenBy(entry => entry.Address, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        private static List<SceneEntryInfo> CollectScenes()
        {
            var scenes = new List<SceneEntryInfo>();
            var usedIdentifiers = new HashSet<string>(StringComparer.Ordinal);
            var enabledIndex = 0;

            foreach (var scene in EditorBuildSettings.scenes)
            {
                if (scene == null || string.IsNullOrWhiteSpace(scene.path))
                {
                    continue;
                }

                var sceneName = Path.GetFileNameWithoutExtension(scene.path);
                var buildIndex = scene.enabled ? enabledIndex++ : -1;
                var identifier = MakeUniqueIdentifier(
                    SanitizeIdentifier(sceneName, "Scene"),
                    scene.path,
                    usedIdentifiers);

                scenes.Add(new SceneEntryInfo
                {
                    Identifier = identifier,
                    SceneName = sceneName,
                    AssetPath = scene.path.Replace('\\', '/'),
                    Enabled = scene.enabled,
                    BuildIndex = buildIndex
                });
            }

            return scenes;
        }

        private static List<TextEntryInfo> CollectTextEntries()
        {
            var entries = new List<TextEntryInfo>();
            var seenIds = new HashSet<int>();

            foreach (var filePath in EnumerateLocalizationJsonFiles())
            {
                LocalizationData data;
                try
                {
                    data = JsonUtility.FromJson<LocalizationData>(File.ReadAllText(filePath));
                }
                catch (Exception exception)
                {
                    Debug.LogWarning($"[FWTextGen] 跳过无法解析的本地化文件：{filePath}，原因：{exception.Message}");
                    continue;
                }

                if (data?.texts == null)
                {
                    continue;
                }

                foreach (var text in data.texts)
                {
                    if (text == null || text.id <= 0 || !seenIds.Add(text.id))
                    {
                        continue;
                    }

                    entries.Add(new TextEntryInfo
                    {
                        Id = text.id,
                        RawName = FirstNonEmpty(text.name, text.key, text.id.ToString())
                    });
                }
            }

            return AssignTextIdentifiers(entries);
        }

        private static IEnumerable<string> EnumerateLocalizationJsonFiles()
        {
            var roots = new[]
            {
                "Assets/GameData/Localization",
                "Assets/Resources/Localization"
            };

            foreach (var root in roots)
            {
                if (!Directory.Exists(root))
                {
                    continue;
                }

                foreach (var filePath in Directory.GetFiles(root, "*.json", SearchOption.AllDirectories))
                {
                    yield return filePath;
                }
            }
        }

        private static List<TextEntryInfo> AssignTextIdentifiers(List<TextEntryInfo> entries)
        {
            var usedIdentifiers = new HashSet<string>(StringComparer.Ordinal);
            foreach (var entry in entries.OrderBy(item => item.Id))
            {
                var fallback = "Text_" + entry.Id;
                var baseIdentifier = SanitizeIdentifier(entry.RawName, fallback);
                if (char.IsDigit(baseIdentifier.TrimStart('_')[0]))
                {
                    baseIdentifier = fallback;
                }

                entry.Identifier = MakeUniqueIdentifier(baseIdentifier, entry.Id.ToString(), usedIdentifiers);
            }

            return entries.OrderBy(entry => entry.Id).ToList();
        }

        private static int ValidateLanguages(string filePath, LocalizationLanguageEntry[] languages, List<string> errors)
        {
            if (languages == null || languages.Length == 0)
            {
                errors.Add($"[FWTextGen] 本地化文件没有定义语言列表：{filePath}");
                return 0;
            }

            var seenLanguageIds = new HashSet<int>();
            for (var i = 0; i < languages.Length; i++)
            {
                var language = languages[i];
                if (language == null)
                {
                    errors.Add($"[FWTextGen] 本地化语言项为空：{filePath}，索引 {i}");
                    continue;
                }

                if (!seenLanguageIds.Add(language.id))
                {
                    errors.Add($"[FWTextGen] 本地化语言 ID 重复：{filePath}，语言 ID {language.id}");
                }
            }

            return languages.Length;
        }

        private static void ValidateTexts(
            string filePath,
            LocalizationTextEntry[] texts,
            int languageCount,
            Dictionary<int, string> seenTextIds,
            Dictionary<string, string> seenTextKeys,
            List<string> errors)
        {
            if (texts == null || texts.Length == 0)
            {
                errors.Add($"[FWTextGen] 本地化文件没有定义文本列表：{filePath}");
                return;
            }

            for (var i = 0; i < texts.Length; i++)
            {
                var text = texts[i];
                if (text == null)
                {
                    errors.Add($"[FWTextGen] 本地化文本项为空：{filePath}，索引 {i}");
                    continue;
                }

                if (text.id <= 0)
                {
                    errors.Add($"[FWTextGen] 本地化文本 ID 必须大于 0：{filePath}，索引 {i}");
                }
                else if (seenTextIds.TryGetValue(text.id, out var duplicateIdSource))
                {
                    errors.Add($"[FWTextGen] 本地化文本 ID 重复：{text.id}，来源 {duplicateIdSource} 与 {filePath}");
                }
                else
                {
                    seenTextIds.Add(text.id, filePath);
                }

                if (string.IsNullOrWhiteSpace(text.key))
                {
                    errors.Add($"[FWTextGen] 本地化文本 key 为空：{filePath}，文本 ID {text.id}");
                }
                else if (seenTextKeys.TryGetValue(text.key, out var duplicateKeySource))
                {
                    errors.Add($"[FWTextGen] 本地化文本 key 重复：{text.key}，来源 {duplicateKeySource} 与 {filePath}");
                }
                else
                {
                    seenTextKeys.Add(text.key, filePath);
                }

                if (string.IsNullOrWhiteSpace(text.name))
                {
                    errors.Add($"[FWTextGen] 本地化文本 name 为空：{filePath}，文本 ID {text.id}");
                }

                if (text.values == null)
                {
                    errors.Add($"[FWTextGen] 本地化文本 values 为空：{filePath}，文本 ID {text.id}");
                }
                else if (languageCount > 0 && text.values.Length != languageCount)
                {
                    errors.Add($"[FWTextGen] 本地化文本 values 数量与语言数量不一致：{filePath}，文本 ID {text.id}，values={text.values.Length}，languages={languageCount}");
                }
            }
        }

        private static string BuildEmptyResourceCode()
        {
            var builder = new StringBuilder();
            builder.AppendLine("// <auto-generated />");
            builder.AppendLine("// This file is generated by YokiFrame.EditorTools.AddressablesCodeGenerator.");
            builder.AppendLine();
            builder.AppendLine("namespace FantasyWord.GameCore");
            builder.AppendLine("{");
            builder.AppendLine("    public static partial class FWRes");
            builder.AppendLine("    {");
            builder.AppendLine("    }");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static string BuildResourceCode(List<ResourceEntryInfo> entries)
        {
            if (entries.Count == 0)
            {
                return BuildEmptyResourceCode();
            }

            var builder = new StringBuilder();
            builder.AppendLine("// <auto-generated />");
            builder.AppendLine("// This file is generated by YokiFrame.EditorTools.AddressablesCodeGenerator.");
            builder.AppendLine();
            builder.AppendLine("namespace FantasyWord.GameCore");
            builder.AppendLine("{");
            builder.AppendLine("    public static partial class FWRes");
            builder.AppendLine("    {");

            var groups = entries.GroupBy(entry => entry.GroupIdentifier).OrderBy(group => group.Key, StringComparer.Ordinal);
            foreach (var group in groups)
            {
                builder.AppendLine($"        public static class {group.Key}");
                builder.AppendLine("        {");
                builder.AppendLine("            public static class Paths");
                builder.AppendLine("            {");
                foreach (var entry in group.OrderBy(item => item.Identifier, StringComparer.Ordinal))
                {
                    builder.AppendLine($"                public const string {entry.Identifier} = {Quote(entry.Address)};");
                }
                builder.AppendLine("            }");
                builder.AppendLine();

                foreach (var entry in group.OrderBy(item => item.Identifier, StringComparer.Ordinal))
                {
                    if (entry.IsSubAsset)
                    {
                        builder.AppendLine(
                            $"            public static readonly global::YokiFrame.SubAssetKey<{entry.TypeName}> {entry.Identifier} =");
                        builder.AppendLine(
                            $"                new global::YokiFrame.SubAssetKey<{entry.TypeName}>(Paths.{entry.Identifier}, {Quote(entry.ParentAddress)}, {Quote(entry.SubAssetName)});");
                    }
                    else if (entry.IsPrefab)
                    {
                        builder.AppendLine(
                            $"            public static readonly global::YokiFrame.PrefabKey {entry.Identifier} =");
                        builder.AppendLine(
                            $"                new global::YokiFrame.PrefabKey(Paths.{entry.Identifier});");
                    }
                    else
                    {
                        builder.AppendLine(
                            $"            public static readonly global::YokiFrame.ResourceKey<{entry.TypeName}> {entry.Identifier} =");
                        builder.AppendLine(
                            $"                new global::YokiFrame.ResourceKey<{entry.TypeName}>(Paths.{entry.Identifier});");
                    }

                    builder.AppendLine();
                }

                builder.AppendLine("        }");
            }

            builder.AppendLine("    }");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static string BuildSceneCode(List<SceneEntryInfo> scenes)
        {
            var builder = new StringBuilder();
            builder.AppendLine("// <auto-generated />");
            builder.AppendLine("// This file is generated by YokiFrame.EditorTools.AddressablesCodeGenerator.");
            builder.AppendLine();
            builder.AppendLine("namespace FantasyWord.GameCore");
            builder.AppendLine("{");
            builder.AppendLine("    public static partial class FWScene");
            builder.AppendLine("    {");
            builder.AppendLine("        public static class Paths");
            builder.AppendLine("        {");

            foreach (var scene in scenes)
            {
                builder.AppendLine($"            public const string {scene.Identifier} = {Quote(scene.AssetPath)};");
            }

            builder.AppendLine("        }");

            if (scenes.Count > 0)
            {
                builder.AppendLine();
            }

            foreach (var scene in scenes)
            {
                builder.AppendLine($"        public static readonly global::YokiFrame.SceneKey {scene.Identifier} =");
                builder.AppendLine(
                    $"            new global::YokiFrame.SceneKey({Quote(scene.SceneName)}, {scene.BuildIndex}, {scene.Enabled.ToString().ToLowerInvariant()}, Paths.{scene.Identifier});");
                builder.AppendLine();
            }

            builder.AppendLine("    }");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static string BuildTextCode(List<TextEntryInfo> entries)
        {
            var builder = new StringBuilder();
            builder.AppendLine("// <auto-generated />");
            builder.AppendLine("// This file is generated by YokiFrame.EditorTools.AddressablesCodeGenerator.");
            builder.AppendLine();
            builder.AppendLine("namespace FantasyWord.GameCore");
            builder.AppendLine("{");
            builder.AppendLine("    public static partial class FWText");
            builder.AppendLine("    {");

            foreach (var entry in entries)
            {
                builder.AppendLine($"        public const int {entry.Identifier}Id = {entry.Id};");
                builder.AppendLine($"        public static readonly global::YokiFrame.LocalizationTextKey {entry.Identifier} =");
                builder.AppendLine($"            new global::YokiFrame.LocalizationTextKey({entry.Identifier}Id);");
                builder.AppendLine();
            }

            builder.AppendLine("    }");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static void EnsureGeneratedDirectory()
        {
            Directory.CreateDirectory(GeneratedDirectory);
        }

        private static void WriteFileIfChanged(string assetPath, string content)
        {
            var fullPath = Path.GetFullPath(assetPath);
            var existing = File.Exists(fullPath) ? File.ReadAllText(fullPath) : null;
            if (string.Equals(existing, content, StringComparison.Ordinal))
            {
                return;
            }

            File.WriteAllText(fullPath, content, new UTF8Encoding(false));
        }

        private static string SanitizeIdentifier(string rawValue, string fallback)
        {
            if (string.IsNullOrWhiteSpace(rawValue))
            {
                return fallback;
            }

            var tokens = new List<string>();
            var current = new StringBuilder();

            foreach (var character in rawValue)
            {
                if (char.IsLetterOrDigit(character))
                {
                    current.Append(character);
                }
                else if (current.Length > 0)
                {
                    tokens.Add(current.ToString());
                    current.Clear();
                }
            }

            if (current.Length > 0)
            {
                tokens.Add(current.ToString());
            }

            var builder = new StringBuilder();
            foreach (var token in tokens)
            {
                if (token.Length == 0)
                {
                    continue;
                }

                builder.Append(char.ToUpperInvariant(token[0]));
                if (token.Length > 1)
                {
                    builder.Append(token.Substring(1));
                }
            }

            var candidate = builder.Length > 0 ? builder.ToString() : fallback;
            if (!IsValidIdentifierStart(candidate[0]))
            {
                candidate = "_" + candidate;
            }

            if (sCSharpKeywords.Contains(candidate))
            {
                candidate = "_" + candidate;
            }

            return candidate;
        }

        private static string MakeUniqueIdentifier(string baseIdentifier, string stableKey, HashSet<string> usedIdentifiers)
        {
            if (usedIdentifiers.Add(baseIdentifier))
            {
                return baseIdentifier;
            }

            var suffix = "__" + Hash128.Compute(stableKey ?? string.Empty).ToString()[..6];
            var candidate = baseIdentifier + suffix;
            if (usedIdentifiers.Add(candidate))
            {
                return candidate;
            }

            var counter = 2;
            while (!usedIdentifiers.Add(candidate + "_" + counter))
            {
                counter++;
            }

            return candidate + "_" + counter;
        }

        private static string Quote(string value)
        {
            return "\"" + (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"") + "\"";
        }

        private static string FirstNonEmpty(params string[] values)
        {
            foreach (var value in values)
            {
                if (!string.IsNullOrWhiteSpace(value))
                {
                    return value;
                }
            }

            return string.Empty;
        }

        private static string ExtractParentAddress(string address)
        {
            var bracketIndex = address.IndexOf('[', StringComparison.Ordinal);
            return bracketIndex >= 0 ? address[..bracketIndex] : address;
        }

        private static string ExtractSubAssetName(string address)
        {
            var start = address.IndexOf('[', StringComparison.Ordinal);
            var end = address.LastIndexOf("]", StringComparison.Ordinal);
            if (start < 0 || end <= start)
            {
                return address;
            }

            return address.Substring(start + 1, end - start - 1);
        }

        private static bool IsValidIdentifierStart(char character)
        {
            return character == '_' || char.IsLetter(character);
        }

        private static string ToGlobalTypeName(Type type)
        {
            return "global::" + (type.FullName ?? type.Name).Replace('+', '.');
        }

        private readonly struct GenerationReport
        {
            public GenerationReport(bool settingsMissing, int resourceCount, int skippedSceneCount)
            {
                SettingsMissing = settingsMissing;
                ResourceCount = resourceCount;
                SkippedSceneCount = skippedSceneCount;
            }

            public bool SettingsMissing { get; }
            public int ResourceCount { get; }
            public int SkippedSceneCount { get; }
        }

        private sealed class ResourceEntryInfo
        {
            public string GroupName { get; set; }
            public string GroupIdentifier { get; set; }
            public string Identifier { get; set; }
            public string Address { get; set; }
            public string ParentAddress { get; set; }
            public string SubAssetName { get; set; }
            public string StableKey { get; set; }
            public string TypeName { get; set; }
            public bool IsPrefab { get; set; }
            public bool IsSubAsset { get; set; }
        }

        private sealed class SceneEntryInfo
        {
            public string Identifier { get; set; }
            public string SceneName { get; set; }
            public string AssetPath { get; set; }
            public bool Enabled { get; set; }
            public int BuildIndex { get; set; }
        }

        private sealed class TextEntryInfo
        {
            public int Id { get; set; }
            public string RawName { get; set; }
            public string Identifier { get; set; }
        }

        [Serializable]
        private sealed class LocalizationData
        {
            public LocalizationLanguageEntry[] languages;
            public LocalizationTextEntry[] texts;
        }

        [Serializable]
        private sealed class LocalizationLanguageEntry
        {
            public int id;
        }

        [Serializable]
        private sealed class LocalizationTextEntry
        {
            public int id;
            public string key;
            public string name;
            public string[] values;
        }

        public sealed class LocalizationValidationReport
        {
            internal LocalizationValidationReport(IReadOnlyList<string> errors)
            {
                Errors = errors;
            }

            public bool IsValid => Errors.Count == 0;
            public IReadOnlyList<string> Errors { get; }
        }
    }
}
