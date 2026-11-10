// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 0;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Item(
      name: fields[1] as String,
      pt: fields[2] as String,
      abilities: fields[0] as String,
      counters: (fields[9] as List?)?.cast<TokenCounter>(),
      createdAt: fields[10] as DateTime?,
      order: fields[11] as double,
    )
      .._colors = fields[3] as String
      .._amount = fields[4] as int
      .._tapped = fields[5] as int
      .._summoningSick = fields[6] as int
      .._plusOneCounters = fields[7] as int
      .._minusOneCounters = fields[8] as int;
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.abilities)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.pt)
      ..writeByte(3)
      ..write(obj._colors)
      ..writeByte(4)
      ..write(obj._amount)
      ..writeByte(5)
      ..write(obj._tapped)
      ..writeByte(6)
      ..write(obj._summoningSick)
      ..writeByte(7)
      ..write(obj._plusOneCounters)
      ..writeByte(8)
      ..write(obj._minusOneCounters)
      ..writeByte(9)
      ..write(obj.counters)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
