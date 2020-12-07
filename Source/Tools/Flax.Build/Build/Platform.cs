// Copyright (c) 2012-2020 Wojciech Figat. All rights reserved.

using System;
using System.Collections.Generic;
using System.Linq;
using Flax.Build.NativeCpp;

namespace Flax.Build
{
    /// <summary>
    /// The base class for all platform toolsets.
    /// </summary>
    public abstract class Platform
    {
        private static Platform _buildPlatform;
        private static Platform[] _platforms;
        private Dictionary<TargetArchitecture, Toolchain> _toolchains;

        /// <summary>
        /// Gets the current target platform that build tool runs on.
        /// </summary>
        public static TargetPlatform BuildTargetPlatform
        {
            get
            {
                if (_buildPlatform == null)
                {
                    OperatingSystem os = Environment.OSVersion;
                    PlatformID platformId = os.Platform;
                    switch (platformId)
                    {
                    case PlatformID.Win32NT:
                    case PlatformID.Win32S:
                    case PlatformID.Win32Windows:
                    case PlatformID.WinCE: return TargetPlatform.Windows;
                    case PlatformID.Unix: return TargetPlatform.Linux;
                    default: throw new NotImplementedException(string.Format("Unsupported build platform {0}.", platformId));
                    }
                }
                return _buildPlatform.Target;
            }
        }

        /// <summary>
        /// Gets the current platform that build tool runs on.
        /// </summary>
        public static Platform BuildPlatform
        {
            get
            {
                if (_buildPlatform == null)
                {
                    _buildPlatform = GetPlatform(BuildTargetPlatform);
                }
                return _buildPlatform;
            }
        }

        /// <summary>
        /// Gets the platform target type.
        /// </summary>
        public abstract TargetPlatform Target { get; }

        /// <summary>
        /// Gets a value indicating whether required external SDKs are installed for this platform.
        /// </summary>
        public abstract bool HasRequiredSDKsInstalled { get; }

        /// <summary>
        /// Gets a value indicating whether precompiled headers are supported on that platform.
        /// </summary>
        public abstract bool HasPrecompiledHeaderSupport { get; }

        /// <summary>
        /// Gets a value indicating whether that platform supports shared libraries (dynamic link libraries).
        /// </summary>
        public abstract bool HasSharedLibrarySupport { get; }

        /// <summary>
        /// Gets a value indicating whether that platform supports building target into modular libraries (otherwise will force monolithic linking).
        /// </summary>
        public virtual bool HasModularBuildSupport => true;

        /// <summary>
        /// Gets the executable file extension (including leading dot).
        /// </summary>
        public abstract string ExecutableFileExtension { get; }

        /// <summary>
        /// Gets the shared library file extension (including leading dot).
        /// </summary>
        public abstract string SharedLibraryFileExtension { get; }

        /// <summary>
        /// Gets the static library file extension (including leading dot).
        /// </summary>
        public abstract string StaticLibraryFileExtension { get; }

        /// <summary>
        /// Gets the program database file extension (including leading dot).
        /// </summary>
        public abstract string ProgramDatabaseFileExtension { get; }

        /// <summary>
        /// Gets the executable and library files prefix.
        /// </summary>
        public virtual string BinaryFilePrefix => string.Empty;

        /// <summary>
        /// Gets the default project format used by the given platform.
        /// </summary>
        public abstract Projects.ProjectFormat DefaultProjectFormat { get; }

        /// <summary>
        /// Creates the toolchain for a given architecture.
        /// </summary>
        /// <param name="architecture">The architecture.</param>
        /// <returns>The toolchain.</returns>
        protected abstract Toolchain CreateToolchain(TargetArchitecture architecture);

        /// <summary>
        /// Determines whether this platform can build for the specified platform.
        /// </summary>
        /// <param name="platform">The platform.</param>
        /// <returns><c>true</c> if this platform can build the specified platform; otherwise, <c>false</c>.</returns>
        public virtual bool CanBuildPlatform(TargetPlatform platform)
        {
            return false;
        }

        /// <summary>
        /// Gets the path to the output file for the linker.
        /// </summary>
        /// <param name="name">The original library name.</param>
        /// <param name="output">The output file type.</param>
        /// <returns>The file name (including prefix, name and extension).</returns>
        public string GetLinkOutputFileName(string name, LinkerOutput output)
        {
            switch (output)
            {
            case LinkerOutput.Executable: return BinaryFilePrefix + name + ExecutableFileExtension;
            case LinkerOutput.SharedLibrary: return BinaryFilePrefix + name + SharedLibraryFileExtension;
            case LinkerOutput.StaticLibrary:
            case LinkerOutput.ImportLibrary: return BinaryFilePrefix + name + StaticLibraryFileExtension;
            default: throw new ArgumentOutOfRangeException(nameof(output), output, null);
            }
        }

        /// <summary>
        /// Creates the build toolchain for a given platform and architecture.
        /// </summary>
        /// <param name="targetPlatform">The target platform.</param>
        /// <param name="nullIfMissing">True if return null platform if it's missing, otherwise will invoke an exception.</param>
        /// <returns>The toolchain.</returns>
        public static Platform GetPlatform(TargetPlatform targetPlatform, bool nullIfMissing = false)
        {
            if (_platforms == null)
            {
                using (new ProfileEventScope("GetPlatforms"))
                    _platforms = typeof(Platform).Assembly.GetTypes().Where(x => !x.IsAbstract && x.IsSubclassOf(typeof(Platform))).Select(Activator.CreateInstance).Cast<Platform>().ToArray();
            }

            foreach (var platform in _platforms)
            {
                if (platform.Target == targetPlatform)
                {
                    return platform;
                }
            }

            if (nullIfMissing)
                return null;
            throw new Exception(string.Format("Platform {0} is not supported.", targetPlatform));
        }

        /// <summary>
        /// Creates the build toolchain for a given architecture.
        /// </summary>
        /// <param name="targetArchitecture">The target architecture.</param>
        /// <returns>The toolchain.</returns>
        public Toolchain GetToolchain(TargetArchitecture targetArchitecture)
        {
            if (!HasRequiredSDKsInstalled)
                throw new Exception(string.Format("Platform {0} has no required SDK installed and cannot be used.", Target));

            if (_toolchains == null)
                _toolchains = new Dictionary<TargetArchitecture, Toolchain>();

            var key = targetArchitecture;

            Toolchain toolchain;
            if (_toolchains.TryGetValue(key, out toolchain))
            {
                return toolchain;
            }

            toolchain = CreateToolchain(targetArchitecture);
            _toolchains.Add(key, toolchain);

            return toolchain;
        }

        /// <summary>
        /// Creates the project files generator for the specified project format.
        /// </summary>
        /// <param name="targetPlatform">The target platform.</param>
        /// <param name="targetArchitecture">The target architecture.</param>
        /// <returns>True if the given platform is supported, otherwise false.</returns>
        public static bool IsPlatformSupported(TargetPlatform targetPlatform, TargetArchitecture targetArchitecture)
        {
            if (targetArchitecture == TargetArchitecture.AnyCPU)
                return true;

            switch (targetPlatform)
            {
            case TargetPlatform.Windows: return targetArchitecture == TargetArchitecture.x64 || targetArchitecture == TargetArchitecture.x86;
            case TargetPlatform.XboxScarlett: return targetArchitecture == TargetArchitecture.x64;
            case TargetPlatform.XboxOne: return targetArchitecture == TargetArchitecture.x64;
            case TargetPlatform.UWP: return targetArchitecture == TargetArchitecture.x64;
            case TargetPlatform.Linux: return targetArchitecture == TargetArchitecture.x64;
            case TargetPlatform.PS4: return targetArchitecture == TargetArchitecture.x64;
            case TargetPlatform.Android: return targetArchitecture == TargetArchitecture.ARM64;
            default: return false;
            }
        }
    }
}
