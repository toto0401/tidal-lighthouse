shader_type spatial;
render_mode cull_disabled;
uniform float low_tide : hint_range(0.0,1.0) = 1.0;
uniform float night_amount : hint_range(0.0,1.0) = 0.0;
uniform vec2 coast_offset = vec2(0.0);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
float shore(vec2 p) {
 p -= coast_offset;
 float d=length(p)-17.0;
 d=min(d,length(p-vec2(-31.0,-5.0))-14.0);
 d=min(d,length(p-vec2(32.0,2.0))-16.0);
 d=min(d,length(p-vec2(0.0,-36.0))-13.0);
 return d;
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_position.xz;
 float d=shore(p);
 float shallow=1.0-smoothstep(0.0,13.0,d);
 float n=noise(p*.18+vec2(TIME*.015,-TIME*.012));
 float n2=noise(p*.8+vec2(-TIME*.04,TIME*.025));
 vec3 deep=vec3(.10,.31,.43);
 vec3 lagoon=mix(vec3(.21,.55,.59),vec3(.26,.69,.64),low_tide);
 vec3 color=mix(deep,lagoon,shallow*.86)+vec3(n*.04);
 float swell=sin(d*3.6-TIME*.7+n2*1.7);
 float foam=smoothstep(.89,.99,swell)*(1.0-smoothstep(.4,4.0,d))*smoothstep(-.7,.4,d);
 float caustic=pow(1.0-abs(sin(p.x*.72+sin(p.y*.48+TIME*.3))+sin(p.y*.63-TIME*.22))*.5,18.0);
 caustic*=shallow*.095;
 vec2 spark_cell=floor(p*1.2);
 float spark=step(.988,hash(spark_cell))*pow(max(sin(TIME*1.2+hash(spark_cell+7.0)*6.28),0.0),9.0);
 spark*=1.0-smoothstep(.02,.25,length(fract(p*1.2)-.5));
 float glint=pow(max(sin(p.x*1.8+p.y*.8+TIME*.3)*sin(p.y*1.4-TIME*.4),0.0),26.0)*.11;
 ALBEDO=mix(color,color*vec3(.40,.52,.73),night_amount)+vec3(caustic+glint)+foam*vec3(.38,.46,.39);
 EMISSION=vec3(.13,.73,.69)*(foam*.16+caustic*.65+spark*.6*shallow)*low_tide*(.15+night_amount*2.2);
 NORMAL_MAP=vec3(.5+sin(p.x*.8+TIME*.42)*.035,.5+cos(p.y*.75-TIME*.31)*.035,1.0);
 ROUGHNESS=.6;
 SPECULAR=.2;
 METALLIC=.0;
}
