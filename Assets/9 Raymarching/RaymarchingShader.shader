Shader "Custom/RayMarchingShader"
{
    Properties
    {
        _NumIterations ("Ray Marching Iterations", Range(1, 256)) = 64
        _SmoothUnionK ("Smooth Union k", Float) = 0.4
        _NumSpheres ("Number of Spheres", Range(1, 32)) = 16
        _SphereSizeMin ("Sphere Size Min", Float) = 0.5
        _SphereSizeMax ("Sphere Size Max", Float) = 1.0
        _SceneScale ("Scene Scale", Float) = 6.0
        _DepthFade ("Depth Fade", Float) = 0.15
        _Brightness ("Brightness", Float) = 1.0
        _AnimationSpeed ("Animation Speed", Float) = 3.0
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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Exposed parameters
            int _NumIterations;
            float _SmoothUnionK;
            int _NumSpheres;
            float _SphereSizeMin;
            float _SphereSizeMax;
            float _SceneScale;
            float _DepthFade;
            float _Brightness;
            float _AnimationSpeed;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
            };

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS);
                OUT.uv = IN.uv;
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                return OUT;
            }

            float opSmoothUnion(float d1, float d2, float k)
            {
                float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
                return lerp(d2, d1, h) - k * h * (1.0 - h);
            }

            float sdSphere(float3 p, float s)
            {
                return length(p) - s;
            }

            float map(float3 p)
            {
                float d = _SceneScale;
                for (int i = 0; i < _NumSpheres; i++)
                {
                    float fi = float(i);
                    float time = _Time.y * _AnimationSpeed * (frac(fi * 412.531 + 0.513) - 0.5) * 2.0;
                    float3 sinArg = time + fi * float3(52.5126, 64.62744, 632.25);
                    float3 spherePos = p + sin(sinArg) * float3(2.0, 2.0, 0.8);
                    float sphereSize = lerp(_SphereSizeMin, _SphereSizeMax, frac(fi * 412.531 + 0.5124));
                    float sphereDist = sdSphere(spherePos, sphereSize);
                    d = opSmoothUnion(sphereDist, d, _SmoothUnionK);
                }
                return d;
            }

            float3 calcNormal(float3 p)
            {
                float h = 1e-5;
                float2 k = float2(1.0, -1.0);
                float3 e1 = float3(k.x, k.y, k.y);
                float3 e2 = float3(k.y, k.y, k.x);
                float3 e3 = float3(k.y, k.x, k.y);
                float3 e4 = float3(k.x, k.x, k.x);

                return normalize(
                    e1 * map(p + e1 * h) +
                    e2 * map(p + e2 * h) +
                    e3 * map(p + e3 * h) +
                    e4 * map(p + e4 * h)
                );
            }

            half4 Frag(Varyings IN) : SV_Target
            {
                float2 fragCoord = (IN.screenPos.xy / IN.screenPos.w) * _ScreenParams.xy;
                float2 uv = fragCoord / _ScreenParams.xy;

                float aspectRatio = _ScreenParams.x / _ScreenParams.y;
                float2 scaledUV = (uv - 0.5) * float2(aspectRatio, 1.0) * _SceneScale;
                float3 rayOri = float3(scaledUV, 3.0);
                float3 rayDir = float3(0.0, 0.0, -1.0);

                float depth = 0.0;
                float3 p;

                for (int i = 0; i < _NumIterations; i++)
                {
                    p = rayOri + rayDir * depth;
                    float dist = map(p);
                    depth += dist;
                    if (dist < 1e-6)
                    {
                        break;
                    }
                }

                depth = min(_SceneScale, depth);
                float3 n = calcNormal(p);
                float3 lightDir = normalize(float3(0.577, 0.577, 0.577));
                float b = max(0.0, dot(n, lightDir));

                float3 col = (0.5 + 0.5 * cos((b + _Time.y * _AnimationSpeed) + float3(uv.x, uv.y, uv.x) * 2.0 + float3(0.0, 2.0, 4.0))) * (0.85 + b * 0.35);
                col *= exp(-depth * _DepthFade) * _Brightness;

                float alpha = saturate(1.0 - (depth - 0.5) / 2.0);

                return half4(col, alpha);
            }

            ENDHLSL
        }
    }
}
