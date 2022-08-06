Shader "Human/LookupTexture"
{
    Properties
    {
        _Use_Linear_Profile("use linear profile", Int) = 0
        _Linear_Profile("linear profile", 2D) = "gray" {}
        _SkinLut("skin lut", 2D) = "gray" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        CGINCLUDE
        #include "UnityCG.cginc"        //常用函数，宏，结构体
        #include "SH_Utils.cginc"
        
        // 50mm范围lut
        #define linearProfileLength 50
        // 3倍方差来代替
        #define PROFILE_WIDTH 8.166

        int _Use_Linear_Profile;
        sampler2D _Linear_Profile;
        sampler2D _SkinLut;
        
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

        float3 LinearSactterLut(float r)
        {
            return tex2D(_Linear_Profile, float2(r/linearProfileLength, 0.5)).rgb;
        }

        // float newPenumbra(float pos, float penumbraWidth)
        // {
        //     return saturate(pos*2-1);
        // }
        
        // 散射范围为PROFILE_WIDTH
        float newPenumbra(float pos, float penumbraWidth)
        {
            return saturate((pos*penumbraWidth -PROFILE_WIDTH) / (penumbraWidth -PROFILE_WIDTH));
        }

        //penumbraLocation为归一化后的在半影区域内的位置；
        // 这里的反函数是有些问题的，unity使用的是tent filter，并不是box filter
        float3 integrateShadowScattering(float penumbraLocation, float penumbraWidth)
        {
            float3 totalWeights = 0;
            float3 totalLight = 0;
            float inc = 0.001;

            penumbraWidth = max(penumbraWidth, PROFILE_WIDTH + 1e-5);
            
            float a = -PROFILE_WIDTH;
            while(a <= PROFILE_WIDTH)   //理论上积分区域应从负无穷到正无穷，这里以3倍方差来代替
            {
                float light = newPenumbra(penumbraLocation+a/penumbraWidth, penumbraWidth);
                float sampleDist = abs(a);
                float3 weights = RadialScatter(sampleDist);
                totalWeights += weights;
                totalLight += light*weights;
                a+=inc;
            }

            return totalLight/totalWeights;
        }

        float3 integrateDiffuseScatteringOnRing(float cosTheta , float skinRadius)
        {
            // Angle from lighting direction.
            float theta = acos(cosTheta);
            float3 totalWeights = 0;
            float3 totalLight = 0;
            float a= -UNITY_HALF_PI;   // 正常来说积分范围应该从-pi到pi，不过用Gaussian profile的积分结果有蓝色成分，所以这里仍然采用-pi/2到pi/2;
            float inc = 0.001;

            while(a <= UNITY_HALF_PI)
            {
                float sampleAngle = theta + a;
                float diffuse= saturate(cos(sampleAngle));
                float sampleDist = abs(2.0*skinRadius*sin(a*0.5)); // Distance.

                float3 weights = 0;
                if(_Use_Linear_Profile == 1)
                    weights = LinearSactterLut(sampleDist);
                else
                    weights = RadialScatter(sampleDist);

                // Profile Weight.
                totalWeights += weights;
                totalLight += diffuse*weights;
                a+=inc;
            }
            return totalLight/totalWeights;
        }

        float3 LinearSactter(float r)
        {
            // 理论上积分范围应该从负无穷到正无穷
            float a = -50;
            int count = 50;
            float3 scatter = 0;

            while(a < 50)
            {
                float len = length(float2(r, a));
                scatter += RadialScatter(len);
                a += 0.01;
                count++;
            }
            return scatter/count*100;
        }

        ENDCG

        // 0 shadow lut
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

            float4 frag(v2f i) : SV_Target
            {
                float3 col = 0;
                float penumbraLocation = i.uv.x;
                float penumbraWidth = 1/i.uv.y;
                col = integrateShadowScattering(penumbraLocation, penumbraWidth);
                return float4(col, 1);
            }
            ENDCG
        }

        // pass 1 skin lut
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

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 col = 0;
                float cosTheta = i.uv.x*2-1;
                float skinRadius = clamp(1/i.uv.y, 1e-5, 100);  //限制下半径范围, 单位mm
                col = integrateDiffuseScatteringOnRing(cosTheta, skinRadius);
                return float4(col, 1);
            }
            ENDCG
        }

        // pass 2 linear profile
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

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 col = 0;
                float skinRadius = i.uv.x;
                col = LinearSactter(skinRadius*linearProfileLength);
                return float4(col, 1);
            }
            ENDCG
        }

        // pass 3 SH profile
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

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float3 SkinNol(float nol, float curvature)
            {
                return tex2Dlod(_SkinLut, float4(nol*0.5 + 0.5, curvature, 0, 0)).rgb;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 col = 0;
                float3 integral = 0;
                int count = 0;
                float theta = 0;

                // ZH0
                if (i.uv.y < 0.33333)
                {
                    while(theta < UNITY_PI) //应该从0到pi积分，而不是pi/2
                    {
                        float nol = saturate(cos(theta));
                        float y0 = Y0(float3(0,0,nol));     // zh的计算只跟z有关
                        float sinTheta = sqrt(1 - nol*nol);
                        float3 skinNol = SkinNol(nol, i.uv.x);
                        integral += y0*sinTheta*skinNol;
                        theta += 0.001;
                        count++;
                    }
                    col = integral / count * UNITY_PI * sqrt(UNITY_FOUR_PI)*UNITY_TWO_PI * UNITY_INV_PI;
                }
                else if (i.uv.y < 0.666666)
                {
                    while(theta < UNITY_PI)
                    {
                        float nol = saturate(cos(theta));
                        float y2 = Y2(float3(0,0,nol));
                        float sinTheta = sqrt(1 - nol*nol);
                        float3 skinNol = SkinNol(nol, i.uv.x);
                        integral += y2*sinTheta*skinNol;
                        theta += 0.001;
                        count++;
                    }
                    col = integral / count * UNITY_PI * sqrt(UNITY_FOUR_PI/3)*UNITY_TWO_PI * UNITY_INV_PI;
                }
                else
                {
                    while(theta < UNITY_PI)
                    {
                        float nol = saturate(cos(theta));
                        float y6 = Y6(float3(0,0,nol));
                        float sinTheta = sqrt(1 - nol*nol);
                        float3 skinNol = SkinNol(nol, i.uv.x);
                        integral += y6*sinTheta*skinNol;
                        theta += 0.001;
                        count++;
                    }
                    col = integral / count * UNITY_PI * sqrt(UNITY_FOUR_PI/5)*UNITY_TWO_PI * UNITY_INV_PI;
                }
                return float4(col, 1);
            }
            ENDCG
        }
    }
}
