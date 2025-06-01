Shader "Custom/IonizeAdvanced"
{
    Properties
    {
        [Header(Animation)]
        _Speed ("Animation Speed", Range(0.1, 5)) = 1.0
        _Turbulence ("Turbulence Amount", Range(0, 2)) = 0.5
        
        [Header(Raymarching)]
        _Iterations ("Max Steps", Range(10, 300)) = 100
        _StepSize ("Step Size", Range(0.01, 1)) = 0.5
        _MaxDistance ("Max Distance", Range(5, 50)) = 20
        
        [Header(Structure)]
        _Size ("Structure Size", Range(0.1, 5)) = 1.0
        _Thickness ("Structure Thickness", Range(0.01, 0.5)) = 0.05
        _BoundarySize ("Boundary Size", Range(1, 10)) = 6.0
        
        [Header(Camera)]
        _Zoom ("Zoom", Range(0.1, 5)) = 1.0
        _CameraDistance ("Camera Distance", Range(1, 20)) = 9.0
        
        [Header(Colors)]
        _Color1 ("Color 1", Color) = (1,0.5,0.5,1)
        _Color2 ("Color 2", Color) = (0.5,1,0.5,1)
        _Color3 ("Color 3", Color) = (0.5,0.5,1,1)
        _GlowIntensity ("Glow Intensity", Range(0.1, 10)) = 1.0
    }
    
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
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
            
            CBUFFER_START(UnityPerMaterial)
                float _Speed;
                float _Turbulence;
                int _Iterations;
                float _StepSize;
                float _MaxDistance;
                float _Size;
                float _Thickness;
                float _BoundarySize;
                float _Zoom;
                float _CameraDistance;
                half4 _Color1;
                half4 _Color2;
                half4 _Color3;
                float _GlowIntensity;
            CBUFFER_END
            
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                // Center UVs, adjust for aspect ratio, and apply zoom
                float2 uv = (IN.uv * 2.0 - 1.0) * _Zoom;
                uv.x *= _ScreenParams.x / _ScreenParams.y;
                OUT.uv = uv;
                return OUT;
            }
            
            // Gyroid distance function with size control
            float sdGyroid(float3 p, float scale)
            {
                p *= scale;
                return abs(dot(cos(p), sin(p.yzx))) - _Thickness;
            }
            
            half4 frag(Varyings IN) : SV_Target
            {
                float time = _Time.y * _Speed;
                float2 uv = IN.uv;
                
                // Raymarching setup with camera distance control
                float3 rayOrigin = float3(uv, -_CameraDistance);
                float3 rayDir = normalize(float3(0, 0, 1));
                
                half4 color = half4(0, 0, 0, 1);
                float t = 0; // Ray distance
                float glow = 0;
                
                [loop]
                for (int i = 0; i < _Iterations && t < _MaxDistance; i++)
                {
                    float3 p = rayOrigin + rayDir * t;
                    
                    // Apply turbulence with controllable amount
                    float3 pDistorted = p;
                    for (float j = 1.0; j < 5.0; j *= 2.0)
                    {
                        pDistorted += _Turbulence * 0.5 * sin(pDistorted.yzx * j + time) / j;
                    }
                    
                    // Gyroid distance with size control
                    float dist = sdGyroid(pDistorted, _Size);
                    
                    // Adjustable boundary
                    float sphereDist = length(p) - _BoundarySize;
                    dist = max(dist, -sphereDist);
                    
                    if (dist < 0.001 * _Size) break;
                    
                    // Accumulate glow with intensity control
                    glow += _GlowIntensity * 0.1 / (1.0 + dist * 20.0);
                    
                    t += dist * _StepSize;
                }
                
                // Color mixing based on position and time
                float3 colorMix = 0.5 + 0.5 * cos(time * 0.5 + float3(0, 2, 4) + uv.x * 3.0);
                color.rgb = lerp(lerp(_Color1.rgb, _Color2.rgb, colorMix.x), 
                             _Color3.rgb, colorMix.y) * glow;
                
                return color;
            }
            ENDHLSL
        }
    }
}