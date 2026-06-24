shader_type spatial;
render_mode depth_test_disabled, unshaded;

uniform int MAX_STEPS = 100;
uniform float MAX_DIST = 100.0;
uniform float SURF_DIST = 0.01;

uniform float STEP_LENGTH = 0.1;
uniform float LIGHT_STEP_LENGTH = 0.1;
uniform float ABSORPTION = 0.1;
uniform float LIGHT_ABSORPTION = 0.1;

uniform vec4 cloud_sphere_shape=vec4(0,0,0,1);
uniform vec3 color : source_color = vec3(1,1,1);

instance uniform vec3 light_direction;


vec3 hash33( ivec3 x )
{
	const int k = 1103515245;
    x = ((x>>8)^x.yzx)*k;
    x = ((x>>8)^x.yzx)*k;
    x = ((x>>8)^x.yzx)*k;
    
    return vec3(x)*(1.0/float(0xffffffffU)) * 2. - 1.0;
}


// returns 3D gradient noise
float perlin_noise( in vec3 x )
{
    // grid
	x += vec3(TIME,0,0);
    ivec3 i = ivec3(floor(x));
    vec3 f = fract(x);
    
    // quintic interpolant
    vec3 u = f*f*f*(f*(f*6.0-15.0)+10.0);
    
    // gradients
    vec3 ga = hash33( i+ivec3(0,0,0) );
    vec3 gb = hash33( i+ivec3(1,0,0) );
    vec3 gc = hash33( i+ivec3(0,1,0) );
    vec3 gd = hash33( i+ivec3(1,1,0) );
    vec3 ge = hash33( i+ivec3(0,0,1) );
    vec3 gf = hash33( i+ivec3(1,0,1) );
    vec3 gg = hash33( i+ivec3(0,1,1) );
    vec3 gh = hash33( i+ivec3(1,1,1) );
    
    // projections
    float va = dot( ga, f-vec3(0.0,0.0,0.0) );
    float vb = dot( gb, f-vec3(1.0,0.0,0.0) );
    float vc = dot( gc, f-vec3(0.0,1.0,0.0) );
    float vd = dot( gd, f-vec3(1.0,1.0,0.0) );
    float ve = dot( ge, f-vec3(0.0,0.0,1.0) );
    float vf = dot( gf, f-vec3(1.0,0.0,1.0) );
    float vg = dot( gg, f-vec3(0.0,1.0,1.0) );
    float vh = dot( gh, f-vec3(1.0,1.0,1.0) );
	
    // interpolation
    return va + 
           u.x*(vb-va) + 
           u.y*(vc-va) + 
           u.z*(ve-va) + 
           u.x*u.y*(va-vb-vc+vd) + 
           u.y*u.z*(va-vc-ve+vg) + 
           u.z*u.x*(va-vb-ve+vf) + 
           u.x*u.y*u.z*(-va+vb+vc-vd+ve-vf-vg+vh);
}

float fbm(vec3 p){
	float value = 0.0;
	float amplitude = 0.5;
	
	for(int i=0; i<1; i++){
		value+=amplitude*perlin_noise(p);
		p*=2.0;
		amplitude*=0.5;
	}
	return value;
}

float sphere_SDF(vec3 point, vec3 center, float radius){
    return length(point-center) - radius;
}

float get_distance(vec3 p){
	return sphere_SDF(p, cloud_sphere_shape.xyz, cloud_sphere_shape.w);
}

float sphere_tracing(vec3 ray_origin, vec3 ray_direction){
	float d = 0.0;
	for(int i = 0; i<MAX_STEPS; i++){
		vec3 p = ray_origin + ray_direction*d;
		float sdf_sample = get_distance(p);
		d += sdf_sample;
		if(sdf_sample<SURF_DIST || d>MAX_DIST) break;
			
	}
	return d;
}

float beers_law(float distance, float absorption){
	return exp(-distance * absorption);
}

vec2 raymarch(vec3 ray_origin, vec3 ray_dir, float entry_dist){
	vec3 sample_point = ray_origin + ray_dir*(entry_dist+STEP_LENGTH);
	float in_cloud_dist = 0.0;
	float light_transmittance = 0.0;
	
	while(get_distance(sample_point)<0.){
		vec3 light_sample_point = sample_point;
		float light_transmitted = 0.0;
		for(int i=0; i<MAX_STEPS && get_distance(light_sample_point)<0.; i++){
			float density = clamp(fbm(light_sample_point*0.2), 0, 1);
			light_transmitted += LIGHT_STEP_LENGTH * density;
			light_sample_point += -light_direction*LIGHT_STEP_LENGTH;
			if(light_transmitted>=LIGHT_STEP_LENGTH)break;
		}
		float density = clamp(fbm(sample_point*0.2), 0, 1);
		
		in_cloud_dist+= STEP_LENGTH * density;
		sample_point += ray_dir*STEP_LENGTH;
		light_transmittance += light_transmitted;
		
		if(light_transmitted>=LIGHT_STEP_LENGTH)break;
	}
	return vec2(in_cloud_dist, light_transmittance);
}

void fragment(){
	vec3 ws_pixel_pos = ((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz); //TO WORLD SPACE
	vec3 ray_origin = CAMERA_POSITION_WORLD;
	vec3 ray_direction = normalize(ws_pixel_pos-ray_origin);
	
	float entry_dist = sphere_tracing(ray_origin, ray_direction);
	if(entry_dist<MAX_DIST){
		vec2 sample = raymarch(ray_origin, ray_direction, entry_dist);
		ALPHA = 1.0 - beers_law(sample.x, ABSORPTION);
		ALBEDO = color * beers_law(sample.y, LIGHT_ABSORPTION);
	}
	else ALPHA = 0.0;
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
