Shader "Custom/VoronoiEffectURP"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _VoronoiScale ("Voronoi Scale", Float) = 5.0
        _TimeSpeed ("Animation Speed", Float) = 0.5
        _DisplacementAmount ("Displacement Amount", Range(0, 0.05)) = 0.01
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" "RenderType"="Opaque" "Queue"="Transparent" }

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float _VoronoiScale;
            float _TimeSpeed;
            float _DisplacementAmount;

            float random(float2 st)
            {
                return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            float2 random2(float2 st)
            {
                st = float2(dot(st, float2(127.1, 311.7)),
                            dot(st, float2(269.5, 183.3)));
                return frac(sin(st) * 43758.5453123);
            }

            float voronoi(float2 uv, out float2 closestCell)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);

                float minDist = 1.0;
                float2 cell;

                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(x, y);
                        float2 pt = random2(i + neighbor);

                        pt = 0.5 + 0.5 * sin(_Time.y * _TimeSpeed + 6.2831 * pt);

                        float2 diff = neighbor + pt - f;
                        float dist = length(diff);

                        if (dist < minDist)
                        {
                            minDist = dist;
                            cell = neighbor + pt;
                        }
                    }
                }

                closestCell = i + cell;
                return minDist;
            }

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS);
                OUT.uv = IN.uv;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv * _VoronoiScale;

                float2 closestCell;
                float d = voronoi(uv, closestCell);

                // Use distance to displace the texture sampling
                float2 disp = normalize(closestCell - uv) * d * _DisplacementAmount;

                float2 displacedUV = clamp(IN.uv + disp, 0.0, 1.0);
                float3 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, displacedUV).rgb;

                // Colorize Voronoi lines
                float3 lineColor = smoothstep(0.02, 0.0, d) * float3(1.0, 0.4, 0.1);

                return float4(texColor + lineColor, 1.0);
            }

            ENDHLSL
        }
    }
}
