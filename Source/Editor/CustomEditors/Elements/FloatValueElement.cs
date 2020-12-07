// Copyright (c) 2012-2020 Wojciech Figat. All rights reserved.

using System.Linq;
using System.Reflection;
using FlaxEditor.GUI.Input;
using FlaxEngine;
using FlaxEngine.GUI;

namespace FlaxEditor.CustomEditors.Elements
{
    /// <summary>
    /// The floating point value element.
    /// </summary>
    /// <seealso cref="FlaxEditor.CustomEditors.LayoutElement" />
    public class FloatValueElement : LayoutElement, IFloatValueEditor
    {
        /// <summary>
        /// The float value box.
        /// </summary>
        public readonly FloatValueBox FloatValue;

        /// <summary>
        /// Initializes a new instance of the <see cref="FloatValueElement"/> class.
        /// </summary>
        public FloatValueElement()
        {
            FloatValue = new FloatValueBox(0);
        }

        /// <summary>
        /// Sets the editor limits from member <see cref="LimitAttribute"/>.
        /// </summary>
        /// <param name="member">The member.</param>
        public void SetLimits(MemberInfo member)
        {
            // Try get limit attribute for value min/max range setting and slider speed
            if (member != null)
            {
                var attributes = member.GetCustomAttributes(true);
                var limit = attributes.FirstOrDefault(x => x is LimitAttribute);
                if (limit != null)
                {
                    FloatValue.SetLimits((LimitAttribute)limit);
                }
            }
        }

        /// <summary>
        /// Sets the editor limits from member <see cref="LimitAttribute"/>.
        /// </summary>
        /// <param name="limit">The limit.</param>
        public void SetLimits(LimitAttribute limit)
        {
            if (limit != null)
            {
                FloatValue.SetLimits(limit);
            }
        }

        /// <summary>
        /// Sets the editor limits from the other <see cref="FloatValueElement"/>.
        /// </summary>
        /// <param name="other">The other.</param>
        public void SetLimits(FloatValueElement other)
        {
            if (other != null)
            {
                FloatValue.SetLimits(other.FloatValue);
            }
        }

        /// <inheritdoc />
        public override Control Control => FloatValue;

        /// <inheritdoc />
        public float Value
        {
            get => FloatValue.Value;
            set => FloatValue.Value = value;
        }

        /// <inheritdoc />
        public bool IsSliding => FloatValue.IsSliding;
    }
}
