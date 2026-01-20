// Assets/Shaders/PixelOutline.shader
Shader "Custom/PixelOutline"
{
    Properties
    {
        [Header(PIXELIZATION)]
        _PixelSize ("Pixel Size", Range(1, 32)) = 4
        [Toggle] _SubPixelStabilization ("Sub-Pixel Stabilization", Float) = 1
        
        [Header(COLOR)]
        _ColorCount ("Color Count (per channel)", Range(2, 64)) = 16
        _Saturation ("Saturation", Range(0, 2)) = 1
        _Contrast ("Contrast", Range(0.5, 2)) = 1
        _Brightness ("Brightness", Range(0.5, 2)) = 1
        
        [Header(DITHERING)]
        [Toggle] _EnableDithering ("Enable Dithering", Float) = 1
        _DitherStrength ("Dither Strength", Range(0, 1)) = 0.5
        
        [Header(OUTER OUTLINE)]
        [Toggle] _EnableOuterOutline ("Enable Outer Outline", Float) = 1
        _OuterOutlineThickness ("Thickness", Range(0.5, 4)) = 1
        _OuterOutlineColor ("Color", Color) = (0, 0, 0, 1)
        [KeywordEnum(Custom, AutoDark)] _OuterColorMode ("Color Mode", Float) = 0
        _OuterDarkness ("Auto Dark Amount", Range(0.3, 1)) = 0.5
        _DepthThreshold ("Depth Threshold", Range(0.01, 0.5)) = 0.05
        
        [Header(INNER OUTLINE)]
        [Toggle] _EnableInnerOutline ("Enable Inner Outline", Float) = 1
        _InnerOutlineThickness ("Thickness", Range(0.5, 3)) = 1
        [KeywordEnum(Brighten, Darken, Custom)] _InnerColorMode ("Color Mode", Float) = 0
        _InnerBrightness ("Brighten Amount", Range(1, 2)) = 1.3
        _InnerDarkness ("Darken Amount", Range(0.5, 1)) = 0.7
        _InnerOutlineColor ("Custom Color", Color) = (1, 1, 1, 1)
        _NormalThreshold ("Normal Threshold", Range(0.1, 1)) = 0.4
        
        [Header(PIXEL GRID)]
        [Toggle] _EnablePixelGrid ("Enable Pixel Grid", Float) = 0
        _GridColor ("Grid Color", Color) = (0, 0, 0, 0.2)
        _GridThickness ("Grid Thickness", Range(0.01, 0.5)) = 0.1
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline"
        }
        
        Pass
        {
            Name "PixelOutlineProPass"
            
            ZTest Always
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            
            #pragma multi_compile_local _ _OUTEREDGEMODE_AUTODARK
            #pragma multi_compile_local _INNEREDGEMODE_BRIGHTEN _INNEREDGEMODE_DARKEN _INNEREDGEMODE_CUSTOM
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            // Pixelization
            float _PixelSize;
            float _SubPixelStabilization;
            
            // Color
            float _ColorCount;
            float _Saturation;
            float _Contrast;
            float _Brightness;
            
            // Dithering
            float _EnableDithering;
            float _DitherStrength;
            
            // Outer Outline
            float _EnableOuterOutline;
            float _OuterOutlineThickness;
            float4 _OuterOutlineColor;
            float _OuterColorMode;
            float _OuterDarkness;
            float _DepthThreshold;
            
            // Inner Outline
            float _EnableInnerOutline;
            float _InnerOutlineThickness;
            float _InnerColorMode;
            float _InnerBrightness;
            float _InnerDarkness;
            float4 _InnerOutlineColor;
            float _NormalThreshold;
            
            // Pixel Grid
            float _EnablePixelGrid;
            float4 _GridColor;
            float _GridThickness;
            
            // ==================== BAYER DITHERING ====================
            static const float BayerMatrix8x8[64] = {
                 0, 32,  8, 40,  2, 34, 10, 42,
                48, 16, 56, 24, 50, 18, 58, 26,
                12, 44,  4, 36, 14, 46,  6, 38,
                60, 28, 52, 20, 62, 30, 54, 22,
                 3, 35, 11, 43,  1, 33,  9, 41,
                51, 19, 59, 27, 49, 17, 57, 25,
                15, 47,  7, 39, 13, 45,  5, 37,
                63, 31, 55, 23, 61, 29, 53, 21
            };
            
            float GetBayerValue(float2 pixelPos)
            {
                int x = int(fmod(pixelPos.x, 8.0));
                int y = int(fmod(pixelPos.y, 8.0));
                return BayerMatrix8x8[y * 8 + x] / 64.0;
            }
            
            // ==================== COLOR FUNCTIONS ====================
            float3 RGBtoHSV(float3 rgb)
            {
                float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
                float4 p = lerp(float4(rgb.bg, K.wz), float4(rgb.gb, K.xy), step(rgb.b, rgb.g));
                float4 q = lerp(float4(p.xyw, rgb.r), float4(rgb.r, p.yzx), step(p.x, rgb.r));
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }
            
            float3 HSVtoRGB(float3 hsv)
            {
                float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
                float3 p = abs(frac(hsv.xxx + K.xyz) * 6.0 - K.www);
                return hsv.z * lerp(K.xxx, saturate(p - K.xxx), hsv.y);
            }
            
            float3 AdjustSaturation(float3 color, float saturation)
            {
                float3 hsv = RGBtoHSV(color);
                hsv.y *= saturation;
                return HSVtoRGB(hsv);
            }
            
            float3 AdjustContrast(float3 color, float contrast)
            {
                return saturate((color - 0.5) * contrast + 0.5);
            }
            
            float3 QuantizeColor(float3 color, float levels, float2 pixelPos, float ditherStrength)
            {
                // Dithering uygula
                if (_EnableDithering > 0.5)
                {
                    float bayerValue = GetBayerValue(pixelPos);
                    float ditherAmount = (bayerValue - 0.5) * ditherStrength / levels;
                    color += ditherAmount;
                }
                
                // Renk quantization
                color = floor(color * levels + 0.5) / levels;
                return saturate(color);
            }
            
            // ==================== PIXELIZATION ====================
            float2 PixelateUV(float2 uv, float pixelSize)
            {
                float2 pixelCount = _ScreenParams.xy / pixelSize;
                float2 pixelatedUV = floor(uv * pixelCount) / pixelCount;
                
                // Sub-pixel stabilization
                if (_SubPixelStabilization > 0.5)
                {
                    pixelatedUV += 0.5 / pixelCount;
                }
                
                return pixelatedUV;
            }
            
            // ==================== DEPTH FUNCTIONS ====================
            float GetLinearDepth(float2 uv)
            {
                float rawDepth = SampleSceneDepth(uv);
                return LinearEyeDepth(rawDepth, _ZBufferParams);
            }
            
            float3 GetNormal(float2 uv)
            {
                return SampleSceneNormals(uv);
            }
            
            // ==================== SOBEL EDGE DETECTION ====================
            struct EdgeResult
            {
                float outerEdge;
                float innerEdge;
                float3 baseColor;
            };
            
            EdgeResult DetectEdges(float2 uv, float2 texelSize, float3 centerColor)
            {
                EdgeResult result;
                result.outerEdge = 0;
                result.innerEdge = 0;
                result.baseColor = centerColor;
                
                // Sobel kernels
                float sobelX[9] = { -1, 0, 1, -2, 0, 2, -1, 0, 1 };
                float sobelY[9] = { -1, -2, -1, 0, 0, 0, 1, 2, 1 };
                
                float2 offsets[9] = {
                    float2(-1, -1), float2(0, -1), float2(1, -1),
                    float2(-1,  0), float2(0,  0), float2(1,  0),
                    float2(-1,  1), float2(0,  1), float2(1,  1)
                };
                
                float centerDepth = GetLinearDepth(uv);
                float3 centerNormal = GetNormal(uv);
                
                // Depth Sobel
                float depthGradX = 0;
                float depthGradY = 0;
                
                // Normal difference
                float maxNormalDiff = 0;
                
                for (int i = 0; i < 9; i++)
                {
                    float2 outerOffset = offsets[i] * texelSize * _OuterOutlineThickness;
                    float2 innerOffset = offsets[i] * texelSize * _InnerOutlineThickness;
                    
                    // Outer outline (depth-based)
                    if (_EnableOuterOutline > 0.5)
                    {
                        float sampleDepth = GetLinearDepth(uv + outerOffset);
                        float depthDiff = (sampleDepth - centerDepth) / max(centerDepth, 0.01);
                        
                        depthGradX += depthDiff * sobelX[i];
                        depthGradY += depthDiff * sobelY[i];
                    }
                    
                    // Inner outline (normal-based)
                    if (_EnableInnerOutline > 0.5)
                    {
                        float3 sampleNormal = GetNormal(uv + innerOffset);
                        float normalDiff = 1.0 - saturate(dot(centerNormal, sampleNormal));
                        maxNormalDiff = max(maxNormalDiff, normalDiff);
                    }
                }
                
                // Outer edge strength (Sobel magnitude)
                float depthEdge = sqrt(depthGradX * depthGradX + depthGradY * depthGradY);
                result.outerEdge = smoothstep(_DepthThreshold * 0.5, _DepthThreshold, depthEdge);
                
                // Inner edge strength
                result.innerEdge = smoothstep(_NormalThreshold * 0.5, _NormalThreshold, maxNormalDiff);
                
                // Outer edge zaten varsa inner edge'i azalt
                result.innerEdge *= (1.0 - result.outerEdge);
                
                return result;
            }
            
            // ==================== PIXEL GRID ====================
            float GetPixelGrid(float2 uv, float pixelSize)
            {
                float2 pixelCount = _ScreenParams.xy / pixelSize;
                float2 pixelUV = frac(uv * pixelCount);
                
                float gridX = step(pixelUV.x, _GridThickness) + step(1.0 - _GridThickness, pixelUV.x);
                float gridY = step(pixelUV.y, _GridThickness) + step(1.0 - _GridThickness, pixelUV.y);
                
                return saturate(gridX + gridY);
            }
            
            // ==================== MAIN FRAGMENT ====================
            float4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;
                float2 pixelatedUV = PixelateUV(uv, _PixelSize);
                
                // Ana renk sample
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, pixelatedUV);
                
                // Color adjustments
                color.rgb = AdjustSaturation(color.rgb, _Saturation);
                color.rgb = AdjustContrast(color.rgb, _Contrast);
                color.rgb *= _Brightness;
                
                // Pixel position (for dithering)
                float2 pixelPos = pixelatedUV * _ScreenParams.xy / _PixelSize;
                
                // Color quantization with dithering
                color.rgb = QuantizeColor(color.rgb, _ColorCount, pixelPos, _DitherStrength);
                
                // Edge detection
                float2 texelSize = _BlitTexture_TexelSize.xy * _PixelSize;
                EdgeResult edges = DetectEdges(pixelatedUV, texelSize, color.rgb);
                
                // Apply outer outline
                if (_EnableOuterOutline > 0.5 && edges.outerEdge > 0.01)
                {
                    float3 outlineColor;
                    
                    if (_OuterColorMode > 0.5) // AutoDark
                    {
                        outlineColor = color.rgb * _OuterDarkness;
                    }
                    else // Custom
                    {
                        outlineColor = _OuterOutlineColor.rgb;
                    }
                    
                    color.rgb = lerp(color.rgb, outlineColor, edges.outerEdge);
                }
                
                // Apply inner outline
                if (_EnableInnerOutline > 0.5 && edges.innerEdge > 0.01)
                {
                    float3 innerColor;
                    
                    if (_InnerColorMode < 0.5) // Brighten
                    {
                        innerColor = color.rgb * _InnerBrightness;
                    }
                    else if (_InnerColorMode < 1.5) // Darken
                    {
                        innerColor = color.rgb * _InnerDarkness;
                    }
                    else // Custom
                    {
                        innerColor = _InnerOutlineColor.rgb;
                    }
                    
                    color.rgb = lerp(color.rgb, innerColor, edges.innerEdge * 0.7);
                }
                
                // Apply pixel grid
                if (_EnablePixelGrid > 0.5)
                {
                    float grid = GetPixelGrid(uv, _PixelSize);
                    color.rgb = lerp(color.rgb, _GridColor.rgb, grid * _GridColor.a);
                }
                
                return color;
            }
            ENDHLSL
        }
    }
}