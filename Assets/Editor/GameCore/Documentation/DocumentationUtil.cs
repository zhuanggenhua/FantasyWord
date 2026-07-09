using System;
using System.IO;
using System.Linq;
using UnityEngine;

namespace FantasyWord.GameCore
{
    public static class DocumentationUtil
    {
        public const string kDocumentationRootFile = "M2DOC_ROOT_DO_NOT_DELETE";

        private static string FindM2DocFileLocation(string startDirectory)
        {
            try
            {
                return Directory.EnumerateFiles(startDirectory, kDocumentationRootFile, SearchOption.AllDirectories).FirstOrDefault();
            }
            catch (Exception ex)
            {
                Debug.LogError("Error finding .m2doc file: " + ex.Message);
                return null;
            }
        }

        public static string GetDocumentationFolderPath()
        {
            string m2docLocation = FindM2DocFileLocation(Application.dataPath);

            if (m2docLocation == null)
            {
                Debug.LogError($"Could not find the '{kDocumentationRootFile}' file in the project directory or any of its subdirectories. Did you delete it? Documentation couldn't be loaded.");
                return null;
            }

            return Path.GetDirectoryName(m2docLocation);
        }
    }
}

