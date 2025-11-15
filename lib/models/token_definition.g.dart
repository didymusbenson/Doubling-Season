// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_definition.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArtworkVariantAdapter extends TypeAdapter<ArtworkVariant> {
  @override
  final int typeId = 4;

  @override
  ArtworkVariant read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArtworkVariant(
      set: fields[0] as String,
      url: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ArtworkVariant obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.set)
      ..writeByte(1)
      ..write(obj.url);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtworkVariantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
