Shader "Custom/NoiseRings"
{
    Properties
    {
        _RingCount ("Number of Rings", Range(1, 32)) = 16
        _RingRadius ("Ring Radius", Float) = 0.2
        _NoiseStrength ("Noise Strength", Float) = 0.12
        _GlowIntensity ("Glow Intensity", Float) = 0.0008
        _TimeScale ("Animation Speed", Float) = 0.3
        _Offset ("Center Offset", Vector) = (-0.4, 0.0, 0.0, 0.0)
    }

    HLSLINCLUDE
    #pragma target 4.5

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    // Constants
    #define PI 3.14159
    #define TAU (2.0 * PI)

    #define F3 0.3333333
    #define G3 0.1666667

    // Exposed parameters
    int _RingCount;
    float _RingRadius;
    float _NoiseStrength;
    float _GlowIntensity;
    float _TimeScale;
    float4 _Offset;

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

    float3 random3(float3 c)
    {
        float j = 4096.0 * sin(dot(c, float3(17.0, 59.4, 15.0)));
        float3 r;
        r.z = frac(512.0 * j);
        j *= 0.125;
        r.x = frac(512.0 * j);
        j *= 0.125;
        r.y = frac(512.0 * j);
        return r - 0.5;
    }

    float simplex3d(float3 p)
    {
        float s = (p.x + p.y + p.z) * F3;
        float3 s_vec = floor(p + s);

        float t = (s_vec.x + s_vec.y + s_vec.z) * G3;
        float3 x = p - s_vec + t;

        float3 x_yzx = float3(x.y, x.z, x.x);
        float3 e = step(float3(0.0, 0.0, 0.0), x - x_yzx);
        float3 e_zxy = float3(e.z, e.x, e.y);
        float3 i1 = e * (1.0 - e_zxy);
        float3 i2 = 1.0 - e_zxy * (1.0 - e);

        float3 x1 = x - i1 + float3(G3, G3, G3);
        float3 x2 = x - i2 + float3(2.0 * G3, 2.0 * G3, 2.0 * G3);
        float3 x3 = x - float3(1.0, 1.0, 1.0) + float3(3.0 * G3, 3.0 * G3, 3.0 * G3);

        float4 w, d;
        w.x = dot(x, x);
        w.y = dot(x1, x1);
        w.z = dot(x2, x2);
        w.w = dot(x3, x3);

        w = max(0.6 - w, 0.0);
        d.x = dot(random3(s_vec), x);
        d.y = dot(random3(s_vec + i1), x1);
        d.z = dot(random3(s_vec + i2), x2);
        d.w = dot(random3(s_vec + float3(1.0, 1.0, 1.0)), x3);

        w *= w;
        w *= w;
        d *= w;

        return dot(d, float4(52.0, 52.0, 52.0, 52.0));
    }

    float4 Frag(Varyings IN) : SV_Target
    {
        float2 fragCoord = IN.screenPos.xy / IN.screenPos.w * _ScreenParams.xy;

        // Normalize coordinates
        float2 uv = (fragCoord - 0.5 * _ScreenParams.xy) / _ScreenParams.y;
        float3 col = float3(0.0, 0.0, 0.0);
        float tt = frac(_TimeScale * _Time.y);

        for (int i = 1; i <= _RingCount; i++)
        {
            float fi = (float)i;
            float a = atan2(uv.y, uv.x) + PI;

            float rad = _RingRadius;

            float sin_a = sin(a);
            float cos_a = cos(a);

            float3 simplex_input = float3(sin_a, cos_a, fi);
            float simplex_value = simplex3d(simplex_input);

            float nx_input_x = (10.0 * fi) + rad * sin(TAU * tt - 5.0 * a);
            float nx_input_y = (10.0 * fi) + rad * cos(TAU * tt - 5.0 * a);
            float nx_input_z = simplex_value;

            float nx = _NoiseStrength * simplex3d(float3(nx_input_x, nx_input_y, nx_input_z));

            float ny_input_x = (2.0 * fi) + rad * sin(TAU * tt - 5.0 * a);
            float ny_input_y = (2.0 * fi) + rad * cos(TAU * tt - 5.0 * a);
            float ny_input_z = simplex_value;

            float ny = _NoiseStrength * simplex3d(float3(ny_input_x, ny_input_y, ny_input_z));

            float d = length(uv - _Offset.xy);

            float2 offset = float2(nx * d * d, ny * d * d);
            float circSDF = abs(length(uv - offset) - 0.37);

            col += d * _GlowIntensity / abs(circSDF);
        }

        return float4(col, 1.0);
    }

    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" }
        Pass
        {
            Name "SimplexNoiseRingsPass"
            Tags { "LightMode" = "UniversalForward" }
            ZTest Always Cull Off ZWrite Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
