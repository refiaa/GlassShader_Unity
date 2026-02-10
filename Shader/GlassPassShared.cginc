#ifndef GLASS_PASS_SHARED_INCLUDED
#define GLASS_PASS_SHARED_INCLUDED

inline float2 ClampSceneUV(float2 uv)
{
    float padding = saturate(_UVClamp);
    return clamp(uv, padding, 1.0 - padding);
}

inline float2 GetScreenTexelSize()
{
    return 1.0 / max(_ScreenParams.xy, float2(1.0, 1.0));
}

inline float3 SampleStereoSceneColor(float2 uv)
{
    return GlassIsStereoEyeRight() ? tex2D(_UdonGlassSceneColorR, uv).rgb : tex2D(_UdonGlassSceneColorL, uv).rgb;
}

inline float3 SampleGrabColor(float4 grabPos)
{
    float invW = 1.0 / max(grabPos.w, 1e-5);
    float2 uv = ClampSceneUV(grabPos.xy * invW);
    return tex2D(_GrabTexture, uv).rgb;
}

inline float3 SampleSceneColor(float2 uv, float4 grabPos)
{
    if (_UseSceneColorTexture > 0.5)
    {
        if (_UseUdonStereoTextures > 0.5)
        {
            return SampleStereoSceneColor(uv);
        }
        return tex2D(_SceneColorTex, uv).rgb;
    }

    if (_UseGrabPassFallback > 0.5)
    {
        if (grabPos.w <= 1e-5)
        {
            return tex2D(_GrabTexture, ClampSceneUV(uv)).rgb;
        }
        return SampleGrabColor(grabPos);
    }

    return 0.0.xxx;
}

inline float3 ComputeNormalWS(Varyings input, float2 normalUV)
{
    float3 normalTS = GlassUnpackNormalTS(_NormalMap, normalUV, _NormalScale);
    float tangentLen2 = dot(input.tangentWS, input.tangentWS);
    float3 normalWS = normalize(input.normalWS);

    if (tangentLen2 > 1e-5)
    {
        normalWS = GlassTransformTangentToWorld(normalTS, input.tangentWS, input.bitangentWS, input.normalWS);
    }

    return normalWS;
}

inline float3 SampleChromaticSceneColor(float2 refractedUV, float4 refractedGrabPos, float2 refractionOffset, float chromaScale)
{
    float2 pixelSize = GetScreenTexelSize();
    float2 chromaDir = normalize(refractionOffset + float2(1e-6, 0.0));
    float chromaFade = saturate(chromaScale / max(_RefractionStrength, 1e-5));
    float2 chromaOffset = chromaDir * (_ChromaticAberration * pixelSize * chromaFade);

    float2 uvR = ClampSceneUV(refractedUV + chromaOffset);
    float2 uvB = ClampSceneUV(refractedUV - chromaOffset);
    float4 grabPosR = refractedGrabPos;
    float4 grabPosB = refractedGrabPos;
    grabPosR.xy += chromaOffset * grabPosR.w;
    grabPosB.xy -= chromaOffset * grabPosB.w;

    float3 sceneColor;
    sceneColor.r = SampleSceneColor(uvR, grabPosR).r;
    sceneColor.g = SampleSceneColor(refractedUV, refractedGrabPos).g;
    sceneColor.b = SampleSceneColor(uvB, grabPosB).b;
    return sceneColor;
}

inline float3 SampleSceneColorOffset(float2 baseUV, float4 baseGrabPos, float2 uvOffset)
{
    float2 uv = ClampSceneUV(baseUV + uvOffset);
    float4 grabPos = baseGrabPos;
    grabPos.xy += uvOffset * baseGrabPos.w;
    return SampleSceneColor(uv, grabPos);
}

inline float3 SampleRefractionBlurredSceneColor(float2 baseUV, float4 baseGrabPos, float2 blurStepUV, float kernelSigma)
{
    float3 accum = 0.0.xxx;
    float weightSum = 0.0;

    [unroll]
    for (int y = -GLASS_REFRACTION_BLUR_RADIUS; y <= GLASS_REFRACTION_BLUR_RADIUS; y++)
    {
        [unroll]
        for (int x = -GLASS_REFRACTION_BLUR_RADIUS; x <= GLASS_REFRACTION_BLUR_RADIUS; x++)
        {
            float2 sampleIndex = float2((float)x, (float)y);
            float weight = GlassGaussianWeight2D(sampleIndex, kernelSigma);
            float2 uvOffset = float2(blurStepUV.x * sampleIndex.x, blurStepUV.y * sampleIndex.y);
            accum += SampleSceneColorOffset(baseUV, baseGrabPos, uvOffset) * weight;
            weightSum += weight;
        }
    }

    return accum / max(weightSum, 1e-5);
}

inline float GlassComputeEdgeDataValidity(float3 barycentric)
{
    float barySum = barycentric.x + barycentric.y + barycentric.z;
    float baryMin = min(barycentric.x, min(barycentric.y, barycentric.z));
    float baryMax = max(barycentric.x, max(barycentric.y, barycentric.z));
    float edgeDataValid = 1.0 - step(0.01, abs(barySum - 1.0));
    edgeDataValid *= step(-0.001, baryMin) * step(baryMax, 1.001);
    return edgeDataValid;
}

inline float GlassComputeMeshEdgeRaw(float3 barycentric, float3 edgeKeep)
{
    float widthPx = max(_MeshEdgeWidth, 0.0);
    float softnessPx = max(_MeshEdgeSoftness, 0.001);
    float3 fw = max(fwidth(barycentric), 1e-5.xxx);
    float3 edgeLo = fw * widthPx;
    float3 edgeHi = edgeLo + fw * softnessPx;
    float3 edge3 = 1.0 - smoothstep(edgeLo, edgeHi, barycentric);
    edge3 *= saturate(edgeKeep);
    return max(edge3.x, max(edge3.y, edge3.z));
}

inline float GlassComputeValidatedDistortionEdgeMask(float3 barycentric, float3 edgeKeep)
{
    float edgeDataValid = GlassComputeEdgeDataValidity(barycentric);
    float rawEdge = GlassComputeMeshEdgeRaw(barycentric, edgeKeep) * edgeDataValid;
    return saturate(sqrt(saturate(rawEdge)));
}

inline float ComputeBaseRefractionScale(float normalizedThickness, float nearFade, float2 screenUV)
{
    float refractionScale = _RefractionStrength * (0.25 + 0.75 * normalizedThickness);
    refractionScale *= nearFade;

    if (_ScreenEdgeFadePixels > 0.01)
    {
        float2 borderDistance01 = min(screenUV, 1.0 - screenUV);
        float minBorderDistance = min(borderDistance01.x, borderDistance01.y);
        float pixelDistance = minBorderDistance * min(_ScreenParams.x, _ScreenParams.y);
        float edgeFade = saturate(pixelDistance / _ScreenEdgeFadePixels);
        refractionScale *= edgeFade;
    }

    return refractionScale;
}

#endif
