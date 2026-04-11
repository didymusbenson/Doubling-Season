// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_trigger.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RuleTriggerAdapter extends TypeAdapter<RuleTrigger> {
  @override
  final int typeId = 11;

  @override
  RuleTrigger read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RuleTrigger(
      triggerType: fields[0] == null ? 'any_token' : fields[0] as String,
      targetTokenId: fields[1] as String?,
      targetType: fields[2] as String?,
      targetColor: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RuleTrigger obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.triggerType)
      ..writeByte(1)
      ..write(obj.targetTokenId)
      ..writeByte(2)
      ..write(obj.targetType)
      ..writeByte(3)
      ..write(obj.targetColor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuleTriggerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
