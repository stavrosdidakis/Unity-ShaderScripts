Shader "Custom/ControlledShaderGraph"
{
    Properties
    {
        [Header(Transform)]
        _Scale("Effect Scale", Range(0.1, 5)) = 1.0
        _Offset("Effect Offset", Vector) = (0, 0, 0, 0)
        _Rotation("Base Rotation", Float) = 0.0
        
        [Header(Animation)]
        _Speed("Animation Speed", Range(0, 5)) = 1.0
        _TimeScale("Time Scaling", Float) = 1.0
        _Iterations("Effect Iterations", Range(1, 30)) = 19
        
        [Header(Color)]
        _BaseColor1("Primary Color", Color) = (1, 0.5, 0.3, 1)
        _BaseColor2("Secondary Color", Color) = (0.3, 0.5, 1, 1)
        _ColorSpeed("Color Cycle Speed", Range(0, 2)) = 0.5
        _Contrast("Contrast", Range(0.5, 3)) = 1.2
        _Brightness("Brightness", Range(0, 2)) = 1.0
        
        [Header(Effect)]
        _Distortion("Distortion Amount", Range(0, 1)) = 0.5
        _WaveIntensity("Wave Intensity", Range(0, 5)) = 1.5
        _Detail("Detail Level", Range(0.1, 2)) = 1.0
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float _Scale;
                float2 _Offset;
                float _Rotation;
                float _Speed;
                float _TimeScale;
                int _Iterations;
                float4 _BaseColor1;
                float4 _BaseColor2;
                float _ColorSpeed;
                float _Contrast;
                float _Brightness;
                float _Distortion;
                float _WaveIntensity;
                float _Detail;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }
            
            float3 palette(float t, float3 a, float3 b, float3 c, float3 d)
            {
                return a + b * cos(6.28318 * (c * t + d));
            }
            
            float4 frag(Varyings IN) : SV_Target
            {
                // Normalized coordinates with all transformations
                float aspect = _ScreenParams.x / _ScreenParams.y;
                float2 u = (IN.uv - 0.5 - _Offset) * float2(aspect, 1.0) * 2.0 * _Scale;
                
                // Apply base rotation
                float sinRot, cosRot;
                sincos(_Rotation, sinRot, cosRot);
                float2x2 rotMat = float2x2(cosRot, -sinRot, sinRot, cosRot);
                u = mul(rotMat, u);
                
                float4 z = float4(1, 2, 3, 0);
                float4 o = z;
                
                float a = 0.5;
                float t = _Time.y * _Speed * _TimeScale;
                int i = 0;
                
                [loop]
                for (i = 0; i < _Iterations; i++)
                {
                    t += 1.0 * _TimeScale;
                    float2 v = cos(t - 7.0 * u * pow(a += 0.03 * _Distortion, i)) - 5.0 * u;
                    
                    // Create dynamic rotation matrix
                    float angle1 = i + 0.02 * t - 0.0;
                    float angle2 = i + 0.02 * t - 11.0;
                    float angle3 = i + 0.02 * t - 33.0;
                    
                    float2x2 dynRotMat = float2x2(
                        cos(angle1), cos(angle2),
                        cos(angle3), cos(angle1)
                    );
                    
                    u = mul(u, dynRotMat);
                    
                    // Apply controlled modifications
                    u += tanh(40.0 * _WaveIntensity * dot(u, u) * cos(100.0 * _Detail * u.yx + t)) / 200.0
                       + 0.2 * a * u
                       + cos(4.0 / exp(dot(o, o) / 100.0) + t) / 300.0;
                    
                    // Accumulate effect
                    o += (1.0 + cos(z + t)) 
                       / length((1.0 + i * dot(v, v)) 
                              * sin(_WaveIntensity * u / (0.5 - dot(u, u)) - 9.0 * u.yx + t));
                }
                
                // Final color processing
                o = 25.6 / (min(o, 13.0) + 164.0 / o) - dot(u, u) / 250.0;
                
                // Color mixing
                float3 colorA = _BaseColor1.rgb;
                float3 colorB = _BaseColor2.rgb;
                float colorT = 0.5 + 0.5 * sin(_Time.y * _ColorSpeed);
                float3 finalColor = lerp(colorA, colorB, colorT) * o.rgb;
                
                // Post-processing
                finalColor = pow(abs(finalColor), _Contrast) * _Brightness;
                finalColor = saturate(finalColor);
                
                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}