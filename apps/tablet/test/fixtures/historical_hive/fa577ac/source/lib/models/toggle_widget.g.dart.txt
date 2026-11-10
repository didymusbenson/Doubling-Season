// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toggle_widget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ToggleWidgetAdapter extends TypeAdapter<ToggleWidget> {
  @override
  final int typeId = 7;

  @override
  ToggleWidget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ToggleWidget(
      widgetId: fields[0] as String,
      name: fields[1] as String,
      colorIdentity: fields[2] as String,
      artworkUrl: fields[3] as String?,
      order: fields[4] as double,
      createdAt: fields[5] as DateTime,
      isActive: fields[6] as bool,
      onDescription: fields[7] as String,
      offDescription: fields[8] as String,
      onArtworkUrl: fields[9] as String?,
      offArtworkUrl: fields[10] as String?,
      isCustom: fields[11] as bool,
      artworkSet: fields[12] as String?,
      artworkOptions: (fields[13] as List?)?.cast<ArtworkVariant>(),
    );
  }

  @override
  void write(BinaryWriter writer, ToggleWidget obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.widgetId)
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
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.onDescription)
      ..writeByte(8)
      ..write(obj.offDescription)
      ..writeByte(9)
      ..write(obj.onArtworkUrl)
      ..writeByte(10)
      ..write(obj.offArtworkUrl)
      ..writeByte(11)
      ..write(obj.isCustom)
      ..writeByte(12)
      ..write(obj.artworkSet)
      ..writeByte(13)
      ..write(obj.artworkOptions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToggleWidgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
