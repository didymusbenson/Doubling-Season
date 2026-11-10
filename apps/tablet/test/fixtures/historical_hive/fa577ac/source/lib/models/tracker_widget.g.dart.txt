// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracker_widget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackerWidgetAdapter extends TypeAdapter<TrackerWidget> {
  @override
  final int typeId = 6;

  @override
  TrackerWidget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrackerWidget(
      widgetId: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      colorIdentity: fields[3] as String,
      artworkUrl: fields[4] as String?,
      order: fields[5] as double,
      createdAt: fields[6] as DateTime,
      currentValue: fields[7] as int,
      defaultValue: fields[8] as int,
      tapIncrement: fields[9] as int,
      longPressIncrement: fields[10] as int,
      isCustom: fields[11] as bool,
      hasAction: fields[12] == null ? false : fields[12] as bool,
      actionButtonText: fields[13] as String?,
      actionType: fields[14] as String?,
      artworkSet: fields[15] as String?,
      artworkOptions: (fields[16] as List?)?.cast<ArtworkVariant>(),
    );
  }

  @override
  void write(BinaryWriter writer, TrackerWidget obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.widgetId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.colorIdentity)
      ..writeByte(4)
      ..write(obj.artworkUrl)
      ..writeByte(5)
      ..write(obj.order)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.currentValue)
      ..writeByte(8)
      ..write(obj.defaultValue)
      ..writeByte(9)
      ..write(obj.tapIncrement)
      ..writeByte(10)
      ..write(obj.longPressIncrement)
      ..writeByte(11)
      ..write(obj.isCustom)
      ..writeByte(12)
      ..write(obj.hasAction)
      ..writeByte(13)
      ..write(obj.actionButtonText)
      ..writeByte(14)
      ..write(obj.actionType)
      ..writeByte(15)
      ..write(obj.artworkSet)
      ..writeByte(16)
      ..write(obj.artworkOptions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackerWidgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
