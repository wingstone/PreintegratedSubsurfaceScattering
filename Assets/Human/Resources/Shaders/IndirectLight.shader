Shader "Human/IndirectLight"
{
    Properties
    {
        [IntRange]_Mode("sh or gi", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "SH_Utils.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float3 normal : NORMAL;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }
                
			float4 c0;
			float4 c1;
			float4 c2;
			float4 c3;
			float4 c4;
			float4 c5;
			float4 c6;
			float4 c7;
			float4 c8;
            int _Mode;

            fixed4 frag (v2f i) : SV_Target
            {
                float3 n = normalize(i.normal);
                float4 col = 0;
                float3 cosZH = float3(3.141593, 2.094395, 0.785398);
                
                if (_Mode == 0)
                    col = c0 * Y0(n) + c1 * Y1(n) + c2 * Y2(n) + c3 * Y3(n) + c4 * Y4(n) + c5 * Y5(n) + c6 * Y6(n) + c7 * Y7(n) + c8 * Y8(n);

                if (_Mode == 1)
                {
                    col = cosZH.x * c0 * Y0(n) + 
                        cosZH.y * (c1 * Y1(n) + c2 * Y2(n) + c3 * Y3(n)) + 
                        cosZH.z * (c4 * Y4(n) + c5 * Y5(n) + c6 * Y6(n) + c7 * Y7(n) + c8 * Y8(n));
                    col *= UNITY_INV_PI;
                }   

                col.a = 1;
                return col;
            }
            ENDCG
        }
    }
}
