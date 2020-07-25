#define LOWPREC lowp
#define MATRIX_VIEW 0
#define MATRIX_PROJECTION 1
#define MATRIX_WORLD 2
#define MATRIX_WORLD_VIEW 3
#define MATRIX_WORLD_VIEW_PROJECTION 4
#define MATRICES_MAX5

uniform mat4 gm_Matrices[MATRICES_MAX]; 

uniform bool gm_LightingEnabled;
uniform bool gm_VS_FogEnabled;
uniform float gm_FogStart;
uniform float gm_RcpFogRange;

#define MAX_VS_LIGHTS8
#define MIRROR_WIN32_LIGHTING_EQUATION


//#defineMAX_VS_LIGHTS8
uniform vec4   gm_AmbientColour;// rgb=colour, a=1
uniform vec4   gm_Lights_Direction[MAX_VS_LIGHTS];// normalised direction
uniform vec4   gm_Lights_PosRange[MAX_VS_LIGHTS];// X,Y,Z position,  W range
uniform vec4   gm_Lights_Colour[MAX_VS_LIGHTS];// rgb=colour, a=1

float CalcFogFactor(vec4 pos)
{
if (gm_VS_FogEnabled)
{
vec4 viewpos = gm_Matrices[MATRIX_WORLD_VIEW] * pos;
float fogfactor = ((viewpos.z - gm_FogStart) * gm_RcpFogRange);
return fogfactor;
}
else
{
return 0.0;
}
}

vec4 DoDirLight(vec3 ws_normal, vec4 dir, vec4 diffusecol)
{
float dotresult = dot(ws_normal, dir.xyz);
dotresult = max(0.0, dotresult);

return dotresult * diffusecol;
}

vec4 DoPointLight(vec3 ws_pos, vec3 ws_normal, vec4 posrange, vec4 diffusecol)
{
vec3 diffvec = ws_pos - posrange.xyz;
float veclen = length(diffvec);
diffvec /= veclen;// normalise
#ifdef MIRROR_WIN32_LIGHTING_EQUATION
// This is based on the Win32 D3D and OpenGL falloff model, where:
// Attenuation = 1.0f / (factor0 + (d * factor1) + (d*d * factor2))
// For some reason, factor0 is set to 0.0f while factor1 is set to 1.0f/lightrange (on both D3D and OpenGL)
// This'll result in no visible falloff as 1.0f / (d / lightrange) will always be larger than 1.0f (if the vertex is within range)
float atten = 1.0 / (veclen / posrange.w);
if (veclen > posrange.w)
{
atten = 0.0;
}
#else
float atten = clamp( (1.0 - (veclen / posrange.w)), 0.0, 1.0);// storing 1.0f/range instead would save a rcp
#endif
float dotresult = dot(ws_normal, diffvec);
dotresult = max(0.0, dotresult);

return dotresult * atten * diffusecol;
}

vec4 DoLighting(vec4 vertexcolour, vec4 objectspacepos, vec3 objectspacenormal)
{
if (gm_LightingEnabled)
{
// Normally we'd have the light positions\\directions back-transformed from world to object space
// But to keep things simple for the moment we'll just transform the normal to world space
vec4 objectspacenormal4 = vec4(objectspacenormal, 0.0);
vec3 ws_normal;
ws_normal = (gm_Matrices[MATRIX_WORLD_VIEW] * objectspacenormal4).xyz;
ws_normal = -normalize(ws_normal);

vec3 ws_pos;
ws_pos = (gm_Matrices[MATRIX_WORLD] * objectspacepos).xyz;

// Accumulate lighting from different light types
vec4 accumcol = vec4(0.0, 0.0, 0.0, 0.0);
for(int i = 0; i < MAX_VS_LIGHTS; i++)
{
accumcol += DoDirLight(ws_normal, gm_Lights_Direction[i], gm_Lights_Colour[i]);
}

for(int i = 0; i < MAX_VS_LIGHTS; i++)
{
accumcol += DoPointLight(ws_pos, ws_normal, gm_Lights_PosRange[i], gm_Lights_Colour[i]);
}

accumcol *= vertexcolour;
accumcol += gm_AmbientColour;
accumcol = min(vec4(1.0, 1.0, 1.0, 1.0), accumcol);
accumcol.a = vertexcolour.a;
return accumcol;
}
else
{
return vertexcolour;
}
}

#define _YY_GLSLES_ 1
attribute vec3 in_Position;                  // (x,y,z)
attribute vec4 in_Colour;                    // (r,g,b,a)
attribute vec2 in_TextureCoord;              // (u,v)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;

void main()
{
    vec4 object_space_pos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
}


//######################_==_YOYO_SHADER_MARKER_==_######################@~precision mediump float;
#define LOWPREC lowp
// Uniforms look like they're shared between vertex and fragment shaders in GLSL, so we have to be careful to avoid name clashes

uniform sampler2D gm_BaseTexture;

uniform bool gm_PS_FogEnabled;
uniform vec4 gm_FogColour;
uniform bool gm_AlphaTestEnabled;
uniform float gm_AlphaRefValue;

void DoAlphaTest(vec4 SrcColour)
{
	if (gm_AlphaTestEnabled)
	{
		if (SrcColour.a <= gm_AlphaRefValue)
		{
			discard;
		}
	}
}

void DoFog(inout vec4 SrcColour, float fogval)
{
	if (gm_PS_FogEnabled)
	{
		SrcColour = mix(SrcColour, gm_FogColour, clamp(fogval, 0.0, 1.0)); 
	}
}

#define _YY_GLSLES_ 1
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform sampler2D palette_texture;
uniform vec2 texel_size;
uniform vec4 palette_UVs;
uniform float palette_index;

void main()
{
    vec4 source = texture2D( gm_BaseTexture, v_vTexcoord );
    
    DoAlphaTest( source );
    
    for(float i = palette_UVs.y; i < palette_UVs.w; i+=texel_size.y )
    {
        if (distance(source, texture2D(palette_texture, vec2(palette_UVs.x, i))) <= 0.004)
        {
            float palette_V = palette_UVs.x + texel_size.x * palette_index;
            source = texture2D(palette_texture, vec2(palette_V, i));
            break;
        }
    }

    gl_FragColor = source * v_vColour;
}

