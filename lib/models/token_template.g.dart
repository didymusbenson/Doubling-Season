// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TokenTemplateAdapter extends TypeAdapter<TokenTemplate> {
  @override
  final int typeId = 3;

  @override
  TokenTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TokenTemplate(
      name: fields[0] as String,
      pt: fields[1] as String,
      abilities: fields[2] as String,
      colors: fields[3] as String,
      order: fields[4] as double,
    ).._type = fields[5] == null ? '' : fields[5] as String?;
  }

  @override
  void write(BinaryWriter writer, TokenTemplate obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.pt)
      ..writeByte(2)
      ..write(obj.abilities)
      ..writeByte(3)
      ..write(obj.colors)
      ..writeByte(4)
      ..write(obj.order)
      ..writeByte(5)
      ..write(obj._type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
