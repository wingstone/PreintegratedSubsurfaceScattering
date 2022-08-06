Shader "Human/ProfileDisplay"
{
    Properties
    {
        _Range("Prfile Range", Range(1,100)) = 10
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

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
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
                    
            float Gaussian (float v, float r)
            {
                return 1.0/sqrt(2.0*UNITY_PI*v)*exp(-(r*r)/(2*v));
            }

            float3 RadialScatter(float r)
            {
                return Gaussian(0.0064*1.414, r)*float3(0.233,0.455,0.649)+
                Gaussian(0.0484*1.414, r)*float3(0.100,0.336,0.344)+
                Gaussian(0.1870*1.414, r)*float3(0.118,0.198,0.000)+
                Gaussian(0.5670*1.414, r)*float3(0.113,0.007,0.007)+
                Gaussian(1.9900*1.414, r)*float3(0.358,0.004,0.000)+
                Gaussian(7.4100*1.414, r)*float3(0.078,0.000,0.000);
            }

            float _Range;

            fixed4 frag (v2f i) : SV_Target
            {
                float4 col = 0;
                
                col.rgb = RadialScatter(length(i.uv*2-1)*_Range);

                col.a = 1;
                return col;
            }
            ENDCG
        }
    }
}
