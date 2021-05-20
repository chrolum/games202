#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 70
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10
#define FILTER_SIZE 3
#define SAMEPLE_SIZE 4 * (FILTER_SIZE + 1) * (FILTER_SIZE + 1)
#define LIGHT_SIZE_UV 70.0
#define Z_NEAR_PLANE 0.1
#define BLOCKER_SEARCH_SIZR 2
#define TEXEL_SIZE 2048.0
#define BIAS 0.01


#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

#define SHADOWEPS 0.01

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

// return the avg depth of blocker
float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver ) {
	
  float search_width = LIGHT_SIZE_UV * (zReceiver - Z_NEAR_PLANE) / zReceiver;
  float shadowDepth;
  vec2 texelSize = 1.0/vec2(2048.0);
  float total_depth = 0.0;
  int blocker_num = 0;
  for (int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; i++)
  {
    shadowDepth = unpack(texture2D(shadowMap, uv + (poissonDisk[i] / TEXEL_SIZE) * search_width));
    if (shadowDepth + BIAS < zReceiver)
    {
      total_depth += shadowDepth;
      blocker_num++;
    }

  }
  if (blocker_num == 0)
    return 0.0;
  return total_depth / float(blocker_num);
}

float PCF(sampler2D shadowMap, vec4 coords, float filterSize) {
  //assert odd filtersize
  poissonDiskSamples(coords.xy);
  float shadowDepth;
  float z = coords.z;
  int blockerCnt = 0;
  vec2 texelSize = 1.0 / vec2(2048.0); //shadowmap size is defined in engine.js
  float pcfDepth;

  for (int i = 0; i < NUM_SAMPLES; i++)
  {
    pcfDepth = unpack(texture2D(shadowMap, coords.xy + (poissonDisk[i] / TEXEL_SIZE) * filterSize));
    blockerCnt += (pcfDepth + BIAS > z) ? 1 : 0;
  }


  // for(int x = -FILTER_SIZE; x <= FILTER_SIZE; x++)
  // {
  //   for(int y = -FILTER_SIZE; y <= FILTER_SIZE; y++)
  //   {
  //     pcfDepth = unpack(texture2D(shadowMap, coords.xy + vec2(x, y)*texelSize));
  //     blockerCnt += (z-pcfDepth<SHADOWEPS) ? 1 : 0;
  //   }
  // }

  return float(blockerCnt) / float(NUM_SAMPLES);
}

float PCSS(sampler2D shadowMap, vec4 coords){

  // STEP 1: avgblocker depth
  vec3 ndc_coord = coords.xyz / coords.w;
  ndc_coord = ndc_coord * 0.5 + 0.5;
  poissonDiskSamples(ndc_coord.xy);
  vec2 texelSize = 1.0/vec2(2048.0);
  float d_reciever = ndc_coord.z;
  float avg_depth = findBlocker(shadowMap, ndc_coord.xy, d_reciever);
  if (avg_depth == 0.0)
    return 1.0;
  // STEP 2: penumbra size
  float w_penumbra = (d_reciever - avg_depth) / float(avg_depth);
  float penumbraUV = LIGHT_SIZE_UV * w_penumbra * Z_NEAR_PLANE / d_reciever;

  // STEP 3: filtering
  return PCF(shadowMap, vec4(ndc_coord, 1.0), penumbraUV);

}


float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  float shadowDepth = unpack(texture2D(shadowMap, shadowCoord.xy));
  float z = shadowCoord.z;

  return (z - shadowDepth < SHADOWEPS) ? 1.0 : 0.0;
}

vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {

  float visibility;
  // vec3 shadowCoord = (vPositionFromLight.xyz / vPositionFromLight.w);
  // vec3 shadowCoord = vPositionFromLight.xyz / vPositionFromLight.w * 0.5 + 0.5;
  // visibility = useShadowMap(uShadowMap, vec4(shadowCoord, 1.0));
  // visibility = PCF(uShadowMap, vec4(shadowCoord.xyz, 1.0));
  visibility = PCSS(uShadowMap, vPositionFromLight);

  vec3 phongColor = blinnPhong();

  //gl_FragColor = vec4(phongColor * visibility, 1.0);
  // gl_FragColor = vec4(phongColor * visibility, 1.0);
  vec3 testColor = vec3(1.0, 1.0, 1.0);
  gl_FragColor = vec4(phongColor * visibility, 1.0);
}