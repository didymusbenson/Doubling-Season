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
    );
  }

  @override
  void write(BinaryWriter writer, Deck obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.templates)
      ..writeByte(2)
      ..write(obj.trackerWidgets)
      ..writeByte(3)
      ..write(obj.toggleWidgets);
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
