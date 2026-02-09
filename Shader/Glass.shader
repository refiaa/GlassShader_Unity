Shader "refiaa/glass"
{
    Properties
    {
        [Header(Core Absorption)]
        _BaseTint("Reserved RGB / Effect Blend (A)", Color) = (1, 1, 1, 1)
        _TransmissionColorAtDistance("Transmittance At Reference Distance", Color) = (0.97647, 1.00000, 0.99608, 1)
        _ReferenceDistance("Reference Distance (Meters)", Range(0.001, 0.250)) = 0.010
        _ThicknessScale("Thickness Scale", Range(0.010, 10.000)) = 0.500
        _ThicknessBias("Thickness Bias (Meters)", Range(-0.020, 0.020)) = 0.020
        _MaxThickness("Max Thickness (Meters)", Range(0.001, 2.000)) = 0.200
        _FallbackThickness("Fallback Thickness (Meters)", Range(0.0001, 0.1000)) = 0.0001
        [Toggle] _FallbackUseAngle("Fallback Use Angle Correction", Float) = 1
        [Toggle] _UseBoundsThicknessFallback("Use Bounds Thickness Fallback", Float) = 1
        _BoundsFallbackBlend("Bounds Fallback Blend", Range(0.000, 1.000)) = 1.000
        _FallbackBoundsMin("Fallback Bounds Min (Object)", Vector) = (-0.5, -0.5, -0.5, 0)
        _FallbackBoundsMax("Fallback Bounds Max (Object)", Vector) = (0.5, 0.5, 0.5, 0)
        _FallbackAbsorptionScale("Fallback Absorption Scale", Range(0.000, 1.000)) = 1.000
        _MinViewDot("Fallback Min |N.V|", Range(0.010, 1.000)) = 0.030
        _GrazingAssistNdotV("Grazing Assist NdotV", Range(0.050, 0.600)) = 0.250
        _GrazingThicknessAssist("Grazing Thickness Assist", Range(0.000, 2.000)) = 0.000
        _NearFadeDistance("Near Camera Fade Distance (Meters)", Range(0.000, 0.200)) = 0.040
        _DepthEdgeFixPixels("Back Depth Edge Fix Radius (Pixels)", Range(0.0, 3.0)) = 1.500

        [Header(Refraction)]
        _RefractionStrength("Refraction Strength", Range(0.000, 0.200)) = 0.010
        [Toggle] _UseChromaticAberration("Use Chromatic Aberration", Float) = 1
        _ChromaticAberration("Chromatic Aberration (Pixels)", Range(0.000, 3.000)) = 3.000
        _ScreenEdgeFadePixels("Refraction Screen Edge Fade (Pixels)", Range(0.0, 32.0)) = 32.000

        [Header(Reflection)]
        _IOR("Index Of Refraction", Range(1.000, 2.000)) = 1.000
        _ReflectionTint("Reflection Tint", Color) = (1, 1, 1, 1)
        _EnvReflectionStrength("Environment Reflection Strength", Range(0.000, 4.000)) = 1.500
        _SpecularStrength("Direct Specular Strength", Range(0.000, 4.000)) = 0.250
        _Smoothness("Smoothness", Range(0.000, 1.000)) = 1.000
        _FresnelBoost("Fresnel Boost", Range(0.000, 2.000)) = 0.850
        _TransmissionAtGrazing("Transmission At Grazing", Range(0.000, 1.000)) = 0.300
        _ReflectionAbsorption("Reflection Absorption Coupling", Range(0.000, 1.000)) = 0.500

        [Header(Surface Detail)]
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0.000, 2.000)) = 1.000

        [Header(External Inputs)]
        [NoScaleOffset] _BackDepthTex("Back Depth Texture (Linear Eye)", 2D) = "black" {}
        [NoScaleOffset] _SceneColorTex("Scene Color Texture", 2D) = "black" {}
        [Toggle] _UseSceneColorTexture("Use External Scene Color Texture", Float) = 0
        [Toggle] _UseBackDepthTexture("Use Back Depth Texture", Float) = 1
        [Toggle] _BackDepthIsLinear("Back Depth Is Linear Eye Depth", Float) = 1
        [Toggle] _UseUdonStereoTextures("Use Udon Stereo Textures", Float) = 0
        [Toggle] _UseGrabPassFallback("Use GrabPass Fallback", Float) = 1
        _UVClamp("UV Clamp Padding", Range(0.000, 0.010)) = 0.001

        [Header(Debug)]
        [KeywordEnum(None, Thickness, Transmittance, Fresnel)] _DebugView("Debug View", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
            "VRCFallback" = "Transparent"
        }

        LOD 400
        Cull Back
        ZWrite Off
        ZTest LEqual
        Blend One Zero

        GrabPass
        {
            "_GlassGrabTex"
        }

        Pass
        {
            Name "FORWARD_BASE"
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_instancing
            #pragma shader_feature_local _DEBUGVIEW_NONE _DEBUGVIEW_THICKNESS _DEBUGVIEW_TRANSMITTANCE _DEBUGVIEW_FRESNEL

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "GlassCommon.cginc"

            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float4 grabPos : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                float3 normalWS : TEXCOORD4;
                float3 tangentWS : TEXCOORD5;
                float3 bitangentWS : TEXCOORD6;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _NormalMap;
            sampler2D _BackDepthTex;
            sampler2D _SceneColorTex;
            sampler2D _GlassGrabTex;
            sampler2D _UdonGlassBackDepthL;
            sampler2D _UdonGlassBackDepthR;
            sampler2D _UdonGlassSceneColorL;
            sampler2D _UdonGlassSceneColorR;

            float4 _BaseTint;
            float4 _TransmissionColorAtDistance;
            float4 _ReflectionTint;
            float4 _NormalMap_ST;
            float _ReferenceDistance;
            float _ThicknessScale;
            float _ThicknessBias;
            float _MaxThickness;
            float _FallbackThickness;
            float _FallbackUseAngle;
            float _UseBoundsThicknessFallback;
            float _BoundsFallbackBlend;
            float4 _FallbackBoundsMin;
            float4 _FallbackBoundsMax;
            float _FallbackAbsorptionScale;
            float _MinViewDot;
            float _GrazingAssistNdotV;
            float _GrazingThicknessAssist;
            float _NearFadeDistance;
            float _DepthEdgeFixPixels;
            float _RefractionStrength;
            float _UseChromaticAberration;
            float _ChromaticAberration;
            float _ScreenEdgeFadePixels;
            float _IOR;
            float _EnvReflectionStrength;
            float _SpecularStrength;
            float _Smoothness;
            float _FresnelBoost;
            float _TransmissionAtGrazing;
            float _ReflectionAbsorption;
            float _NormalScale;
            float _UseSceneColorTexture;
            float _UseBackDepthTexture;
            float _BackDepthIsLinear;
            float _UseUdonStereoTextures;
            float _UseGrabPassFallback;
            float _UVClamp;

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_OUTPUT(Varyings, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.positionCS = UnityObjectToClipPos(input.vertex);
                output.uv = TRANSFORM_TEX(input.uv, _NormalMap);
                output.screenPos = ComputeScreenPos(output.positionCS);
                output.grabPos = ComputeGrabScreenPos(output.positionCS);
                output.worldPos = mul(unity_ObjectToWorld, input.vertex).xyz;

                output.normalWS = UnityObjectToWorldNormal(input.normal);
                output.tangentWS = UnityObjectToWorldDir(input.tangent.xyz);
                float tangentSign = input.tangent.w * unity_WorldTransformParams.w;
                output.bitangentWS = cross(output.normalWS, output.tangentWS) * tangentSign;

                return output;
            }

            float2 ClampSceneUV(float2 uv)
            {
                float padding = saturate(_UVClamp);
                return clamp(uv, padding, 1.0 - padding);
            }

            float SampleBackDepthRaw(float2 uv)
            {
                if (_UseUdonStereoTextures > 0.5)
                {
                    return GlassIsStereoEyeRight() ? tex2D(_UdonGlassBackDepthR, uv).r : tex2D(_UdonGlassBackDepthL, uv).r;
                }

                return tex2D(_BackDepthTex, uv).r;
            }

            float SampleBackDepth(float2 uv)
            {
                float rawDepth = SampleBackDepthRaw(uv);

                if (_BackDepthIsLinear > 0.5)
                {
                    return rawDepth;
                }

                return LinearEyeDepth(rawDepth);
            }

            float BackDepthIsValid(float backDepth, float frontDepth)
            {
                return step(frontDepth + 1e-4, backDepth) * step(1e-5, backDepth);
            }

            void UpdateBestBackDepth(float depth, float valid, inout float bestDepth, inout float bestValid)
            {
                if (valid > 0.5 && (bestValid < 0.5 || depth > bestDepth))
                {
                    bestDepth = depth;
                    bestValid = valid;
                }
            }

            void SampleAndUpdateBackDepth(float2 uv, float frontDepth, inout float bestDepth, inout float bestValid)
            {
                float depth = SampleBackDepth(uv);
                float valid = BackDepthIsValid(depth, frontDepth);
                UpdateBestBackDepth(depth, valid, bestDepth, bestValid);
            }

            float SampleBackDepthRobust(float2 uv, float frontDepth, out float valid)
            {
                float bestDepth = SampleBackDepth(uv);
                float bestValid = BackDepthIsValid(bestDepth, frontDepth);

                if (_DepthEdgeFixPixels > 0.01)
                {
                    float2 texel = 1.0 / max(_ScreenParams.xy, float2(1.0, 1.0));
                    float2 offset = texel * _DepthEdgeFixPixels;

                    float2 uv1 = ClampSceneUV(uv + float2(offset.x, 0.0));
                    float2 uv2 = ClampSceneUV(uv - float2(offset.x, 0.0));
                    float2 uv3 = ClampSceneUV(uv + float2(0.0, offset.y));
                    float2 uv4 = ClampSceneUV(uv - float2(0.0, offset.y));

                    SampleAndUpdateBackDepth(uv1, frontDepth, bestDepth, bestValid);
                    SampleAndUpdateBackDepth(uv2, frontDepth, bestDepth, bestValid);
                    SampleAndUpdateBackDepth(uv3, frontDepth, bestDepth, bestValid);
                    SampleAndUpdateBackDepth(uv4, frontDepth, bestDepth, bestValid);
                }

                valid = bestValid;
                return bestDepth;
            }

            float3 SampleGrabColor(float4 grabPos)
            {
                float invW = 1.0 / max(grabPos.w, 1e-5);
                float2 uv = ClampSceneUV(grabPos.xy * invW);
                return tex2D(_GlassGrabTex, uv).rgb;
            }

            float ComputeBoundsFallbackThickness(float3 worldPos, float3 viewDirWS, float3 boundsMinOS, float3 boundsMaxOS)
            {
                float3 bMin = min(boundsMinOS, boundsMaxOS);
                float3 bMax = max(boundsMinOS, boundsMaxOS);

                float3 startOS = mul(unity_WorldToObject, float4(worldPos, 1.0)).xyz;
                float3 dirOS = mul((float3x3)unity_WorldToObject, -normalize(viewDirWS));

                float3 dirSign = lerp(-1.0.xxx, 1.0.xxx, step(0.0.xxx, dirOS));
                float3 smallMask = 1.0.xxx - step(1e-5.xxx, abs(dirOS));
                float3 safeDirOS = dirOS + dirSign * smallMask * 1e-5;
                float3 invDirOS = 1.0 / safeDirOS;

                startOS += normalize(safeDirOS) * 1e-4;

                float3 t0 = (bMin - startOS) * invDirOS;
                float3 t1 = (bMax - startOS) * invDirOS;
                float3 tMin = min(t0, t1);
                float3 tMax = max(t0, t1);

                float tNear = max(max(tMin.x, tMin.y), tMin.z);
                float tFar = min(min(tMax.x, tMax.y), tMax.z);
                return max(0.0, tFar - max(tNear, 0.0));
            }

            float3 SampleSceneColor(float2 uv, float4 grabPos)
            {
                if (_UseSceneColorTexture > 0.5)
                {
                    if (_UseUdonStereoTextures > 0.5)
                    {
                        return GlassIsStereoEyeRight() ? tex2D(_UdonGlassSceneColorR, uv).rgb : tex2D(_UdonGlassSceneColorL, uv).rgb;
                    }
                    return tex2D(_SceneColorTex, uv).rgb;
                }

                if (_UseGrabPassFallback > 0.5)
                {
                    if (grabPos.w <= 1e-5)
                    {
                        return tex2D(_GlassGrabTex, ClampSceneUV(uv)).rgb;
                    }
                    return SampleGrabColor(grabPos);
                }

                return 0.0.xxx;
            }

            float4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float3 viewDirWS = normalize(UnityWorldSpaceViewDir(input.worldPos));
                float3 normalTS = GlassUnpackNormalTS(_NormalMap, input.uv, _NormalScale);
                float tangentLen2 = dot(input.tangentWS, input.tangentWS);
                float3 normalWS = normalize(input.normalWS);
                if (tangentLen2 > 1e-5)
                {
                    normalWS = GlassTransformTangentToWorld(normalTS, input.tangentWS, input.bitangentWS, input.normalWS);
                }
                float3 normalVS = mul((float3x3)UNITY_MATRIX_V, normalWS);

                float2 screenUV = ClampSceneUV(GlassGetScreenUV(input.screenPos));
                float frontDepth = max(-mul(UNITY_MATRIX_V, float4(input.worldPos, 1.0)).z, 0.0);

                float approxThickness = _FallbackThickness;
                if (_FallbackUseAngle > 0.5)
                {
                    approxThickness = GlassComputeApproxThickness(_FallbackThickness, normalWS, viewDirWS, _MinViewDot);
                }

                if (_UseBoundsThicknessFallback > 0.5)
                {
                    float boundsThickness = ComputeBoundsFallbackThickness(input.worldPos, viewDirWS, _FallbackBoundsMin.xyz, _FallbackBoundsMax.xyz);
                    float blendedBoundsThickness = lerp(approxThickness, boundsThickness, saturate(_BoundsFallbackBlend));
                    approxThickness = max(blendedBoundsThickness, approxThickness * 0.05);
                }
                approxThickness = approxThickness * _ThicknessScale + _ThicknessBias;

                float exactValid;
                float backDepth = SampleBackDepthRobust(screenUV, frontDepth, exactValid);
                float exactThickness = (backDepth - frontDepth) * _ThicknessScale + _ThicknessBias;
                float useExactThickness = step(0.5, _UseBackDepthTexture) * exactValid;
                float thickness = lerp(approxThickness, exactThickness, useExactThickness);
                thickness = clamp(thickness, 0.0, _MaxThickness);

                // Side-view robustness: when exact back-front depth collapses at grazing angles,
                // keep physically plausible thickness using the angle-based approximation only near grazing.
                float ndotvAbs = abs(dot(normalWS, viewDirWS));
                float grazing01 = 1.0 - saturate(ndotvAbs / max(_GrazingAssistNdotV, 1e-4));
                float grazingAssistThickness = approxThickness * grazing01 * _GrazingThicknessAssist;
                thickness = max(thickness, grazingAssistThickness * useExactThickness + thickness * (1.0 - useExactThickness));
                thickness = clamp(thickness, 0.0, _MaxThickness);

                float nearFade = 1.0;
                if (_NearFadeDistance > 1e-4)
                {
                    nearFade = saturate(frontDepth / _NearFadeDistance);
                }
                thickness *= nearFade;

                float absorptionThickness = thickness * lerp(saturate(_FallbackAbsorptionScale), 1.0, useExactThickness);
                absorptionThickness = clamp(absorptionThickness, 0.0, _MaxThickness);

                float3 sigma = GlassSigmaFromReferenceColor(_TransmissionColorAtDistance.rgb, _ReferenceDistance);
                float3 transmittance = GlassComputeTransmittance(sigma, absorptionThickness);

                float normalizedThickness = absorptionThickness / max(_MaxThickness, 1e-5);
                float refractionScale = _RefractionStrength * (0.25 + 0.75 * saturate(normalizedThickness));
                refractionScale *= nearFade;
                if (_ScreenEdgeFadePixels > 0.01)
                {
                    float2 borderDistance01 = min(screenUV, 1.0 - screenUV);
                    float minBorderDistance = min(borderDistance01.x, borderDistance01.y);
                    float pixelDistance = minBorderDistance * min(_ScreenParams.x, _ScreenParams.y);
                    float edgeFade = saturate(pixelDistance / _ScreenEdgeFadePixels);
                    refractionScale *= edgeFade;
                }

                float2 refractionOffset = normalVS.xy * refractionScale;
                float2 refractedUV = ClampSceneUV(screenUV + refractionOffset);
                float4 refractedGrabPos = input.grabPos;
                refractedGrabPos.xy += refractionOffset * refractedGrabPos.w;

                float3 sceneColor;
                if (_UseChromaticAberration > 0.5)
                {
                    float2 pixelSize = 1.0 / max(_ScreenParams.xy, float2(1.0, 1.0));
                    float2 chromaDir = normalize(refractionOffset + float2(1e-6, 0.0));
                    float chromaFade = saturate(refractionScale / max(_RefractionStrength, 1e-5));
                    float2 chromaOffset = chromaDir * (_ChromaticAberration * pixelSize * chromaFade);

                    float2 uvR = ClampSceneUV(refractedUV + chromaOffset);
                    float2 uvB = ClampSceneUV(refractedUV - chromaOffset);
                    float4 grabPosR = refractedGrabPos;
                    float4 grabPosB = refractedGrabPos;
                    grabPosR.xy += chromaOffset * grabPosR.w;
                    grabPosB.xy -= chromaOffset * grabPosB.w;

                    sceneColor.r = SampleSceneColor(uvR, grabPosR).r;
                    sceneColor.g = SampleSceneColor(refractedUV, refractedGrabPos).g;
                    sceneColor.b = SampleSceneColor(uvB, grabPosB).b;
                }
                else
                {
                    sceneColor = SampleSceneColor(refractedUV, refractedGrabPos);
                }

                float eta = max(_IOR, 1.0001);
                float f0 = pow((eta - 1.0) / (eta + 1.0), 2.0);
                float cosTheta = saturate(dot(normalWS, viewDirWS));
                float fresnel = saturate(GlassSchlickFresnel(cosTheta, f0) * _FresnelBoost);
                float transmissionWeight = saturate((1.0 - fresnel) + _TransmissionAtGrazing * fresnel);
                float reflectionWeight = saturate(1.0 - transmissionWeight);

                float3 reflectionDirWS = reflect(-viewDirWS, normalWS);
                float iblLod = (1.0 - saturate(_Smoothness)) * 6.0;
                half4 encodedIbl = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectionDirWS, iblLod);
                float3 envReflection = DecodeHDR(encodedIbl, unity_SpecCube0_HDR);

                float3 lightDirWS = normalize(UnityWorldSpaceLightDir(input.worldPos));
                float3 halfDirWS = normalize(lightDirWS + viewDirWS);
                float nDotL = saturate(dot(normalWS, lightDirWS));
                float nDotH = saturate(dot(normalWS, halfDirWS));
                float specPower = lerp(16.0, 8192.0, saturate(_Smoothness));
                float directSpecularFactor = pow(nDotH, specPower) * nDotL;
                float3 directSpecular = directSpecularFactor * _LightColor0.rgb * _SpecularStrength;

                float3 reflectionColor = (envReflection * _EnvReflectionStrength + directSpecular) * _ReflectionTint.rgb;
                float3 reflectionAbsorption = GlassComputeTransmittance(sigma, absorptionThickness * 2.0);
                reflectionColor *= lerp(1.0.xxx, reflectionAbsorption, saturate(_ReflectionAbsorption));

                float3 transmittedColor = sceneColor * transmittance;
                float3 composedColor = reflectionColor * reflectionWeight + transmittedColor * transmissionWeight;
                float3 finalColor = lerp(sceneColor, composedColor, saturate(_BaseTint.a));

                #if defined(_DEBUGVIEW_THICKNESS)
                    finalColor = GlassHeatColor(normalizedThickness);
                #elif defined(_DEBUGVIEW_TRANSMITTANCE)
                    finalColor = transmittance;
                #elif defined(_DEBUGVIEW_FRESNEL)
                    finalColor = fresnel.xxx;
                #endif

                return float4(finalColor, 1.0);
            }
            ENDCG
        }
    }

    CustomEditor "GlassShaderGUI"
    Fallback "Transparent/VertexLit"
}
