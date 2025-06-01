Shader "Custom/BaseWarpFBMShader"
{
    Properties
    {
        _FBM_Scale ("FBM Scale", Float) = 2.02
        _FBM_Weight1 ("FBM Weight 1", Float) = 0.5
        _FBM_Weight2 ("FBM Weight 2", Float) = 0.25
        _FBM_Weight3 ("FBM Weight 3", Float) = 0.125
        _FBM_Weight4 ("FBM Weight 4", Float) = 0.0625
        _FBM_Weight5 ("FBM Weight 5", Float) = 0.015625
        _TimeSpeed ("Time Speed", Float) = 1.0
        _Brightness ("Brightness", Float) = 1.0
        _Rotation ("Rotation Angle (degrees)", Range(0,360)) = 0
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
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float _FBM_Scale;
            float _FBM_Weight1;
            float _FBM_Weight2;
            float _FBM_Weight3;
            float _FBM_Weight4;
            float _FBM_Weight5;
            float _TimeSpeed;
            float _Brightness;
            float _Rotation;

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

            float rand(float2 n)
            {
                return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
            }

            float noise(float2 p)
            {
                float2 ip = floor(p);
                float2 u = frac(p);
                u = u * u * (3.0 - 2.0 * u);

                float res = lerp(
                    lerp(rand(ip), rand(ip + float2(1.0, 0.0)), u.x),
                    lerp(rand(ip + float2(0.0, 1.0)), rand(ip + float2(1.0, 1.0)), u.x),
                    u.y);
                return res * res;
            }

            float2x2 rotationMatrix(float angle)
            {
                float rad = radians(angle);
                float c = cos(rad);
                float s = sin(rad);
                return float2x2(c, -s, s, c);
            }

            float fbm(float2 p)
            {
                float2x2 mtx = rotationMatrix(_Rotation);

                float f = 0.0;
                f += _FBM_Weight1 * noise(p + _Time.y * _TimeSpeed);
                p = mul(p, mtx) * _FBM_Scale;
                f += _FBM_Weight2 * noise(p);
                p = mul(p, mtx) * _FBM_Scale;
                f += _FBM_Weight3 * noise(p);
                p = mul(p, mtx) * _FBM_Scale;
                f += _FBM_Weight4 * noise(p);
                p = mul(p, mtx) * _FBM_Scale;
                f += _FBM_Weight5 * noise(p + sin(_Time.y * _TimeSpeed));
                return f;
            }

            float pattern(float2 p)
            {
                return fbm(p + fbm(p + fbm(p)));
            }

            float colormap_red(float x)
            {
                if (x < 0.0) return 54.0 / 255.0;
                else if (x < (20049.0 / 82979.0)) return (829.79 * x + 54.51) / 255.0;
                else return 1.0;
            }

            float colormap_green(float x)
            {
                if (x < (20049.0 / 82979.0)) return 0.0;
                else if (x < (327013.0 / 810990.0))
                    return ((8546482679670.0 / 10875673217.0) * x - (2064961390770.0 / 10875673217.0)) / 255.0;
                else if (x <= 1.0)
                    return ((103806720.0 / 483977.0) * x + (19607415.0 / 483977.0)) / 255.0;
                else return 1.0;
            }

            float colormap_blue(float x)
            {
                if (x < 0.0) return 54.0 / 255.0;
                else if (x < (7249.0 / 82979.0)) return (829.79 * x + 54.51) / 255.0;
                else if (x < (20049.0 / 82979.0)) return 127.0 / 255.0;
                else if (x < (327013.0 / 810990.0))
                    return (792.0224934136139 * x - 64.36479073560233) / 255.0;
                else return 1.0;
            }

            float4 colormap(float x)
            {
                return float4(
                    colormap_red(x),
                    colormap_green(x),
                    colormap_blue(x),
                    1.0
                );
            }

            half4 Frag(Varyings IN) : SV_Target
            {
                float2 fragCoord = (IN.screenPos.xy / IN.screenPos.w) * _ScreenParams.xy;
                float2 uv = fragCoord / _ScreenParams.x;

                float shade = pattern(uv);
                float4 color = colormap(shade) * _Brightness;

                return half4(color.rgb, shade);
            }

            ENDHLSL
        }
    }
}
