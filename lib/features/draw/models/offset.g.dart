// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offset.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OffsetCustomAdapter extends TypeAdapter<OffsetCustom> {
  @override
  final int typeId = 0;

  @override
  OffsetCustom read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OffsetCustom(
      fields[0] as double,
      fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, OffsetCustom obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.dx)
      ..writeByte(1)
      ..write(obj.dy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetCustomAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
