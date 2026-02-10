#ifndef GLASS_REFRACTION_BLUR_INCLUDED
#define GLASS_REFRACTION_BLUR_INCLUDED

#ifndef GLASS_REFRACTION_BLUR_RADIUS
#define GLASS_REFRACTION_BLUR_RADIUS 3
#endif

inline float GlassComputePerceptualRoughness(float smoothness, float roughnessMapSample, float roughnessMapStrength)
{
    float basePerceptualRoughness = saturate(1.0 - smoothness);
    return saturate(lerp(basePerceptualRoughness, saturate(roughnessMapSample), saturate(roughnessMapStrength)));
}

inline float GlassGaussianWeight(float sampleIndex, float sigma)
{
    float sigmaSafe = max(sigma, 0.35);
    float invTwoSigma2 = 0.5 / (sigmaSafe * sigmaSafe);
    return exp(-sampleIndex * sampleIndex * invTwoSigma2);
}

inline float GlassGaussianWeight2D(float2 sampleIndex, float sigma)
{
    float sigmaSafe = max(sigma, 0.35);
    float invTwoSigma2 = 0.5 / (sigmaSafe * sigmaSafe);
    return exp(-dot(sampleIndex, sampleIndex) * invTwoSigma2);
}

inline float GlassCircularKernelWeight(float2 sampleIndex)
{
    float radius = (float)GLASS_REFRACTION_BLUR_RADIUS + 0.5;
    float dist = length(sampleIndex);
    return saturate((radius - dist) / max(radius, 1e-5));
}

inline float GlassComputeRefractionBlurStepUV(float blurDriver, float frontDepth, float blurScale, float aspect, float projectionM11)
{
    float depthSafe = max(frontDepth, 1e-3);
    float scale = blurScale / (float)GLASS_REFRACTION_BLUR_RADIUS;
    return blurDriver * rsqrt(depthSafe) * aspect * scale * abs(projectionM11);
}

inline float GlassComputeRefractionBlurDriver(float perceptualRoughness, float normalizedThickness, float roughnessInfluence, float thicknessInfluence)
{
    float roughnessDriver = lerp(1.0, saturate(perceptualRoughness), saturate(roughnessInfluence));
    float thicknessDriver = lerp(1.0, saturate(normalizedThickness), saturate(thicknessInfluence));
    return roughnessDriver * thicknessDriver;
}

inline float GlassClampBlurRadiusUVByPixelRadius(float radiusUV, float maxPixelRadius, float screenSize)
{
    float maxPixels = max(maxPixelRadius, 0.0);
    if (maxPixels <= 1e-4)
    {
        return 0.0;
    }

    float radiusPixels = abs(radiusUV) * max(screenSize, 1.0);
    if (radiusPixels <= maxPixels || radiusPixels <= 1e-6)
    {
        return radiusUV;
    }

    return radiusUV * (maxPixels / radiusPixels);
}

inline float GlassClampBlurStepUVByPixelRadius(float stepUV, float maxPixelRadius, float screenSize)
{
    return GlassClampBlurRadiusUVByPixelRadius(stepUV, maxPixelRadius, screenSize);
}

#endif
