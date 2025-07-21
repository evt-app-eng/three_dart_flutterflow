import 'package:three_dart_flutterflow/three3d/materials/material.dart';

class GroupMaterial extends Material {
  List<Material>? children;

  GroupMaterial() : super() {
    type = "GroupMaterial";
  }
}
