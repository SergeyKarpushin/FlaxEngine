// Copyright (c) 2012-2020 Wojciech Figat. All rights reserved.

using Flax.Build;

/// <summary>
/// https://github.com/recastnavigation/recastnavigation
/// </summary>
public class recastnavigation : ThirdPartyModule
{
    /// <inheritdoc />
    public override void Init()
    {
        base.Init();

        LicenseType = LicenseTypes.zLib;
    }
}
