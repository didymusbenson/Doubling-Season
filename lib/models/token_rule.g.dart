// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TokenRuleAdapter extends TypeAdapter<TokenRule> {
  @override
  final int typeId = 10;

  @override
  TokenRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TokenRule(
      name: fields[0] == null ? '' : fields[0] as String,
      enabled: fields[1] == null ? true : fields[1] as bool,
      order: fields[2] == null ? 0.0 : fields[2] as double,
      trigger: fields[3] as RuleTrigger,
      outcomes:
          fields[4] == null ? [] : (fields[4] as List?)?.cast<RuleOutcome>(),
      count: fields[5] == null ? 1 : fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TokenRule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.enabled)
      ..writeByte(2)
      ..write(obj.order)
      ..writeByte(3)
      ..write(obj.trigger)
      ..writeByte(4)
      ..write(obj.outcomes)
      ..writeByte(5)
      ..write(obj.count);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
