Shader "Custom/GyroFractalField"
{
    Properties
    {
        _SineAmp ("Sine Amplitude", Float) = 0.2
        _Freq1 ("Frequency 1", Float) = 10.0
        _Freq2 ("Frequency 2", Float) = 8.0
        _Scale ("Raymarch Step Scale", Float) = 0.02
        _MaxSteps ("Max Iterations", Range(1, 200)) = 90
        _StopThreshold ("Stop Threshold", Float) = 0.001
        _MaxDistance ("Max Raymarch Distance", Float) = 2.0
        _ColorIntensity ("Color Intensity", Float) = 1.0
    }

    HLSLINCLUDE
    #pragma target 4.5

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    // Exposed properties
    float _SineAmp;
    float _Freq1;
    float _Freq2;
    float _Scale;
    int _MaxSteps;
    float _StopThreshold;
    float _MaxDistance;
    float _ColorIntensity;

    float SS(float a, float b, float c)
    {
        return smoothstep(a - b, a + b, c);
    }

    float gyr(float3 p)
    {
        return dot(sin(p), cos(float3(p.z, p.x, p.y)));
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

    float map(float3 p)
    {
        return (1.0 + _SineAmp * sin(p.y * 600.0)) *
               gyr(p * _Freq1 + 0.8 * gyr(p * _Freq2)) *
               (1.0 + sin(_Time.y + length(p.xy) * 10.0)) +
               0.3 * sin(_Time.y * 0.15 + p.z * 5.0 + p.y) *
               (2.0 + gyr(p * (sin(_Time.y * 0.2 + p.z * 3.0) * 350.0 + 250.0)));
    }

    float3 norm(float3 p)
    {
        float m = map(p);
        float dz = p.z;
        float2 d = float2(0.06 + 0.06 * sin(dz), 0.0);

        float3 n;
        n.x = map(p) - map(p - float3(d.x, d.y, d.y));
        n.y = map(p) - map(p - float3(d.y, d.x, d.y));
        n.z = map(p) - map(p - float3(d.y, d.y, d.x));
        return n;
    }

    float4 Frag(Varyings IN) : SV_Target
    {
        float2 fragCoord = IN.screenPos.xy / IN.screenPos.w * _ScreenParams.xy;

        float2 uv = fragCoord / _ScreenParams.xy;
        float2 uvc = (fragCoord - _ScreenParams.xy * 0.5) / _ScreenParams.y;

        float d = 0.0;
        float dd = 1.0;
        float3 p = float3(0.0, 0.0, _Time.y / 4.0);
        float3 rd = normalize(float3(uvc.xy, 1.0));

        for (int i = 0; i < _MaxSteps && dd > _StopThreshold && d < _MaxDistance; ++i)
        {
            d += dd;
            p += rd * dd;
            dd = map(p) * _Scale;
        }

        float3 n = norm(p);
        float bw = n.x + n.y;
        bw *= SS(0.9, 0.15, 1.0 / d);
        float3 color = bw * _ColorIntensity;

        return float4(color, 1.0);
    }

    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            Name "GyrPass"
            Tags { "LightMode" = "UniversalForward" }
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
