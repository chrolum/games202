#ifdef GL_ES
precision mediump float;
#endif

attribute mat3 aPrecomputeLT;
attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute vec2 aTextureCoord;

uniform vec3 uPrecomputeL[9];
uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;
varying vec3 vColor;

void main(void) {

  vFragPos = (uModelMatrix * vec4(aVertexPosition, 1.0)).xyz;
  vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;

  for (int i = 0; i < 3; i++)
  {
    for (int j = 0; j < 3; j++)
    {
      vColor[0] += uPrecomputeL[i][0] * aPrecomputeLT[0][j];
      vColor[1] += uPrecomputeL[i][1] * aPrecomputeLT[0][j];
      vColor[2] += uPrecomputeL[i][2] * aPrecomputeLT[0][j];
    }
  }

  for (int i = 3; i < 6; i++)
  {
    for (int j = 0; j < 3; j++)
    {
      vColor[0] += uPrecomputeL[i][0] * aPrecomputeLT[1][j];
      vColor[1] += uPrecomputeL[i][1] * aPrecomputeLT[1][j];
      vColor[2] += uPrecomputeL[i][2] * aPrecomputeLT[1][j];
    }
  }

  for (int i = 6; i < 9; i++)
  {
    for (int j = 0; j < 3; j++)
    {
      vColor[0] += uPrecomputeL[i][0] * aPrecomputeLT[2][j];
      vColor[1] += uPrecomputeL[i][1] * aPrecomputeLT[2][j];
      vColor[2] += uPrecomputeL[i][2] * aPrecomputeLT[2][j];
    }
  }

  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix *
                vec4(aVertexPosition, 1.0);
}
