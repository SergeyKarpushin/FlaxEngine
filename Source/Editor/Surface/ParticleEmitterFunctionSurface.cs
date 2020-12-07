// Copyright (c) 2012-2020 Wojciech Figat. All rights reserved.

using System;
using FlaxEditor.Surface.Archetypes;
using FlaxEngine;

namespace FlaxEditor.Surface
{
    /// <summary>
    /// The Visject Surface implementation for the particle emitter functions editor.
    /// </summary>
    /// <seealso cref="ParticleEmitterSurface" />
    /// <seealso cref="Function.IFunctionSurface" />
    [HideInEditor]
    public class ParticleEmitterFunctionSurface : ParticleEmitterSurface, Function.IFunctionSurface
    {
        private static readonly Type[] ParticleEmitterFunctionTypes =
        {
            typeof(bool),
            typeof(int),
            typeof(float),
            typeof(Vector2),
            typeof(Vector3),
            typeof(Vector4),
            typeof(FlaxEngine.Object),
        };

        /// <inheritdoc />
        public ParticleEmitterFunctionSurface(IVisjectSurfaceOwner owner, Action onSave, FlaxEditor.Undo undo)
        : base(owner, onSave, undo)
        {
        }

        /// <inheritdoc />
        public override bool CanUseNodeType(NodeArchetype nodeArchetype)
        {
            if (nodeArchetype.Title == "Function Input" ||
                nodeArchetype.Title == "Function Output")
                return true;

            return base.CanUseNodeType(nodeArchetype);
        }

        /// <inheritdoc />
        public Type[] FunctionTypes => ParticleEmitterFunctionTypes;
    }
}
