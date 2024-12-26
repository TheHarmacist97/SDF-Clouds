Shader "Unlit/SDFSphere"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        MAX_STEPS("Maximum Steps", int) = 255
        MAX_DIST("Maximum Distance", float) = 10.0
        SURF_DIST("Surface Threshold", float) = 0.1
        _Exposure("Exposure", float ) = 0.1
        _SphereDesc("Sphere", Vector) = (0,1,6,1)
        _LightPos("Light Position", Vector) = (0, 5, 6)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1;
            };

            uniform int MAX_STEPS;
            uniform float MAX_DIST;
            uniform float SURF_DIST;
            uniform float _Exposure;
            uniform float4 _SphereDesc;
            uniform float3 _LightPos;
            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float GetSafeDistance(float3 currentPoint)
            {
                //described as (x,y,z)=pos and w = radius
                float sphereDist = length(currentPoint - _SphereDesc.xyz) - _SphereDesc.w;
                float planeDist = currentPoint.y;
                float safeDist = min(sphereDist, planeDist);
                return safeDist;
            }

            float RayMarch(float3 origin, float3 dir, float3 objPos)
            {
                float distanceMarched = 0;

                for (int i = 0; i < MAX_STEPS; i++)
                {
                    //distance safely marched at this iteration
                    //in the ray direction from the origin
                    float3 currentPoint = origin + dir * distanceMarched + objPos;
                    float safeDistFromCurrentPoint = GetSafeDistance(currentPoint);
                    distanceMarched += safeDistFromCurrentPoint;
                    if (distanceMarched > MAX_DIST || safeDistFromCurrentPoint < SURF_DIST)
                    {
                        break;
                    }
                }

                return distanceMarched;
            }

            float3 GetNormalOfSphere(float3 atPoint)
            {
                return normalize(atPoint - _SphereDesc.xyz);
            }

            float GetDiffuseLight(float3 atPoint)
            {
                float3 lightDir = normalize(_LightPos - atPoint);
                float lightRecieved = dot(GetNormalOfSphere(atPoint), lightDir);
                return lightRecieved;
            }

            float GetSpecularLight(float3 atPoint, float3 _cameraDir)
            {
                float3 lightDir = -normalize(_LightPos - atPoint);
                float specular_light = saturate(max(dot(lightDir, _cameraDir), 0));
                specular_light = pow(specular_light, 20);
                specular_light *= 2;
                return specular_light;
            }
            fixed4 frag(v2f i) : SV_Target
            {
                // sample the texture
                float2 uv = i.uv * 2.0 - 1.0;
                float3 rayOrigin = float3(0, 1, 0);
                float3 rayDirection = normalize(float3(uv.x, uv.y, 1));
                float rayMarchedDist = RayMarch(rayOrigin, rayDirection, i.worldPos);
                float3 illuminatedPoint = rayOrigin + rayDirection * rayMarchedDist;
                float3 circularOffset = float3(sin(_Time.y), 0, cos(_Time.y));
                _LightPos += circularOffset;
                float diffuse = GetDiffuseLight(illuminatedPoint);
                float specular = GetSpecularLight(illuminatedPoint, rayDirection);
                float phong = diffuse + specular; 
                phong *= _Exposure;
                float4 col = phong;
                return col;
            }
            ENDCG
        }
    }
}