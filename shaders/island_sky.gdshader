shader_type sky;
uniform float night_amount : hint_range(0.0,1.0) = 0.0;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky() {
 float height=max(EYEDIR.y,0.0);
 vec3 day=mix(vec3(.79,.87,.82),vec3(.31,.59,.73),pow(height,.42));
 vec3 night=mix(vec3(.23,.34,.47),vec3(.035,.075,.19),pow(height,.45));
 vec3 color=mix(day,night,night_amount);
 vec2 uv=EYEDIR.xz/max(EYEDIR.y+.19,.05)*.43;
 float cloud=noise(uv*.9)*.55+noise(uv*2.1)*.28+noise(uv*4.2)*.17;
 float mask=smoothstep(.59,.75,cloud)*smoothstep(.01,.3,height);
 color=mix(color,mix(vec3(.98,.94,.85),vec3(.26,.35,.5),night_amount),mask*.64);
 vec3 moon_dir=normalize(vec3(-.3,.20,-1.0));
 float moon=dot(EYEDIR,moon_dir);
 color+=vec3(.92,.93,.79)*smoothstep(.99915,.9996,moon)*night_amount;
 color+=vec3(.13,.19,.22)*pow(max(moon,0.0),100.0)*night_amount;
 vec2 stars=SKY_COORDS*vec2(950.0,480.0);
 float star=step(.9972,hash(floor(stars)))*pow(max(1.0-length(fract(stars)-.5)*2.0,0.0),3.0);
 color+=star*vec3(.7,.81,1.0)*night_amount*smoothstep(.05,.3,height);
 COLOR=color;
}
