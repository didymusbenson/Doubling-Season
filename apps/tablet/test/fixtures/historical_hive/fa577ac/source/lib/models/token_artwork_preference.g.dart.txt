// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_artwork_preference.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TokenArtworkPreferenceAdapter
    extends TypeAdapter<TokenArtworkPreference> {
  @override
  final int typeId = 5;

  @override
  TokenArtworkPreference read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TokenArtworkPreference(
      tokenIdentity: fields[0] as String,
      lastUsedArtwork: fields[1] as String?,
      customArtworkPath: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TokenArtworkPreference obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.tokenIdentity)
      ..writeByte(1)
      ..write(obj.lastUsedArtwork)
      ..writeByte(2)
      ..write(obj.customArtworkPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenArtworkPreferenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
