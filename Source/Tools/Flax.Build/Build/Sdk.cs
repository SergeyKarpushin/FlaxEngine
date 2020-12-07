// Copyright (c) 2012-2019 Wojciech Figat. All rights reserved.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Flax.Build.Platforms;

namespace Flax.Build
{
    /// <summary>
    /// The base class for all SDKs.
    /// </summary>
    public abstract class Sdk
    {
        private static Dictionary<string, Sdk> _sdks;

        /// <summary>
        /// Returns true if SDK is valid.
        /// </summary>
        public bool IsValid { get; protected set; } = false;

        /// <summary>
        /// Gets the version of the SDK.
        /// </summary>
        public Version Version { get; protected set; } = new Version();

        /// <summary>
        /// Gets the path to the SDK install location.
        /// </summary>
        public string RootPath { get; protected set; } = string.Empty;

        /// <summary>
        /// Gets the platforms list supported by this SDK.
        /// </summary>
        public abstract TargetPlatform[] Platforms { get; }

        /// <summary>
        /// Prints info about all SDKs.
        /// </summary>
        public static void Print()
        {
            Get(string.Empty);
            foreach (var e in _sdks)
            {
                var sdk = e.Value;
                Log.Info(sdk.GetType().Name + ", " + sdk.Version + ", " + sdk.RootPath);
            }
            foreach (var e in WindowsPlatformBase.GetSDKs())
            {
                Log.Info("Windows SDK " + e.Key + ", " + WindowsPlatformBase.GetSDKVersion(e.Key) + ", " + e.Value);
            }
            foreach (var e in WindowsPlatformBase.GetToolsets())
            {
                Log.Info("Windows Toolset " + e.Key + ", " + e.Value);
            }
        }

        /// <summary>
        /// Gets the specified SDK.
        /// </summary>
        /// <param name="name">The SDK name.</param>
        /// <returns>The SDK instance or null if not supported.</returns>
        public static Sdk Get(string name)
        {
            if (_sdks == null)
            {
                using (new ProfileEventScope("GetSdks"))
                {
                    _sdks = new Dictionary<string, Sdk>();
                    var types = typeof(Sdk).Assembly.GetTypes().Where(x => !x.IsAbstract && x.IsSubclassOf(typeof(Sdk)));
                    foreach (var type in types)
                    {
                        object instance = null;
                        var instanceField = type.GetField("Instance", BindingFlags.Public | BindingFlags.Static);
                        if (instanceField != null)
                        {
                            instance = instanceField.GetValue(null);
                        }
                        else if (type.GetConstructor(Type.EmptyTypes) != null)
                        {
                            instance = Activator.CreateInstance(type);
                        }
                        if (instance != null)
                            _sdks.Add(type.Name, (Sdk)instance);
                    }
                }
            }

            _sdks.TryGetValue(name, out var result);
            return result;
        }

        /// <summary>
        /// Returns true if SDK is supported and is valid.
        /// </summary>
        /// <param name="name">The SDK name.</param>
        /// <returns><c>true</c> if the SDK is valid; otherwise, <c>false</c>.</returns>
        public static bool HasValid(string name)
        {
            return Get(name)?.IsValid ?? false;
        }
    }
}
