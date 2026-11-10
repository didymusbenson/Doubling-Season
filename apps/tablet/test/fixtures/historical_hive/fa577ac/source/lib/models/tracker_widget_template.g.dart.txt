// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracker_widget_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackerWidgetTemplateAdapter extends TypeAdapter<TrackerWidgetTemplate> {
  @override
  final int typeId = 8;

  @override
  TrackerWidgetTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrackerWidgetTemplate(
      name: fields[0] as String,
      description: fields[1] as String,
      colorIdentity: fields[2] as String,
      artworkUrl: fields[3] as String?,
      artworkSet: fields[4] as String?,
      artworkOptions: (fields[5] as List?)?.cast<ArtworkVariant>(),
      defaultValue: fields[6] == null ? 0 : fields[6] as int,
      tapIncrement: fields[7] == null ? 1 : fields[7] as int,
      longPressIncrement: fields[8] == null ? 5 : fields[8] as int,
      hasAction: fields[9] == null ? false : fields[9] as bool,
      actionButtonText: fields[10] as String?,
      actionType: fields[11] as String?,
      isCustom: fields[12] == null ? false : fields[12] as bool,
      order: fields[13] == null ? 0.0 : fields[13] as double,
    );
  }

  @override
  void write(BinaryWriter writer, TrackerWidgetTemplate obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.colorIdentity)
      ..writeByte(3)
      ..write(obj.artworkUrl)
      ..writeByte(4)
      ..write(obj.artworkSet)
      ..writeByte(5)
      ..write(obj.artworkOptions)
      ..writeByte(6)
      ..write(obj.defaultValue)
      ..writeByte(7)
      ..write(obj.tapIncrement)
      ..writeByte(8)
      ..write(obj.longPressIncrement)
      ..writeByte(9)
      ..write(obj.hasAction)
      ..writeByte(10)
      ..write(obj.actionButtonText)
      ..writeByte(11)
      ..write(obj.actionType)
      ..writeByte(12)
      ..write(obj.isCustom)
      ..writeByte(13)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackerWidgetTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
