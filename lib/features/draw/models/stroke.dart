import 'dart:ui';

import 'package:drawing_app_artify/features/draw/models/offset.dart';
import 'package:hive/hive.dart';

part 'stroke.g.dart';

@HiveType(typeId: 1)
class Stroke extends HiveObject {
  @HiveField(0)
  final List<OffsetCustom> points;

  @HiveField(1)
  final int color;

  @HiveField(2)
  final double brushSize;

  Stroke({
    required this.points,
    required this.color,
    required this.brushSize,
  });

  Color get strokeColor => Color(color);

  List<Offset> get offsetPoints => points.map((e) => e.toOffset()).toList();

  factory Stroke.fromOffsets({
    required List<Offset> points,
    required Color color,
    required double brushSize,
  }) {
    return Stroke(
      points: points.map((e) => OffsetCustom.fromOffset(e)).toList(),
      color: color.value,
      brushSize: brushSize,
    );
  }

  // Create a copy of this stroke with modified properties
  Stroke copyWith({
    List<OffsetCustom>? points,
    int? color,
    double? brushSize,
  }) {
    return Stroke(
      points: points ?? this.points,
      color: color ?? this.color,
      brushSize: brushSize ?? this.brushSize,
    );
  }

  @override
  String toString() {
    return 'Stroke(points: ${points.length}, color: $color, brushSize: $brushSize)';
  }
}