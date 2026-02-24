// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deck.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeckAdapter extends TypeAdapter<Deck> {
  @override
  final int typeId = 2;

  @override
  Deck read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Deck(
      name: fields[0] as String,
      templates: (fields[1] as List?)?.cast<TokenTemplate>(),
      trackerWidgets: (fields[2] as List?)?.cast<TrackerWidgetTemplate>(),
      toggleWidgets: (fields[3] as List?)?.cast<ToggleWidgetTemplate>(),
      colorIdentity: fields[4] as String?,
      order: fields[5] == null ? 0.0 : fields[5] as double,
      createdAt: fields[6] as DateTime?,
      lastModifiedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Deck obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.templates)
      ..writeByte(2)
      ..write(obj.trackerWidgets)
      ..writeByte(3)
      ..write(obj.toggleWidgets)
      ..writeByte(4)
      ..write(obj.colorIdentity)
      ..writeByte(5)
      ..write(obj.order)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.lastModifiedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeckAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
