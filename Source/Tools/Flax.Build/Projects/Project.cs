// Copyright (c) 2012-2020 Wojciech Figat. All rights reserved.

using System.Collections.Generic;
using Flax.Build.NativeCpp;

namespace Flax.Build.Projects
{
    /// <summary>
    /// The project file data for generator.
    /// </summary>
    public class Project
    {
        private string _path;

        /// <summary>
        /// The project generator that created this project.
        /// </summary>
        public ProjectGenerator Generator;

        /// <summary>
        /// The project name.
        /// </summary>
        public string Name;

        /// <summary>
        /// The project type. Overrides the type of the target.
        /// </summary>
        public TargetType? Type;

        /// <summary>
        /// The project output type. Overrides the output type of the target.
        /// </summary>
        public TargetOutputType? OutputType;

        /// <summary>
        /// The project file path.
        /// </summary>
        public virtual string Path
        {
            get => _path;
            set => _path = value;
        }

        /// <summary>
        /// The workspace root directory path.
        /// </summary>
        public string WorkspaceRootPath;

        /// <summary>
        /// The project source files directories.
        /// </summary>
        public List<string> SourceDirectories;

        /// <summary>
        /// The project source files.
        /// </summary>
        public List<string> SourceFiles;

        /// <summary>
        /// The project source files that are generated by the build system. Can be hidden in project tree but are relevant for the project.
        /// </summary>
        public List<string> GeneratedSourceFiles;

        /// <summary>
        /// The targets used in the project. Non-empty and non-null collection of one or more valid projects.
        /// </summary>
        public Target[] Targets;

        /// <summary>
        /// The source code build defines.
        /// </summary>
        public HashSet<string> Defines = new HashSet<string>();

        /// <summary>
        /// The additional included source files path.
        /// </summary>
        public string[] SearchPaths;

        /// <summary>
        /// The project dependencies.
        /// </summary>
        public HashSet<Project> Dependencies = new HashSet<Project>();

        /// <summary>
        /// The custom name of the project group. Useful to group the project in the solution eg. by category or the project name.
        /// </summary>
        public string GroupName = string.Empty;

        /// <summary>
        /// Gets the source folder path (or workspace root if no source directory is assigned).
        /// </summary>
        public string SourceFolderPath => SourceDirectories != null && SourceDirectories.Count > 0 ? SourceDirectories[0] : WorkspaceRootPath;

        /// <summary>
        /// The configuration data.
        /// </summary>
        public struct ConfigurationData
        {
            /// <summary>
            /// The name of the configuration (eg. Editor.Windows.Debug|x64).
            /// </summary>
            public string Name;

            /// <summary>
            /// The configuration text (eg.Editor.Windows.Debug).
            /// </summary>
            public string Text;

            /// <summary>
            /// The platform.
            /// </summary>
            public TargetPlatform Platform;

            /// <summary>
            /// The platform name.
            /// </summary>
            public string PlatformName;

            /// <summary>
            /// The architecture.
            /// </summary>
            public TargetArchitecture Architecture;

            /// <summary>
            /// The architecture name.
            /// </summary>
            public string ArchitectureName;

            /// <summary>
            /// The configuration.
            /// </summary>
            public TargetConfiguration Configuration;

            /// <summary>
            /// The configuration name.
            /// </summary>
            public string ConfigurationName;

            /// <summary>
            /// The target.
            /// </summary>
            public Target Target;

            /// <summary>
            /// The target build options merged from the modules (fake project build environment).
            /// </summary>
            public BuildOptions TargetBuildOptions;

            /// <summary>
            /// The list of modules for build (fake project build environment).
            /// </summary>
            public Dictionary<Module, BuildOptions> Modules;

            /// <summary>
            /// Initializes a new instance of the <see cref="ConfigurationData"/> struct.
            /// </summary>
            /// <param name="target">The target.</param>
            /// <param name="project">The project.</param>
            /// <param name="platform">The platform.</param>
            /// <param name="architecture">The architecture.</param>
            /// <param name="configuration">The configuration.</param>
            public ConfigurationData(Target target, Project project, Platform platform, TargetArchitecture architecture, TargetConfiguration configuration)
            {
                var targetName = target.ConfigurationName ?? target.Name;
                var platformName = platform.Target.ToString();
                var configurationName = configuration.ToString();
                var configurationText = targetName + '.' + platformName + '.' + configurationName;
                var architectureName = architecture.ToString();
                if (platform is IProjectCustomizer customizer)
                    customizer.GetProjectArchitectureName(project, platform, architecture, ref architectureName);
                Name = configurationText + '|' + architectureName;
                Text = configurationText;
                Platform = platform.Target;
                PlatformName = platformName;
                Architecture = architecture;
                ArchitectureName = architectureName;
                Configuration = configuration;
                ConfigurationName = configurationName;
                Target = target;
                TargetBuildOptions = null;
                Modules = new Dictionary<Module, BuildOptions>();
            }

            /// <inheritdoc />
            public override string ToString()
            {
                return Name;
            }
        }

        /// <summary>
        /// The project configurations.
        /// </summary>
        public List<ConfigurationData> Configurations = new List<ConfigurationData>();

        /// <summary>
        /// The native C++ project options.
        /// </summary>
        public struct NativeCppProject
        {
        }

        /// <summary>
        /// The native C++ project options.
        /// </summary>
        public NativeCppProject NativeCpp;

        /// <summary>
        /// The native C# project options.
        /// </summary>
        public struct CSharpProject
        {
            /// <summary>
            /// If set to true, the generated project will use Flax.VS extension for scripts debugging, otherwise it will be generic C# project.
            /// </summary>
            public bool UseFlaxVS;

            /// <summary>
            /// The system libraries references.
            /// </summary>
            public HashSet<string> SystemReferences;

            /// <summary>
            /// The .Net libraries references (dll or exe files paths).
            /// </summary>
            public HashSet<string> FileReferences;

            /// <summary>
            /// The output folder path (optional).
            /// </summary>
            public string OutputPath;

            /// <summary>
            /// The intermediate output folder path (optional).
            /// </summary>
            public string IntermediateOutputPath;
        }

        /// <summary>
        /// The native C# project options.
        /// </summary>
        public CSharpProject CSharp = new CSharpProject
        {
            SystemReferences = new HashSet<string>(),
            FileReferences = new HashSet<string>(),
        };

        /// <summary>
        /// Generates the project.
        /// </summary>
        public virtual void Generate()
        {
            Generator.GenerateProject(this);
        }

        /// <inheritdoc />
        public override string ToString()
        {
            return $"{Name} ({Path})";
        }
    }
}
