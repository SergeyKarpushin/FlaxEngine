// Copyright (c) 2012-2024 Wojciech Figat. All rights reserved.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Runtime.CompilerServices;
using FlaxEngine;

namespace FlaxEditor.Modules
{
    /// <summary>
    /// Caching local editor data manager.
    /// </summary>
    /// <seealso cref="FlaxEditor.Modules.EditorModule" />
    public sealed class EditorCacheModule : EditorModule
    {
        private readonly string _cachePath;
        private DateTime _lastSaveTime;
        private bool _isDirty = false;

        private readonly Dictionary<string, string> _customData = new Dictionary<string, string>();

        /// <inheritdoc />
        internal EditorCacheModule(Editor editor)
        : base(editor)
        {
            // After editor options but before the others
            InitOrder = -890;

            _cachePath = StringUtils.CombinePaths(Editor.LocalCachePath, "EditorCache.dat");
        }

        /// <summary>
        /// Determines whether project cache contains custom data of the specified key.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <returns><c>true</c> if has custom data of the specified key; otherwise, <c>false</c>.</returns>
        public bool HasCustomData(string key)
        {
            return _customData.ContainsKey(key);
        }

        /// <summary>
        /// Gets the custom data by the key.
        /// </summary>
        /// <remarks>
        /// Use <see cref="HasCustomData"/> to check if a key is valid.
        /// </remarks>
        /// <param name="key">The key.</param>
        /// <returns>The custom data.</returns>
        public string GetCustomData(string key)
        {
            return _customData[key];
        }

        /// <summary>
        /// Tries to get the custom data by the key.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="value">When this method returns, contains the value associated with the specified key, if the key is found; otherwise, the default value for the type of the <paramref name="value" /> parameter. This parameter is passed uninitialized.</param>
        /// <returns>The custom data.</returns>
        public bool TryGetCustomData(string key, out string value)
        {
            return _customData.TryGetValue(key, out value);
        }

        /// <summary>
        /// Tries to get the custom data by the key.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="value">When this method returns, contains the value associated with the specified key, if the key is found; otherwise, the default value for the type of the <paramref name="value" /> parameter. This parameter is passed uninitialized.</param>
        /// <returns>The custom data.</returns>
        public bool TryGetCustomData(string key, out bool value)
        {
            value = false;
            return _customData.TryGetValue(key, out var valueStr) && bool.TryParse(valueStr, out value);
        }

        /// <summary>
        /// Tries to get the custom data by the key.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="value">When this method returns, contains the value associated with the specified key, if the key is found; otherwise, the default value for the type of the <paramref name="value" /> parameter. This parameter is passed uninitialized.</param>
        /// <returns>The custom data.</returns>
        public bool TryGetCustomData(string key, out float value)
        {
            value = 0.0f;
            return _customData.TryGetValue(key, out var valueStr) && float.TryParse(valueStr, out value);
        }

        /// <summary>
        /// Sets the custom data.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="value">The value.</param>
        public void SetCustomData(string key, string value)
        {
            _customData[key] = value;
            _isDirty = true;
        }

        /// <summary>
        /// Sets the custom data.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="value">The value.</param>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public void SetCustomData(string key, bool value)
        {
            SetCustomData(key, value.ToString());
        }

        /// <summary>
        /// Sets the custom data.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="value">The value.</param>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public void SetCustomData(string key, float value)
        {
            SetCustomData(key, value.ToString(CultureInfo.InvariantCulture));
        }

        /// <summary>
        /// Removes the custom data.
        /// </summary>
        /// <param name="key">The key.</param>
        public void RemoveCustomData(string key)
        {
            bool removed = _customData.Remove(key);
            _isDirty |= removed;
        }

        private void LoadGuarded()
        {
            using (var stream = new FileStream(_cachePath, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var reader = new BinaryReader(stream))
            {
                var version = reader.ReadInt32();

                switch (version)
                {
                    case 1:
                        {
                            _customData.Clear();

                            break;
                        }
                    case 2:
                        {
                            _customData.Clear();
                            int customDataCount = reader.ReadInt32();
                            for (int i = 0; i < customDataCount; i++)
                            {
                                var key = reader.ReadString();
                                var value = reader.ReadString();
                                _customData.Add(key, value);
                            }

                            break;
                        }
                    case 3:
                        {
                            _customData.Clear();
                            int customDataCount = reader.ReadInt32();
                            for (int i = 0; i < customDataCount; i++)
                            {
                                var key = reader.ReadString();
                                var value = reader.ReadString();
                                _customData.Add(key, value);
                            }

                            break;
                        }
                    default:
                        Editor.LogWarning("Unknown editor cache version.");
                        return;
                }
            }
        }

        private void Load()
        {
            if (!File.Exists(_cachePath))
            {
                Editor.LogWarning("Missing editor cache file.");
                return;
            }

            _lastSaveTime = DateTime.UtcNow;

            try
            {
                LoadGuarded();
            }
            catch (Exception ex)
            {
                Editor.LogWarning(ex);
                Editor.LogError("Failed to load editor cache. " + ex.Message);
            }
        }

        private void SaveGuarded()
        {
            using (var stream = new FileStream(_cachePath, FileMode.Create, FileAccess.Write, FileShare.Read))
            using (var writer = new BinaryWriter(stream))
            {
                writer.Write(3);

                writer.Write(_customData.Count);
                foreach (var e in _customData)
                {
                    writer.Write(e.Key);
                    writer.Write(e.Value);
                }
            }
        }

        private void Save()
        {
            if (!_isDirty)
                return;

            _lastSaveTime = DateTime.UtcNow;

            try
            {
                SaveGuarded();
                _isDirty = false;
            }
            catch (Exception ex)
            {
                Editor.LogWarning(ex);
                Editor.LogError("Failed to save editor cache. " + ex.Message);
            }
        }

        /// <inheritdoc />
        public override void OnInit()
        {
            Load();
        }

        /// <inheritdoc />
        public override void OnExit()
        {
            Save();
        }
    }
}
