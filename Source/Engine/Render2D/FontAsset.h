// Copyright (c) 2012-2020 Wojciech Figat. All rights reserved.

#pragma once

#include "Engine/Content/BinaryAsset.h"

class Font;
class FontManager;
typedef struct FT_FaceRec_* FT_Face;

/// <summary>
/// The font hinting used when rendering characters.
/// </summary>
API_ENUM() enum class FontHinting : byte
{
    /// <summary>
    /// Use the default hinting specified in the font.
    /// </summary>
    Default,

    /// <summary>
    /// Force the use of an automatic hinting algorithm (over the font's native hinter).
    /// </summary>
    Auto,

    /// <summary>
    /// Force the use of an automatic light hinting algorithm, optimized for non-monochrome displays.
    /// </summary>
    AutoLight,

    /// <summary>
    /// Force the use of an automatic hinting algorithm optimized for monochrome displays.
    /// </summary>
    Monochrome,

    /// <summary>
    /// Do not use hinting. This generally generates 'blurrier' bitmap glyphs when the glyph are rendered in any of the anti-aliased modes.
    /// </summary>
    None,
};

/// <summary>
/// The font flags used when rendering characters.
/// </summary>
API_ENUM(Attributes="Flags") enum class FontFlags : byte
{
    /// <summary>
    /// No options.
    /// </summary>
    None = 0,

    /// <summary>
    /// Enables using anti-aliasing for font characters. Otherwise font will use monochrome data.
    /// </summary>
    AntiAliasing = 1,

    /// <summary>
    /// Enables artificial embolden effect.
    /// </summary>
    Bold = 2,

    /// <summary>
    /// Enables slant effect, emulating italic style.
    /// </summary>
    Italic = 4,
};

DECLARE_ENUM_OPERATORS(FontFlags);

/// <summary>
/// The font asset options.
/// </summary>
API_STRUCT() struct FontOptions
{
DECLARE_SCRIPTING_TYPE_MINIMAL(FontOptions);

    /// <summary>
    /// The hinting.
    /// </summary>
    API_FIELD() FontHinting Hinting;

    /// <summary>
    /// The flags.
    /// </summary>
    API_FIELD() FontFlags Flags;
};

/// <summary>
/// Font asset contains glyph collection and cached data used to render text.
/// </summary>
API_CLASS(NoSpawn) class FLAXENGINE_API FontAsset : public BinaryAsset
{
DECLARE_BINARY_ASSET_HEADER(FontAsset, 3);
    friend Font;
private:

    FT_Face _face;
    FontOptions _options;
    BytesContainer _fontFile;
    Array<Font*, InlinedAllocation<32>> _fonts;

public:

    /// <summary>
    /// Gets the font family name.
    /// </summary>
    API_PROPERTY() String GetFamilyName() const;

    /// <summary>
    /// Gets the font style name.
    /// </summary>
    API_PROPERTY() String GetStyleName() const;

    /// <summary>
    /// Gets FreeType face handle.
    /// </summary>
    FORCE_INLINE FT_Face GetFTFace() const
    {
        return _face;
    }

    /// <summary>
    /// Gets the font options.
    /// </summary>
    API_PROPERTY() const FontOptions& GetOptions() const
    {
        return _options;
    }

    /// <summary>
    /// Sets the font options.
    /// </summary>
    API_PROPERTY() void SetOptions(const FontOptions& value)
    {
        _options = value;
    }

public:

    /// <summary>
    /// Creates the font object of given characters size.
    /// </summary>
    /// <param name="size">The font characters size.</param>
    /// <returns>The created font object.</returns>
    API_FUNCTION() Font* CreateFont(int32 size);

#if USE_EDITOR

    /// <summary>
    /// Saves this asset to the file. Supported only in Editor.
    /// </summary>
    /// <param name="path">The custom asset path to use for the saving. Use empty value to save this asset to its own storage location. Can be used to duplicate asset. Must be specified when saving virtual asset.</param>
    /// <returns>True if cannot save data, otherwise false.</returns>
    API_FUNCTION() bool Save(const StringView& path = StringView::Empty);

#endif

    /// <summary>
    /// Invalidates all cached dynamic font atlases using this font. Can be used to reload font characters after changing font asset options.
    /// </summary>
    API_FUNCTION() void Invalidate();

protected:

    // [BinaryAsset]
    bool init(AssetInitData& initData) override;
    LoadResult load() override;
    void unload(bool isReloading) override;
    AssetChunksFlag getChunksToPreload() const override;
};
