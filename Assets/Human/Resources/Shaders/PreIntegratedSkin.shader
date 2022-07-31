Shader "Human/PreIntegratedShader(no specular)"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _NormalTex ("Normal Texture", 2D) = "bump" {}
        _OcclusionTex ("Occlusion Texture", 2D) = "white" {}
        _PreIntegratedSkinTex ("PreIntegrated Skin Texture", 2D) = "black" {}
        _PreIntegratedShadowTex ("PreIntegrated Shadow Texture", 2D) = "black" {}
        _SHProfile ("SH Profile", 2D) = "black" {}
        _CurvatureScale("Curvature Scale", Range(0.1, 10)) = 1
        
        //当前无法从unity获取半影宽度，因此这里以参数数值手动匹配当前环境
        _invPenumbraWidth("Penumbra Width", Range(0.0001, 1)) = 0.117
    }
    SubShader
    {
        Tags { "LightMode"="ForwardBase" "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"        //常用函数，宏，结构体
            #include "Lighting.cginc"		//光源相关变量
            #include "AutoLight.cginc"		//光照，阴影相关宏，函数
            #include "SH_Utils.cginc"

            struct appdata
            {
                float4 color : COLOR;
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 tangent : TEXCOORD2;
                float3 binormal : TEXCOORD3;
                float3 normal : TEXCOORD4;
                UNITY_LIGHTING_COORDS(5, 6)
                float4 pos : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _NormalTex;
            sampler2D _OcclusionTex;
            sampler2D _PreIntegratedSkinTex;
            sampler2D _PreIntegratedShadowTex;
            sampler2D _SHProfile;
            float _CurvatureScale;
            float _invPenumbraWidth;
            
			float4 c0;
			float4 c1;
			float4 c2;
			float4 c3;
			float4 c4;
			float4 c5;
			float4 c6;
			float4 c7;
			float4 c8;

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex).xyz;
                o.uv = v.uv;
                o.color = v.color;

                o.normal = UnityObjectToWorldNormal(v.normal);
                o.tangent = UnityObjectToWorldDir(v.tangent.xyz);

                float3x3 tangentToWorld = CreateTangentToWorldPerVertex(o.normal, o.tangent, v.tangent.w);
                o.tangent = tangentToWorld[0];
                o.binormal = tangentToWorld[1];
                o.normal = tangentToWorld[2];

                UNITY_TRANSFER_LIGHTING(o, v.uv);
                return o;
            }

            float GSquare(float x)
            {
                return x*x;
            }
            
            float CurvatureFromLight(
            float3 tangent,
            float3 bitangent,
            float3 curvTensor,
            float3 lightDir)
            {
                // Project light vector into tangent plane
                
                float2 lightDirProj = float2(dot(lightDir, tangent), dot(lightDir, bitangent));
                
                // NOTE (jasminp) We should normalize lightDirProj here in order to correctly
                //    calculate curvature in the light direction projected to the tangent plane.
                //    However, it makes no perceptible difference, since the skin LUT does not vary
                //    much with curvature when N.L is large.
                
                float curvature = curvTensor.x * GSquare(lightDirProj.x) +
                2.0f * curvTensor.y * lightDirProj.x * lightDirProj.y +
                curvTensor.z * GSquare(lightDirProj.y);
                
                return curvature;
            }

            float3 SkinNol(float old_nol, float curvature)
            {
                return tex2D(_PreIntegratedSkinTex, float2(old_nol*0.5+0.5, curvature)).rgb;
            }

            float3 SkinShadow(float atten, float inv_width)
            {
                return tex2D(_PreIntegratedShadowTex, float2(atten, inv_width)).rgb;
            }

            float ZHRed0Approx(float cur, float cur2, float cur3, float cur4) 
            {
                return 1.04297 - 0.0395131*cur + 0.854299*cur2 - 0.92605*cur3 + 0.308906*cur4; 
            }
            float ZHRed1Approx(float cur, float cur2, float cur3, float cur4) 
            {
                return 0.614122 + 0.0177265*cur - 0.283127*cur2 + 0.254445*cur3 - 0.0657637*cur4; 
            }
            float ZHRed2Approx(float cur, float cur2, float cur3, float cur4) 
            {
                return 0.105369 - 0.000255739*cur - 0.523248*cur2 + 0.634608*cur3 -0.234107*cur4;
            } 
            #define ZHGreen0Approx 1.05
            #define ZHGreen1Approx 0.611
            #define ZHGreen2Approx 0.098 
            #define ZHBlue0Approx 1.045
            #define ZHBluelApprox 0.6135 
            #define ZHBlue2Approx 0.1 

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 albedo = tex2D(_MainTex, i.uv);
                float3 diffcolor = unity_ColorSpaceDielectricSpec.a*albedo;
                float3 speccolor = unity_ColorSpaceDielectricSpec.rgb;
                float3 texNormal = UnpackNormal(tex2D(_NormalTex, i.uv));
                float occlusion = tex2D(_OcclusionTex, i.uv).r;
                
                float3 N = normalize(texNormal.x*i.tangent + texNormal.y*i.binormal + texNormal.z*i.normal);
                float3 L = _WorldSpaceLightPos0.xyz;
                float old_nol = dot(N, L);

                float3 col = 0;

                //shadow
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                float3 lightcolor = _LightColor0.rgb;
                
                //diffuse
                // float meanCurv = i.color.a*_CurvatureScale;
                float dirCurv = CurvatureFromLight(i.tangent, i.binormal, i.color.rgb, L)*_CurvatureScale;
                float3 diffuse = lightcolor * SkinNol(old_nol, dirCurv) * SkinShadow(atten, _invPenumbraWidth);
                col += diffcolor * diffuse;

                //ambient
                float3 zh0 = tex2Dlod(_SHProfile,float4(dirCurv, 0.166666, 0, 0));
                float3 zh1 = tex2Dlod(_SHProfile,float4(dirCurv, 0.5, 0, 0));
                float3 zh2 = tex2Dlod(_SHProfile,float4(dirCurv, 0.833333, 0, 0));
                // float cur = curvature;
                // float cur2 = cur * cur;
                // float cur3 = cur2*cur;
                // float cur4 = cur2*cur2;
                // float3 zh0 = float3(ZHRed0Approx(cur, cur2,cur3,cur4), ZHGreen0Approx, ZHBlue0Approx);
                // float3 zh1 = float3(ZHRed1Approx(cur, cur2,cur3,cur4), ZHGreen1Approx, ZHBluelApprox);
                // float3 zh2 = float3(ZHRed2Approx(cur, cur2,cur3,cur4), ZHGreen2Approx, ZHBlue2Approx);
                float3 ambient = zh0 * c0 * Y0(N) + 
                    zh1 * (c1 * Y1(N) + c2 * Y2(N) + c3 * Y3(N)) + 
                    zh2 * (c4 * Y4(N) + c5 * Y5(N) + c6 * Y6(N) + c7 * Y7(N) + c8 * Y8(N));
                // ambient *= UNITY_INV_PI; // premultiply in zh
                col += diffcolor * ambient;

                return float4(col, 1);
            }
            ENDCG
        }

        Pass
        {
            //copy from unity standard shadowcaster
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------

            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _SPECGLOSSMAP
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _PARALLAXMAP
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertShadowCaster
            #pragma fragment fragShadowCaster

            #include "UnityStandardShadow.cginc"

            ENDCG
        }
    }
}
