#ifndef GLASS_COMMON_INCLUDED
#define GLASS_COMMON_INCLUDED

#include "UnityCG.cginc"

static const float GLASS_EPSILON = 1e-5;

inline float GlassSafePositive(float value)
{
    return max(value, GLASS_EPSILON);
}

inline float GlassSafeRcp(float value)
{
    return 1.0 / GlassSafePositive(abs(value));
}

inline float2 GlassGetScreenUV(float4 screenPos)
{
    float2 uv = screenPos.xy * GlassSafeRcp(screenPos.w);
#if UNITY_UV_STARTS_AT_TOP
    if (_ProjectionParams.x < 0.0)
    {
        uv.y = 1.0 - uv.y;
    }
#endif
    return uv;
}

inline float3 GlassSigmaFromReferenceColor(float3 transmittanceAtReference, float referenceDistance)
{
    float3 safeColor = max(transmittanceAtReference, float3(GLASS_EPSILON, GLASS_EPSILON, GLASS_EPSILON));
    float safeDistance = GlassSafePositive(referenceDistance);
    return -log(safeColor) / safeDistance;
}

inline float3 GlassComputeTransmittance(float3 sigma, float thickness)
{
    return exp(-sigma * max(thickness, 0.0));
}

inline float GlassSchlickFresnel(float cosTheta, float f0)
{
    float oneMinusCos = 1.0 - saturate(cosTheta);
    float oneMinusCos2 = oneMinusCos * oneMinusCos;
    float oneMinusCos5 = oneMinusCos2 * oneMinusCos2 * oneMinusCos;
    return f0 + (1.0 - f0) * oneMinusCos5;
}

inline float3 GlassSchlickFresnelColor(float cosTheta, float3 f0)
{
    float oneMinusCos = 1.0 - saturate(cosTheta);
    float oneMinusCos2 = oneMinusCos * oneMinusCos;
    float oneMinusCos5 = oneMinusCos2 * oneMinusCos2 * oneMinusCos;
    return f0 + (1.0.xxx - f0) * oneMinusCos5;
}

inline float GlassComputeApproxThickness(float fallbackThickness, float3 normalWS, float3 viewDirWS, float minDenominator)
{
    float ndotv = abs(dot(normalize(normalWS), normalize(viewDirWS)));
    float denom = max(ndotv, GlassSafePositive(minDenominator));
    return fallbackThickness / denom;
}

inline float3 GlassUnpackNormalTS(sampler2D normalMap, float2 uv, float scale)
{
    float3 normalTS = UnpackNormal(tex2D(normalMap, uv));
    normalTS.xy *= scale;
    normalTS.z = sqrt(saturate(1.0 - dot(normalTS.xy, normalTS.xy)));
    return normalTS;
}

inline float3 GlassTransformTangentToWorld(float3 normalTS, float3 tangentWS, float3 bitangentWS, float3 normalWS)
{
    float3x3 tbn = float3x3(normalize(tangentWS), normalize(bitangentWS), normalize(normalWS));
    return normalize(mul(normalTS, tbn));
}

inline float3 GlassHeatColor(float value01)
{
    float t = saturate(value01);
    float3 c;
    c.r = saturate(1.5 - abs(2.0 * t - 1.0) * 3.0);
    c.g = saturate(1.5 - abs(2.0 * t - 0.5) * 3.0);
    c.b = saturate(1.5 - abs(2.0 * t - 0.0) * 3.0);
    return c;
}

inline float GlassLuminance(float3 color)
{
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

inline bool GlassIsStereoEyeRight()
{
#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED) || defined(UNITY_SINGLE_PASS_STEREO)
    return unity_StereoEyeIndex == 1;
#else
    return false;
#endif
}

#endif
