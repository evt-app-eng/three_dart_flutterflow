import 'package:three_dart_flutterflow/three3d/core/object_3d.dart';
import 'package:three_dart_flutterflow/three3d/lights/light.dart';

class RectAreaLight extends Light {
  RectAreaLight(color, intensity, width, height) : super(color, intensity) {
    type = 'RectAreaLight';

    this.width = width ?? 10;
    this.height = height ?? 10;
    isRectAreaLight = true;
  }

  @override
  copy(Object3D source, [bool? recursive]) {
    super.copy(source);

    RectAreaLight source1 = source as RectAreaLight;

    width = source1.width;
    height = source1.height;

    return this;
  }

  @override
  toJSON({Object3dMeta? meta}) {
    var data = super.toJSON(meta: meta);

    data["object"]["width"] = width;
    data["object"]["height"] = height;

    return data;
  }
}
