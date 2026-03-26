// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toggle_widget_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ToggleWidgetTemplateAdapter extends TypeAdapter<ToggleWidgetTemplate> {
  @override
  final int typeId = 9;

  @override
  ToggleWidgetTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ToggleWidgetTemplate(
      name: fields[0] as String,
      colorIdentity: fields[1] as String,
      artworkUrl: fields[2] as String?,
      artworkSet: fields[3] as String?,
      artworkOptions: (fields[4] as List?)?.cast<ArtworkVariant>(),
      onDescription: fields[5] as String,
      offDescription: fields[6] as String,
      onArtworkUrl: fields[7] as String?,
      offArtworkUrl: fields[8] as String?,
      isCustom: fields[9] == null ? false : fields[9] as bool,
      order: fields[10] == null ? 0.0 : fields[10] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ToggleWidgetTemplate obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.colorIdentity)
      ..writeByte(2)
      ..write(obj.artworkUrl)
      ..writeByte(3)
      ..write(obj.artworkSet)
      ..writeByte(4)
      ..write(obj.artworkOptions)
      ..writeByte(5)
      ..write(obj.onDescription)
      ..writeByte(6)
      ..write(obj.offDescription)
      ..writeByte(7)
      ..write(obj.onArtworkUrl)
      ..writeByte(8)
      ..write(obj.offArtworkUrl)
      ..writeByte(9)
      ..write(obj.isCustom)
      ..writeByte(10)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToggleWidgetTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
