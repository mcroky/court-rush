shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform bool fabric = false;
uniform sampler2D jersey_mark : source_color, filter_linear_mipmap_anisotropic;
void fragment() {
 vec3 base = COLOR.rgb;
 if (fabric) {
  vec2 p = UV * vec2(220.0, 320.0);
  float aa = max(length(dFdx(p)), length(dFdy(p)));
  float weave = sin(p.x * 6.28318) * sin(p.y * 6.28318);
  float holes = pow(max(0.0, cos(p.x * 3.14159) * cos(p.y * 3.14159)), 10.0);
  base *= 1.0 + (weave * 0.035 - holes * 0.10) * (1.0 - smoothstep(0.4, 1.5, aa));
 }
 // UV2 is an authored garment print projection and is preserved by skinning.
 if(UV2.x>0.0 && UV2.x<1.0 && UV2.y>0.0 && UV2.y<1.0){
  vec4 mark=texture(jersey_mark,UV2);
  base=mix(base,mark.rgb,mark.a);
 }
 ALBEDO = base;
 ROUGHNESS = 0.94;
}
