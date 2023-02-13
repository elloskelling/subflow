/* 
subflow - a music visualizer
Copyright (C) 2021-2023 Ello Skelling Productions

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#include <metal_stdlib>
#include "constants.h"
using namespace metal;

struct VertexIn{
  packed_float3 position;
  packed_float4 color;
};

struct VertexOut{
  float4 position [[position]];
  float4 color;
};

struct Uniforms{
  float4x4 modelMatrix[NUM_TRIANGLES];
  float4x4 projectionMatrix;
  float greys[NUM_TRIANGLES];
};

vertex VertexOut basic_vertex(
                              const device VertexIn* vertex_array [[ buffer(0) ]],
                              const device Uniforms&  uniforms    [[ buffer(1) ]],
                              unsigned int vid [[ vertex_id ]]) {
  float4x4 mv_Matrix;
  float4x4 proj_Matrix = uniforms.projectionMatrix;
  
  unsigned int mid = as_type<uint>(vid/4);
  mv_Matrix = uniforms.modelMatrix[mid];
  VertexIn VertexIn = vertex_array[vid];
  float grey = uniforms.greys[mid];
  
  
  VertexOut VertexOut;
  VertexOut.position = proj_Matrix * mv_Matrix * float4(VertexIn.position,1);
  
  for (int k = 0; k<3; k++)
    VertexOut.color[k] = grey;
  
  return VertexOut;
}

fragment half4 basic_fragment(VertexOut interpolated [[stage_in]]) {
  return half4(interpolated.color[0], interpolated.color[1], interpolated.color[2], interpolated.color[3]);
}
