shader_type spatial;
render_mode depth_test_disabled;

uniform vec4 sphere_1;
uniform vec4 sphere_2;

uniform float blend_tolerance;

uniform int MAX_STEPS = 100;
uniform float MAX_DIST = 100.0;
uniform float SURF_DIST = 0.01;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

float smin( float a, float b, float k ) // comes from inigo quilez
{
    k *= 1.0/(1.0-sqrt(0.5));
    float h = max( k-abs(a-b), 0.0 )/k;
    return min(a,b) - k*0.5*(1.0+h-sqrt(1.0-h*(h-2.0)));
}

float SphereSDF(vec3 point, vec3 center, float radius){
    return length(point-center) - radius;
}

float getDistance(vec3 point){
    float sdf1 = SphereSDF(point,sphere_1.xyz, sphere_1.w);
    float sdf2 = SphereSDF(point,sphere_2.xyz, sphere_2.w);
    return smin(sdf1, sdf2, blend_tolerance);
}

vec3 getNormal(vec3 p){
	float d = getDistance(p);
	vec2 e = vec2(0.0005, 0);
	return normalize(d-vec3(
		getDistance(p - e.xyy),
		getDistance(p - e.yxy),
		getDistance(p - e.yyx)
	));
}

float raymarch(vec3 ray_origin, vec3 ray_direction){
	float d = 0.0;
	for(int i = 0; i<MAX_STEPS; i++){
		vec3 p = ray_origin + ray_direction*d;
		float sdf_sample = getDistance(p);
		d += sdf_sample;
		if(sdf_sample<SURF_DIST || d>MAX_DIST) break;
			
	}
	return d;
}

void fragment() {
	vec3 ws_pixel_pos = ((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz); //TO WORLD SPACE
	vec3 ray_origin = CAMERA_POSITION_WORLD;
	vec3 ray_direction = normalize(ws_pixel_pos-ray_origin);
	
	float d = raymarch(ray_origin, ray_direction);
	
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
  	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
  	view.xyz /= view.w;
  	float linear_depth = -view.z;
	
	vec3 n = getNormal(ray_origin + ray_direction *d);
	ALPHA = step(d, min(MAX_DIST, linear_depth));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	ALBEDO = vec3(1,1,1);
}
void light(){
	float ndot = clamp(dot(NORMAL, LIGHT), 0, 1);
	/*float step1 = step(0.5,  ndot)*1.0; //si ndot > 0.5 ->1.0
	float step2 = step(0.,  ndot)*0.5;
	float step3 = step(-1,  ndot)*0.;*/
	
	DIFFUSE_LIGHT += LIGHT_COLOR/PI * ATTENUATION * ndot; //max(max(step1, step2), step3);
	
}