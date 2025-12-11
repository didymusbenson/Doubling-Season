// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'krenko_utility.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KrenkoUtilityAdapter extends TypeAdapter<KrenkoUtility> {
  @override
  final int typeId = 8;

  @override
  KrenkoUtility read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KrenkoUtility(
      utilityId: fields[0] as String,
      name: fields[1] as String,
      colorIdentity: fields[2] as String,
      artworkUrl: fields[3] as String?,
      order: fields[4] as double,
      createdAt: fields[5] as DateTime,
      krenkoPower: fields[6] as int,
      nontokenGoblins: fields[7] as int,
      isCustom: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, KrenkoUtility obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.utilityId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorIdentity)
      ..writeByte(3)
      ..write(obj.artworkUrl)
      ..writeByte(4)
      ..write(obj.order)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.krenkoPower)
      ..writeByte(7)
      ..write(obj.nontokenGoblins)
      ..writeByte(8)
      ..write(obj.isCustom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KrenkoUtilityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
