// 环境光 环境光颜色与网格模型的颜色进行RGB进行乘法运算

import 'package:three_dart_flutterflow/three3d/lights/light.dart';

class AmbientLight extends Light {
  bool isAmbientLight = true;

  AmbientLight(color, [double? intensity]) : super(color, intensity) {
    type = 'AmbientLight';
  }

  AmbientLight.fromJSON(Map<String, dynamic> json, Map<String, dynamic> rootJSON) : super.fromJSON(json, rootJSON) {
    type = 'AmbientLight';
  }
}
