shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform sampler2D face_map : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 skin_tone : source_color;
uniform vec4 paint_reference : source_color = vec4(0.70,0.43,0.25,1.0);
void fragment(){
 vec3 detail=texture(face_map,clamp(UV,vec2(0.002),vec2(0.998))).rgb;
 vec3 relative=detail/max(paint_reference.rgb,vec3(0.04));
 float edge=(1.0-smoothstep(0.86,0.99,abs(UV.x-0.5)*2.0))*(1.0-smoothstep(0.91,1.0,UV.y));
 ALBEDO=skin_tone.rgb*mix(vec3(1.0),relative,edge*0.88);
 ROUGHNESS=0.98;
}
