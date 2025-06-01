Shader "Custom/FractalShader"
{
    Properties
    {
        _MaxIterations ("Max Iterations", Range(1, 100)) = 50
        _InnerIterations ("Inner Loop Iterations", Range(1, 20)) = 5
        _RotationSpeed ("Rotation Speed", Float) = 1.0
        _RotationIntensity ("Rotation Intensity", Float) = 1.0
        _Brightness ("Brightness", Float) = 1.0
        _DistanceScale ("Distance Scale", Float) = 75.0
        _ColorIntensity ("Color Intensity", Float) = 0.07
    }

    HLSLINCLUDE
    #pragma target 4.5

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    #define PI 3.14159265359

    float _MaxIterations;
    float _InnerIterations;
    float _RotationSpeed;
    float _RotationIntensity;
    float _Brightness;
    float _DistanceScale;
    float _ColorIntensity;

    float2x2 rot(float x)
    {
        float4 angle = x + float4(0.0, 11.0, 33.0, 0.0);
        float4 c = cos(angle);
        return float2x2(c.x, c.z,
                        c.y, c.w);
    }

    float3 H(float3 h)
    {
        return cos(0.007 * float3(2.0 * h.x, h.y, 5.0 * h.z));
    }

    struct Attributes
    {
        float4 positionOS : POSITION;
    };

    struct Varyings
    {
        float4 positionHCS : SV_POSITION;
        float4 screenPos : TEXCOORD0;
    };

    Varyings Vert(Attributes IN)
    {
        Varyings OUT;
        OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
        OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
        return OUT;
    }

    float4 Frag(Varyings IN) : SV_Target
    {
        float2 fragCoord = IN.screenPos.xy / IN.screenPos.w * _ScreenParams.xy;

        float4 O = float4(0.0, 0.0, 0.0, 0.0);
        float3 c = float3(0.0, 0.0, 0.0);

        float2 uv = fragCoord - 0.5 * _ScreenParams.xy;
        float4 rd = normalize(float4(uv.xy, 0.8 * _ScreenParams.y, _ScreenParams.y / 2.0));

        float dotp, totdist = 0.0, tt = _Time.y * _RotationSpeed, t = 0.0;

        for (int i = 0; i < _MaxIterations; i++)
        {
            float fi = (float)i;

            float4 p = rd * totdist * 10.0;

            p.z += -1.5;
            p.x += 2.5;
            p.y += -2.0;

            p.xz = mul(p.xz, rot(1.2 * _RotationIntensity * (1.0 + 0.4 * sin(tt / 3.0))));
            p.xy = mul(p.xy, rot(-0.6 * _RotationIntensity * (1.0 + 0.2 * sin(tt / 3.0))));
            p.yz = mul(p.yz, rot(tt / 7.0));

            float4 w = float4(0.0, 0.0, 0.0, 0.0);
            float4 dz = float4(0.0, 0.0, 0.0, 0.0);
            float4 z;

            for (int j = 0; j < _InnerIterations; j++)
            {
                float ex = exp(w.x);
                float cy = cos(w.y);
                float sy = sin(w.y);
                float cz = cos(w.z);
                float sz = sin(w.z);
                float cw = cos(w.w);
                float sw = sin(w.w);

                z = float4(
                    ex * (cy * cz * cw - sy * sz * sw),
                    ex * (sy * cz * cw + cy * sz * sw),
                    ex * (cy * sz * cw - sy * cz * sw),
                    ex * (sy * sz * cw + cy * cz * sw)
                );

                dz = float4(
                    z.x * dz.x - z.y * dz.y - z.z * dz.z - z.w * dz.w,
                    z.x * dz.y + z.y * dz.x + z.z * dz.w - z.w * dz.z,
                    z.x * dz.z - z.y * dz.w + z.z * dz.x + z.w * dz.y,
                    z.x * dz.w + z.y * dz.z - z.z * dz.y + z.w * dz.x
                );

                dz.x += 20.3;

                dotp = max(1.0 / dot(z, z), 0.1);
                dz *= dotp;
                w = z * dotp + p;
            }

            float ddz = clamp(dot(dz, dz), 1e-3, 1e6);
            float ddw = clamp(dot(w, w), 1e-3, 1e4);

            float dist = sqrt(sqrt(ddw / ddz)) * log(ddw);
            float stepsize = dist / _DistanceScale;
            totdist += stepsize;

            c += _ColorIntensity * H(clamp(dz.xyz, -1e-3, 1e3)) * exp(-fi * fi * dist * dist * 0.05);
        }

        c = _Brightness * (1.0 - exp(-c * c));
        O = float4(c, 1.0);
        return O;
    }

    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            Name "FractalPass"
            Tags { "LightMode" = "UniversalForward" }
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
