shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform bool fabric = false;
uniform bool vertex_srgb = false;
uniform int surface_kind = 0;
uniform bool jersey_custom = false;
uniform bool shorts_custom = false;
uniform bool shoes_custom = false;
uniform vec4 jersey_base : source_color = vec4(1.0);
uniform vec4 jersey_panel : source_color = vec4(1.0);
uniform vec4 jersey_accent : source_color = vec4(1.0);
uniform vec4 shorts_base : source_color = vec4(1.0);
uniform vec4 shorts_panel : source_color = vec4(1.0);
uniform vec4 shorts_accent : source_color = vec4(1.0);
uniform vec4 shoes_base : source_color = vec4(1.0);
uniform vec4 shoes_panel : source_color = vec4(1.0);
uniform vec4 shoes_accent : source_color = vec4(1.0);
uniform int jersey_pattern = 0;
uniform int shorts_pattern = 0;
uniform int shoes_pattern = 0;
uniform sampler2D jersey_mark : source_color, filter_linear_mipmap_anisotropic;
float motif(int design, vec2 uv) {
 if(design==1)return 1.0-step(0.11,abs(uv.y-0.44));
 if(design==2)return 1.0-step(0.07,fract(uv.x*16.0));
 if(design==3)return smoothstep(0.15,0.85,uv.y);
 if(design==4)return 1.0-step(0.10,abs(fract(uv.y+uv.x*0.65)-0.5));
 if(design==5)return 1.0-step(0.06,abs(uv.y-0.38-abs(fract(uv.x*2.0)-0.5)*0.42));
 if(design==6)return mod(floor(uv.x*12.0)+floor(uv.y*10.0),2.0)*smoothstep(0.50,0.58,uv.y);
 if(design==7)return step(0.5,uv.x)*0.85;
 if(design==8)return 1.0-step(0.055,abs(uv.y-0.45-pow(fract(uv.x*2.0)-0.5,2.0)*0.75));
 return 0.0;
}
void fragment() {
 vec3 base = COLOR.rgb;
 if(vertex_srgb && !OUTPUT_IS_SRGB)base=mix(base/12.92,pow((base+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),base));
 int region = int(floor(UV.x / 4.0));
 vec2 garment_uv = UV - vec2(float(region)*4.0,0.0);
 if(jersey_custom && (region==1 || region==6 || region==4)){
  base=region==6?jersey_panel.rgb:jersey_base.rgb;
  if(surface_kind==1 || region==4)base=jersey_accent.rgb;
  else if(region==1){
   base=mix(base,jersey_pattern==2?jersey_accent.rgb:jersey_panel.rgb,motif(jersey_pattern,garment_uv));
  }
 }
 if(shorts_custom && (region==2 || region==7)){
  base=region==7?shorts_panel.rgb:shorts_base.rgb;
  if(region==2 && surface_kind==0)base=mix(base,shorts_panel.rgb,motif(shorts_pattern,garment_uv)*0.85);
  if(surface_kind==1 || (shorts_pattern==1 && (abs(garment_uv.y-0.85)<0.018 || abs(garment_uv.y-0.92)<0.018)))base=shorts_accent.rgb;
 }
 if(shoes_custom && (region==3 || region==8 || region==9))base=region==3?shoes_base.rgb:region==8?shoes_panel.rgb:shoes_accent.rgb;
 if(shoes_custom && region==3)base=mix(base,shoes_accent.rgb,motif(shoes_pattern,garment_uv));
 if (fabric) {
  vec2 p = garment_uv * vec2(220.0, 320.0);
  float aa = max(length(dFdx(p)), length(dFdy(p)));
  float weave = sin(p.x * 6.28318) * sin(p.y * 6.28318);
  float holes = pow(max(0.0, cos(p.x * 3.14159) * cos(p.y * 3.14159)), 10.0);
  base *= 1.0 + (weave * 0.035 - holes * 0.10) * (1.0 - smoothstep(0.4, 1.5, aa));
 }
 // UV2 is an authored garment print projection and is preserved by skinning.
 if(fabric && region==1 && UV2.x>0.0 && UV2.x<1.0 && UV2.y>0.0 && UV2.y<1.0){
  vec4 mark=texture(jersey_mark,UV2);
  base=mix(base,mark.rgb,mark.a);
 }
 ALBEDO = base;
 ROUGHNESS = 0.94;
}
