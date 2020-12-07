// Copyright (c) 2012-2020 Wojciech Figat. All rights reserved.

#if COMPILE_WITH_MODEL_TOOL

#include "ModelTool.h"
#include "Engine/Core/Log.h"
#include "Engine/Serialization/Serialization.h"

BoundingBox ImportedModelData::LOD::GetBox() const
{
    if (Meshes.IsEmpty())
        return BoundingBox::Empty;

    BoundingBox box;
    Meshes[0]->CalculateBox(box);
    for (int32 i = 1; i < Meshes.Count(); i++)
    {
        if (Meshes[i]->Positions.HasItems())
        {
            BoundingBox t;
            Meshes[i]->CalculateBox(t);
            BoundingBox::Merge(box, t, box);
        }
    }

    return box;
}

void ModelTool::Options::Serialize(SerializeStream& stream, const void* otherObj)
{
    SERIALIZE_GET_OTHER_OBJ(ModelTool::Options);

    SERIALIZE(Type);
    SERIALIZE(CalculateNormals);
    SERIALIZE(SmoothingNormalsAngle);
    SERIALIZE(FlipNormals);
    SERIALIZE(CalculateTangents);
    SERIALIZE(SmoothingTangentsAngle);
    SERIALIZE(OptimizeMeshes);
    SERIALIZE(MergeMeshes);
    SERIALIZE(ImportLODs);
    SERIALIZE(ImportVertexColors);
    SERIALIZE(ImportBlendShapes);
    SERIALIZE(LightmapUVsSource);
    SERIALIZE(Scale);
    SERIALIZE(Rotation);
    SERIALIZE(Translation);
    SERIALIZE(CenterGeometry);
    SERIALIZE(Duration);
    SERIALIZE(FramesRange);
    SERIALIZE(DefaultFrameRate);
    SERIALIZE(SamplingRate);
    SERIALIZE(SkipEmptyCurves);
    SERIALIZE(OptimizeKeyframes);
    SERIALIZE(EnableRootMotion);
    SERIALIZE(RootNodeName);
    SERIALIZE(AnimationIndex);
    SERIALIZE(GenerateLODs);
    SERIALIZE(BaseLOD);
    SERIALIZE(LODCount);
    SERIALIZE(TriangleReduction);
    SERIALIZE(ImportMaterials);
    SERIALIZE(ImportTextures);
    SERIALIZE(RestoreMaterialsOnReimport);
}

void ModelTool::Options::Deserialize(DeserializeStream& stream, ISerializeModifier* modifier)
{
    DESERIALIZE(Type);
    DESERIALIZE(CalculateNormals);
    DESERIALIZE(SmoothingNormalsAngle);
    DESERIALIZE(FlipNormals);
    DESERIALIZE(CalculateTangents);
    DESERIALIZE(SmoothingTangentsAngle);
    DESERIALIZE(OptimizeMeshes);
    DESERIALIZE(MergeMeshes);
    DESERIALIZE(ImportLODs);
    DESERIALIZE(ImportVertexColors);
    DESERIALIZE(ImportBlendShapes);
    DESERIALIZE(LightmapUVsSource);
    DESERIALIZE(Scale);
    DESERIALIZE(Rotation);
    DESERIALIZE(Translation);
    DESERIALIZE(CenterGeometry);
    DESERIALIZE(Duration);
    DESERIALIZE(FramesRange);
    DESERIALIZE(DefaultFrameRate);
    DESERIALIZE(SamplingRate);
    DESERIALIZE(SkipEmptyCurves);
    DESERIALIZE(OptimizeKeyframes);
    DESERIALIZE(EnableRootMotion);
    DESERIALIZE(RootNodeName);
    DESERIALIZE(AnimationIndex);
    DESERIALIZE(GenerateLODs);
    DESERIALIZE(BaseLOD);
    DESERIALIZE(LODCount);
    DESERIALIZE(TriangleReduction);
    DESERIALIZE(ImportMaterials);
    DESERIALIZE(ImportTextures);
    DESERIALIZE(RestoreMaterialsOnReimport);
}

#endif
