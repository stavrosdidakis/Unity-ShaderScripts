Shader "Custom/DynamicFlow"
{
    Properties
    {
        // Time scaling factors
        _TimeScale ("Time Scale", Float) = 0.05
        _TimeOffset ("Time Offset", Float) = 47.0

        // Z scaling
        _ZScale ("Z Scale", Float) = 1.5

        // Color multipliers
        _ColMultiplier ("Color Multiplier", Float) = 0.5
        _ExpMultiplier ("Exp Multiplier", Float) = 10.0

        // Color adjustments
        _ColorAdjust1 ("Color Adjust 1", Color) = (1.6, 0.8, 0.5, 1.0)
        _ColorAdjust2 ("Color Adjust 2", Color) = (1.0, 0.9, 0.5, 1.0)
        _ColorAdjust3 ("Color Adjust 3", Color) = (0.8, 0.4, 0.2, 1.0)

        // Exponents
        _PowExponent ("Pow Exponent", Vector) = (0.8, 1.1, 1.3, 0.0)

        // UV Multiplier
        _UVMul ("UV Multiplier", Float) = 16.0

        // UV Exponent
        _UVExponent ("UV Exponent", Float) = 0.1

        // Control Booleans
        _timeOffsetControl ("Time Offset Control", Range(0,1)) = 0
        _zScaleControl ("Z Scale Control", Range(0,1)) = 0
        _powExponentControl ("Pow Exponent Control", Range(0,1)) = 0

        // Lerp Speed Controls
        _timeOffsetSpeed ("Time Offset Lerp Speed", Float) = 3.0
        _zScaleSpeed ("Z Scale Lerp Speed", Float) = 3.0
        _powExponentSpeed ("Pow Exponent Lerp Speed", Float) = 3.0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        }

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Define AA (Anti-Aliasing) level
            #define AA 1 // Reduced AA, assuming FXAA is enabled

            // Shader Properties
            float _TimeScale;
            float _TimeOffset;
            float _ZScale;
            float _ColMultiplier;
            float _ExpMultiplier;
            float4 _ColorAdjust1;
            float4 _ColorAdjust2;
            float4 _ColorAdjust3;
            float4 _PowExponent;
            float _UVMul;
            float _UVExponent;

            // Control Booleans
            float _timeOffsetControl;
            float _zScaleControl;
            float _powExponentControl;

            // Lerp Speed Controls
            float _timeOffsetSpeed;
            float _zScaleSpeed;
            float _powExponentSpeed;

            // Vertex Input Structure
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            // Vertex Output Structure (Interpolators)
            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
            };

            // Hash Functions for Random Value Generation
            float rand(int n)
            {
                return frac(sin(float(n)) * 43758.5453);
            }

            float3 rand3(int n)
            {
                return float3(frac(sin(float(n)) * 43758.5453),
                              frac(cos(float(n)) * 43758.5453),
                              frac(sin(float(n) * 2.0) * 43758.5453));
            }

            // Vertex Shader
            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                // Transform object space position to homogeneous clip space
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS);
                // Pass UV coordinates
                OUT.uv = IN.uv;
                // Compute screen position for fragment shader
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                return OUT;
            }

            // Function Declarations
            float3 shape(float2 uv, float actualTimeOffset, float actualZScale);

            // Fragment Shader
            half4 Frag(Varyings IN) : SV_Target
            {
                // Current time in seconds
                float currentTime = _Time.y;

                // Compute actual Time Offset
                float actualTimeOffset = _timeOffsetControl > 0.5 ?
                    lerp(
                        0.5 + rand(int(floor(currentTime / _timeOffsetSpeed))) * 4.5, // 0.5 to 5.0
                        0.5 + rand(int(floor(currentTime / _timeOffsetSpeed)) + 1) * 4.5, // 0.5 to 5.0
                        frac(currentTime / _timeOffsetSpeed)
                    ) :
                    _TimeOffset;

                // Compute actual Z Scale
                float actualZScale = _zScaleControl > 0.5 ?
                    lerp(
                        0.5 + rand(int(floor(currentTime / _zScaleSpeed))) * 4.5, // 0.5 to 5.0
                        0.5 + rand(int(floor(currentTime / _zScaleSpeed)) + 1) * 4.5, // 0.5 to 5.0
                        frac(currentTime / _zScaleSpeed)
                    ) :
                    _ZScale;

                // Compute actual Pow Exponent
                float3 actualPowExponent = _powExponentControl > 0.5 ?
                    lerp(
                        float3(0.5, 0.5, 0.5) + rand3(int(floor(currentTime / _powExponentSpeed))) * 2.5, // 0.5 to 3.0
                        float3(0.5, 0.5, 0.5) + rand3(int(floor(currentTime / _powExponentSpeed)) + 1) * 2.5, // 0.5 to 3.0
                        frac(currentTime / _powExponentSpeed)
                    ) :
                    _PowExponent.xyz;

                float e = 1.0 / _ScreenParams.x;

                float3 tot = float3(0.0, 0.0, 0.0);

                // Get fragCoord (pixel coordinates)
                float2 fragCoord = (IN.screenPos.xy / IN.screenPos.w) * _ScreenParams.xy;
                float2 invScreen = 1.0 / _ScreenParams.xy;

                for (int m = 0; m < AA; m++)
                {
                    for (int n = 0; n < AA; n++)
                    {
                        float2 uv = (fragCoord + float2(m, n) / AA) * invScreen;

                        // Use the actualTimeOffset and actualZScale
                        float3 col = shape(uv, actualTimeOffset, actualZScale);

                        float f = dot(col, float3(0.333, 0.333, 0.333));

                        // Cache shape results to avoid multiple calls
                        float3 shape_e_x = shape(uv + float2(e, 0.0), actualTimeOffset, actualZScale);
                        float3 shape_e_y = shape(uv + float2(0.0, e), actualTimeOffset, actualZScale);

                        float avg_col1 = (shape_e_x.x + shape_e_x.y + shape_e_x.z) * 0.333;
                        float avg_col2 = (shape_e_y.x + shape_e_y.y + shape_e_y.z) * 0.333;

                        float3 nor = normalize(float3(avg_col1 - f, avg_col2 - f, e));

                        col += 0.2 * _ColorAdjust2.rgb * dot(nor, _ColorAdjust3.rgb);
                        col += 0.3 * nor.z;

                        tot += col;
                    }
                }

                tot /= (AA * AA);

                // Use the actualPowExponent instead of the original _PowExponent
                tot = pow(saturate(tot), actualPowExponent);

                float2 uv_final = IN.uv;
                tot *= 0.4 + 0.6 * pow(_UVMul * uv_final.x * uv_final.y * (1.0 - uv_final.x) * (1.0 - uv_final.y), _UVExponent);

                return half4(tot, 1.0);
            }

            // Function Definitions
            float3 shape(float2 uv, float actualTimeOffset, float actualZScale)
            {
                float time = _Time.y * _TimeScale + actualTimeOffset;
                float2 z = -1.0 + 2.0 * uv;
                z *= actualZScale;

                float3 col = float3(1.0, 1.0, 1.0);

                #pragma unroll
                for (int j = 0; j < 32; j++) // Reduced loop count
                {
                    float s = float(j) / 16.0;
                    float f = 0.2 * (0.5 + frac(sin(s * 20.0)));

                    float2 c = 0.5 * float2(cos(f * time + 17.0 * s), sin(f * time + 19.0 * s));
                    z -= c;
                    float zr = length(z);
                    float ar = atan2(z.y, z.x) + zr * 0.6;
                    z = float2(cos(ar), sin(ar)) / zr;
                    z += c;

                    // Color computation
                    col -= _ColMultiplier * exp(-_ExpMultiplier * dot(z, z)) * (0.25 + 0.4 * sin(5.5 + 1.5 * s + _ColorAdjust1.rgb));
                }

                return col;
            }

            ENDHLSL
        }
    }
}
