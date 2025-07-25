import 'package:flutter_gl_flutterflow/flutter_gl.dart';
import 'package:three_dart_flutterflow/three3d/core/index.dart';
import 'package:three_dart_flutterflow/three3d/math/index.dart';

class SphereGeometry extends BufferGeometry {
  NativeArray? verticesArray;
  NativeArray? normalsArray;
  NativeArray? uvsArray;

  SphereGeometry([
    radius = 1,
    num widthSegments = 32,
    num heightSegments = 16,
    phiStart = 0,
    phiLength = Math.pi * 2,
    thetaStart = 0,
    thetaLength = Math.pi,
  ]) : super() {
    type = "SphereGeometry";
    parameters = {
      "radius": radius,
      "widthSegments": widthSegments,
      "heightSegments": heightSegments,
      "phiStart": phiStart,
      "phiLength": phiLength,
      "thetaStart": thetaStart,
      "thetaLength": thetaLength,
    };

    widthSegments = Math.max(3, Math.floor(widthSegments));
    heightSegments = Math.max(2, Math.floor(heightSegments));

    var thetaEnd = Math.min<num>(thetaStart + thetaLength, Math.pi);

    var index = 0;
    var grid = [];

    var vertex = Vector3.init();
    var normal = Vector3.init();

    // buffers

    List<num> indices = [];
    List<double> vertices = [];
    List<double> normals = [];
    List<double> uvs = [];

    // generate vertices, normals and uvs

    for (var iy = 0; iy <= heightSegments; iy++) {
      var verticesRow = [];

      var v = iy / heightSegments;

      // special case for the poles

      num uOffset = 0;

      if (iy == 0 && thetaStart == 0) {
        uOffset = 0.5 / widthSegments;
      } else if (iy == heightSegments && thetaEnd == Math.pi) {
        uOffset = -0.5 / widthSegments;
      }

      for (var ix = 0; ix <= widthSegments; ix++) {
        var u = ix / widthSegments;

        // vertex

        vertex.x = -radius * Math.cos(phiStart + u * phiLength) * Math.sin(thetaStart + v * thetaLength);
        vertex.y = radius * Math.cos(thetaStart + v * thetaLength);
        vertex.z = radius * Math.sin(phiStart + u * phiLength) * Math.sin(thetaStart + v * thetaLength);

        vertices.addAll([vertex.x.toDouble(), vertex.y.toDouble(), vertex.z.toDouble()]);

        // normal

        normal.copy(vertex).normalize();
        normals.addAll([normal.x.toDouble(), normal.y.toDouble(), normal.z.toDouble()]);

        // uv

        uvs.addAll([u + uOffset, 1 - v]);

        verticesRow.add(index++);
      }

      grid.add(verticesRow);
    }

    // indices

    for (var iy = 0; iy < heightSegments; iy++) {
      for (var ix = 0; ix < widthSegments; ix++) {
        var a = grid[iy][ix + 1];
        var b = grid[iy][ix];
        var c = grid[iy + 1][ix];
        var d = grid[iy + 1][ix + 1];

        if (iy != 0 || thetaStart > 0) indices.addAll([a, b, d]);
        if (iy != heightSegments - 1 || thetaEnd < Math.pi) {
          indices.addAll([b, c, d]);
        }
      }
    }

    // build geometry

    setIndex(indices);
    setAttribute('position', Float32BufferAttribute(verticesArray = Float32Array.from(vertices), 3, false));
    setAttribute('normal', Float32BufferAttribute(normalsArray = Float32Array.from(normals), 3, false));
    setAttribute('uv', Float32BufferAttribute(uvsArray = Float32Array.from(uvs), 2, false));
  }

  @override
  void dispose() {
    verticesArray?.dispose();
    normalsArray?.dispose();
    uvsArray?.dispose();
    super.dispose();
  }

  static fromJSON(data) {
    return SphereGeometry(data["radius"], data["widthSegments"], data["heightSegments"], data["phiStart"],
        data["phiLength"], data["thetaStart"], data["thetaLength"]);
  }
}
