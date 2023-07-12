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

import Foundation
import Metal

// A class representing a triangle in the Metal graphics framework
class Triangle: Node {
  
  // The initializer function for the Triangle class
  init(device: MTLDevice){
    // Defining vertex positions and colors for an equilateral triangle in a 2D space
    let V00 = Vertex(x:  0.0, y:   0.0, z:   0.0, r:  0.0, g:  0.0, b:  0.0, a:  0.0)
    let V0 = Vertex(x:  0.0, y:   0.866, z:   0.0, r:  1.0, g:  0.0, b:  0.0, a:  1.0)
    let V1 = Vertex(x: -1.0, y:  -0.866, z:   0.0, r:  0.0, g:  1.0, b:  0.0, a:  1.0)
    let V2 = Vertex(x:  1.0, y:  -0.866, z:   0.0, r:  0.0, g:  0.0, b:  1.0, a:  1.0)
    
    // Creating an array of vertices for a full array of triangles, initialized with V00
    var verticesArray = [Vertex](repeating: V00, count: 4*Int(NUM_TRIANGLES))
    
    // Populating the correct coordinates for each triangle in the array
    for ni in 0...(Int(NUM_TRIANGLES)-1){
      verticesArray[ni*4] = V0
      verticesArray[ni*4+1] = V1
      verticesArray[ni*4+2] = V2
      verticesArray[ni*4+3] = V0
    }

    // Initializing the Node superclass with the name "Triangles", the vertices array, and the device
    super.init(name: "Triangles", vertices: verticesArray, device: device)

  }
  
}
