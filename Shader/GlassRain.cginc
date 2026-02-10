#ifndef GLASS_RAIN_INCLUDED
#define GLASS_RAIN_INCLUDED

sampler2D _GlassRainMask;
sampler2D _GlassRainSheet;
sampler2D _GlassRainDropletMask;
sampler2D _GlassRainNoiseTex;

float4 _GlassRainMask_ST;

float _GlassRainEnabled;
float _GlassRainMode;
float _GlassRainMaskChannel;
float _GlassRainNormalBlend;
float _GlassRainWetness;
float _GlassRainStrength;
float _GlassRainSpeed;
float4 _GlassRainTiling;
float _GlassRainSheetRows;
float _GlassRainSheetColumns;
float _GlassRainDynamicDroplets;
float _GlassRainRippleStrength;
float _GlassRainRippleScale;
float _GlassRainRippleSpeed;
float _GlassRainRippleDensity;
float _GlassRainAutoThreshold;
float _GlassRainAutoBlend;

inline float GlassRainSelectChannel(float4 rgba, float channel)
{
    if (channel < 0.5) return rgba.r;
    if (channel < 1.5) return rgba.g;
    if (channel < 2.5) return rgba.b;
    return rgba.a;
}

inline float2 GlassRainResolveUV(float2 uv, float isBackFacePass)
{
    if (isBackFacePass > 0.5)
    {
        uv.y = 1.0 - uv.y;
    }
    return uv;
}

inline float2 GlassRainGetFlipbookUV(float2 uv, float columns, float rows, float speed)
{
    float safeColumns = max(columns, 1.0);
    float safeRows = max(rows, 1.0);
    float frameCount = safeColumns * safeRows;
    float frame = fmod(floor(_Time.y * speed), frameCount);
    float frameY = floor(frame / safeColumns);
    float frameX = frame - frameY * safeColumns;
    float2 tileScale = float2(1.0 / safeColumns, 1.0 / safeRows);
    float2 tileOffset = float2(frameX, safeRows - 1.0 - frameY) * tileScale;
    return frac(uv) * tileScale + tileOffset;
}

inline float3 GlassRainHeightNormalTS(sampler2D tex, float2 uv, float4 uvdd, float strength, out float height)
{
    const float kOffset = 0.0003375;
    height = tex2Dgrad(tex, uv, uvdd.xy, uvdd.zw).g;
    float hU = tex2Dgrad(tex, uv + float2(kOffset, 0.0), uvdd.xy, uvdd.zw).g;
    float hV = tex2Dgrad(tex, uv + float2(0.0, kOffset), uvdd.xy, uvdd.zw).g;
    float2 grad = float2(hU - height, hV - height);
    return normalize(float3(-grad * strength, 1.0));
}

inline void GlassRainBuildDropletsTS(float2 baseUV, float rainMask, out float3 rainTS, out float wetness)
{
    float2 tiling = max(abs(_GlassRainTiling.xy), float2(0.0001, 0.0001));
    float2 rainUV = baseUV * tiling;
    float2 flipUV = GlassRainGetFlipbookUV(rainUV, _GlassRainSheetColumns, _GlassRainSheetRows, _GlassRainSpeed);

    float2 frameUV = rainUV / float2(max(_GlassRainSheetColumns, 1.0), max(_GlassRainSheetRows, 1.0));
    float4 uvdd = float4(ddx(frameUV), ddy(frameUV));

    float flipbookHeight;
    rainTS = GlassRainHeightNormalTS(_GlassRainSheet, flipUV, uvdd, _GlassRainStrength * rainMask, flipbookHeight);
    wetness = saturate(flipbookHeight);

    [branch]
    if (_GlassRainDynamicDroplets > 0.001)
    {
        float4 droplet = tex2D(_GlassRainDropletMask, rainUV);
        float phase = frac(droplet.b + _Time.y * (_GlassRainSpeed * 0.005));
        float alive = smoothstep(1.0 - _GlassRainDynamicDroplets, 1.0, droplet.a - phase);
        float2 dropletXY = droplet.rg * 2.0 - 1.0;
        float3 dropletTS = normalize(float3(dropletXY * (_GlassRainStrength * 2.0 * rainMask), 1.0));
        rainTS = normalize(lerp(rainTS, dropletTS, alive));
        wetness = saturate(wetness + alive * 0.7);
    }
}

inline void GlassRainBuildRipplesTS(float2 baseUV, float rainMask, out float3 rainTS, out float wetness)
{
    float scale = max(_GlassRainRippleScale * _GlassRainRippleDensity, 0.001);
    float t = _Time.y * _GlassRainRippleSpeed;

    float2 uv0 = baseUV * scale + float2(t * 0.071, t * 0.043);
    float2 uv1 = baseUV * (scale * 1.37) - float2(t * 0.059, t * 0.067);

    float2 n0 = tex2D(_GlassRainNoiseTex, uv0).rg * 2.0 - 1.0;
    float2 n1 = tex2D(_GlassRainNoiseTex, uv1).rg * 2.0 - 1.0;

    float2 rippleXY = (n0 + n1 * 0.65) * (_GlassRainRippleStrength * rainMask);
    rainTS = normalize(float3(rippleXY, 1.0));
    wetness = saturate(dot(rippleXY, rippleXY) * 1.1 + rainMask * 0.25);
}

inline void GlassApplyRain(in Varyings input, inout float3 normalWS, inout float perceptualRoughness, float isBackFacePass)
{
    [branch]
    if (_GlassRainEnabled <= 0.5)
    {
        return;
    }

    float2 baseUV = GlassRainResolveUV(input.uv, isBackFacePass);
    float2 maskUV = TRANSFORM_TEX(baseUV, _GlassRainMask);
    float rainMask = saturate(GlassRainSelectChannel(tex2D(_GlassRainMask, maskUV), _GlassRainMaskChannel));
    [branch]
    if (rainMask <= 1e-4)
    {
        return;
    }

    float3 rainDropletsTS = float3(0.0, 0.0, 1.0);
    float3 rainRipplesTS = float3(0.0, 0.0, 1.0);
    float wetDroplets = 0.0;
    float wetRipples = 0.0;

    float mode = round(_GlassRainMode);
    if (mode < 0.5)
    {
        return;
    }
    else if (mode < 1.5)
    {
        GlassRainBuildDropletsTS(baseUV, rainMask, rainDropletsTS, wetDroplets);
    }
    else if (mode < 2.5)
    {
        GlassRainBuildRipplesTS(baseUV, rainMask, rainRipplesTS, wetRipples);
    }
    else
    {
        GlassRainBuildDropletsTS(baseUV, rainMask, rainDropletsTS, wetDroplets);
        GlassRainBuildRipplesTS(baseUV, rainMask, rainRipplesTS, wetRipples);
    }

    float3 rainTS = rainDropletsTS;
    float rainWetness = wetDroplets;
    if (mode >= 1.5 && mode < 2.5)
    {
        rainTS = rainRipplesTS;
        rainWetness = wetRipples;
    }
    else if (mode >= 2.5)
    {
        float flatness = 1.0 - abs(dot(normalize(input.normalWS), float3(0.0, 1.0, 0.0)));
        float halfWidth = max(_GlassRainAutoBlend, 0.01) * 0.5;
        float blend = smoothstep(_GlassRainAutoThreshold - halfWidth, _GlassRainAutoThreshold + halfWidth, flatness);
        rainTS = normalize(lerp(rainRipplesTS, rainDropletsTS, blend));
        rainWetness = lerp(wetRipples, wetDroplets, blend);
    }

    float3 baseNormalWS = normalize(normalWS);
    float3 geomNormalWS = normalize(input.normalWS);
    float3 tangentWS = normalize(input.tangentWS);
    float3 bitangentWS = normalize(input.bitangentWS);
    float3 rainNormalWS = normalize(rainTS.x * tangentWS + rainTS.y * bitangentWS + rainTS.z * geomNormalWS);

    float blendWeight = saturate(_GlassRainNormalBlend * rainMask);
    float3 detailDelta = rainNormalWS - geomNormalWS;
    normalWS = normalize(baseNormalWS + detailDelta * blendWeight);

    float wetness = saturate(rainWetness * rainMask * _GlassRainWetness);
    perceptualRoughness = saturate(perceptualRoughness - wetness);
}

#endif
