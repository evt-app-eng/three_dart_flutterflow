import 'package:flutter_gl_flutterflow/flutter_gl.dart';
import 'package:three_dart_flutterflow/three3d/core/index.dart';
import 'package:three_dart_flutterflow/three3d/math/index.dart';

class ConvexGeometry extends BufferGeometry {
  NativeArray? verticesArray;
  NativeArray? normalsArray;

  ConvexGeometry(points) : super() {
    List<double> vertices = [];
    List<double> normals = [];

    // buffers

    var convexHull = ConvexHull().setFromPoints(points);

    // generate vertices and normals

    var faces = convexHull.faces;

    for (var i = 0; i < faces.length; i++) {
      var face = faces[i];
      var edge = face.edge;

      // we move along a doubly-connected edge list to access all face points (see HalfEdge docs)

      do {
        var point = edge!.head().point;

        vertices.addAll([point.x.toDouble(), point.y.toDouble(), point.z.toDouble()]);
        normals.addAll([face.normal.x.toDouble(), face.normal.y.toDouble(), face.normal.z.toDouble()]);

        edge = edge.next;
      } while (edge != face.edge);
    }

    // build geometry
    setAttribute('position', Float32BufferAttribute(verticesArray = Float32Array.from(vertices), 3, false));
    setAttribute('normal', Float32BufferAttribute(normalsArray = Float32Array.from(normals), 3, false));
  }

  @override
  void dispose() {
    verticesArray?.dispose();
    normalsArray?.dispose();

    super.dispose();
  }
}
