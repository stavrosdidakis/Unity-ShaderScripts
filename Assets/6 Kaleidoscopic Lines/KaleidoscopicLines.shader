Shader "Custom/KaleidoscopicLines"
{
    Properties
    {
        // Palette parameters
        _PaletteA ("Palette A", Color) = (0.5, 0.5, 0.5, 1.0)
        _PaletteB ("Palette B", Color) = (0.5, 0.5, 0.5, 1.0)
        _PaletteC ("Palette C", Color) = (1.0, 1.0, 1.0, 1.0)
        _PaletteD ("Palette D", Color) = (0.263, 0.416, 0.557, 1.0)

        // Time scaling
        _TimeScale ("Time Scale", Float) = 0.4

        // UV scaling
        _UVScale ("UV Scale", Float) = 1.5

        // Iteration count (integer between 1 and 10)
        [IntRange] _Iterations ("Iterations", Range(1, 10)) = 4

        // Sin scale
        _SinScale ("Sin Scale", Float) = 8.0

        // Power exponent
        _PowExponent ("Power Exponent", Float) = 1.2
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
            // Shader target and pragmas
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Shader Properties
            float4 _PaletteA;
            float4 _PaletteB;
            float4 _PaletteC;
            float4 _PaletteD;
            float _TimeScale;
            float _UVScale;
            int _Iterations;
            float _SinScale;
            float _PowExponent;

            // Vertex Input Structure
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            // Vertex Output Structure
            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
            };

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

            // Palette function
            float3 palette(float t)
            {
                float3 a = _PaletteA.rgb;
                float3 b = _PaletteB.rgb;
                float3 c = _PaletteC.rgb;
                float3 d = _PaletteD.rgb;

                return a + b * cos(6.28318 * (c * t + d));
            }

            // Fragment Shader
            half4 Frag(Varyings IN) : SV_Target
            {
                // Get fragCoord (pixel coordinates)
                float2 fragCoord = (IN.screenPos.xy / IN.screenPos.w) * _ScreenParams.xy;

                // Compute UV coordinates
                float2 uv = (fragCoord * 2.0 - _ScreenParams.xy) / _ScreenParams.y;
                float2 uv0 = uv;
                float3 finalColor = float3(0.0, 0.0, 0.0);

                [loop]
                for (int i = 0; i < _Iterations; i++)
                {
                    uv = frac(uv * _UVScale) - 0.5;

                    float d = length(uv) * exp(-length(uv0));

                    float3 col = palette(length(uv0) + i * 0.4 + _Time.y * _TimeScale);

                    d = sin(d * _SinScale + _Time.y) / _SinScale;
                    d = abs(d);

                    d = pow(0.01 / d, _PowExponent);

                    finalColor += col * d;
                }

                return half4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }
}
