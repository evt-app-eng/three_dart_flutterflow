import 'package:three_dart_flutterflow/three3d/core/object_3d.dart';

class Group extends Object3D {
  bool isGroup = true;

  dynamic animations;

  Group() : super() {
    type = 'Group';
  }
  Group.fromJSON(Map<String, dynamic> json, Map<String, dynamic> rootJSON) : super.fromJSON(json, rootJSON) {
    type = 'Group';
  }
}
