// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_outcome.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RuleOutcomeAdapter extends TypeAdapter<RuleOutcome> {
  @override
  final int typeId = 12;

  @override
  RuleOutcome read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RuleOutcome(
      outcomeType: fields[0] == null ? 'multiply' : fields[0] as String,
      multiplier: fields[1] == null ? 2 : fields[1] as int,
      targetTokenId: fields[2] as String?,
      quantity: fields[3] == null ? 1 : fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RuleOutcome obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.outcomeType)
      ..writeByte(1)
      ..write(obj.multiplier)
      ..writeByte(2)
      ..write(obj.targetTokenId)
      ..writeByte(3)
      ..write(obj.quantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuleOutcomeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
