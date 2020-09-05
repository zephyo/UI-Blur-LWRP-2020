Shader "Custom/UIBlur"
{
    
    Properties
    {
        // Blur properties
        [IntRange] _Radius("Blur Radius", Range(0, 64)) = 1
        [IntRange] _Step("Step Size", Range(3, 10)) = 4
        _Jump("Jump Size", Range(0.0001,0.3)) = 0.1
        _BlurTex ("Blurred Texture", 2D) = "white" {}

        // Default properties
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)

        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255

        _ColorMask ("Color Mask", Float) = 15

        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Pass
        {
            Name "Default"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP

            struct appdata_t
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 texcoord  : TEXCOORD0;
                float4 screenPosition : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            int _Radius;
            float _Step; 
            float _Jump;
            sampler2D _BlurTex;

            sampler2D _MainTex;
            fixed4 _Color;
            fixed4 _TextureSampleAdd;
            float4 _ClipRect;
            float4 _MainTex_ST;

            half4 GetBlur(float4 uv, half4 pixel)
            {
                #define GrabPixelXY(kernelx, kernely) tex2Dproj(_BlurTex, UNITY_PROJ_COORD(float4(uv.x +  _Jump * kernelx, uv.y + _Jump*kernely, uv.z,uv.w)))
                
                float4 sum = GrabPixelXY(0,0);

                float range = _Step;
                
                for (; range <= _Radius; range += _Step)
                {
                    for (float i = 0.06; i <= 0.18; i+= 0.03){
                        float minus = (0.21-i);
                        sum += GrabPixelXY(-range*i, range*minus);
                        sum += GrabPixelXY(range*i, -range*minus);
                        sum += GrabPixelXY(-range*minus, -range*i);
                        sum += GrabPixelXY(range*minus, range*i);
                    }
                }

                half4 result = sum/(_Radius*2+1);
                return result * pixel;
            }

            v2f vert(appdata_t v)
            {
                v2f OUT;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                OUT.vertex = UnityObjectToClipPos(v.vertex);
                OUT.screenPosition = ComputeScreenPos(OUT.vertex);

                OUT.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);

                OUT.color = v.color * _Color;
                return OUT;
            }

            fixed4 frag(v2f IN) : SV_Target
            {
                half4 color = (tex2D(_MainTex, IN.texcoord) + _TextureSampleAdd) * IN.color;

                #ifdef UNITY_UI_ALPHACLIP
                    clip (color.a - 0.001);
                #endif

                return  GetBlur(IN.screenPosition, color);
            }
            ENDCG
        }
    }
}
