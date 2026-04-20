import 'package:flutter/material.dart';

enum HeartStyleType {
  solid,
  gradient2,
  gradient3,
}

/// A heart badge style keyed to MTG color combinations.
///
/// The 26 factories below cover the five mono colors, ten guilds, five shards,
/// five wedges, and a default rainbow. Colors are the official card-frame dark
/// values from magic.wizards.com so the badge reads as Magic-themed.
class HeartStyle {
  static const Color _magicWhite = Color(0xFFF9FAF4);
  static const Color _magicBlue = Color(0xFF0E68AB);
  static const Color _magicBlack = Color(0xFF150B00);
  static const Color _magicRed = Color(0xFFD3202A);
  static const Color _magicGreen = Color(0xFF00733E);

  final String id;
  final String name;
  final HeartStyleType type;
  final List<Color> colors;

  const HeartStyle({
    required this.id,
    required this.name,
    required this.type,
    required this.colors,
  });

  factory HeartStyle.white() => const HeartStyle(
        id: 'white',
        name: 'White',
        type: HeartStyleType.solid,
        colors: [_magicWhite],
      );

  factory HeartStyle.blue() => const HeartStyle(
        id: 'blue',
        name: 'Blue',
        type: HeartStyleType.solid,
        colors: [_magicBlue],
      );

  factory HeartStyle.black() => const HeartStyle(
        id: 'black',
        name: 'Black',
        type: HeartStyleType.solid,
        colors: [_magicBlack],
      );

  factory HeartStyle.red() => const HeartStyle(
        id: 'red',
        name: 'Red',
        type: HeartStyleType.solid,
        colors: [_magicRed],
      );

  factory HeartStyle.green() => const HeartStyle(
        id: 'green',
        name: 'Green',
        type: HeartStyleType.solid,
        colors: [_magicGreen],
      );

  factory HeartStyle.azorius() => const HeartStyle(
        id: 'azorius',
        name: 'Azorius',
        type: HeartStyleType.gradient2,
        colors: [_magicWhite, _magicBlue],
      );

  factory HeartStyle.orzhov() => const HeartStyle(
        id: 'orzhov',
        name: 'Orzhov',
        type: HeartStyleType.gradient2,
        colors: [_magicWhite, _magicBlack],
      );

  factory HeartStyle.izzet() => const HeartStyle(
        id: 'izzet',
        name: 'Izzet',
        type: HeartStyleType.gradient2,
        colors: [_magicBlue, _magicRed],
      );

  factory HeartStyle.dimir() => const HeartStyle(
        id: 'dimir',
        name: 'Dimir',
        type: HeartStyleType.gradient2,
        colors: [_magicBlue, _magicBlack],
      );

  factory HeartStyle.rakdos() => const HeartStyle(
        id: 'rakdos',
        name: 'Rakdos',
        type: HeartStyleType.gradient2,
        colors: [_magicBlack, _magicRed],
      );

  factory HeartStyle.golgari() => const HeartStyle(
        id: 'golgari',
        name: 'Golgari',
        type: HeartStyleType.gradient2,
        colors: [_magicBlack, _magicGreen],
      );

  factory HeartStyle.gruul() => const HeartStyle(
        id: 'gruul',
        name: 'Gruul',
        type: HeartStyleType.gradient2,
        colors: [_magicRed, _magicGreen],
      );

  factory HeartStyle.boros() => const HeartStyle(
        id: 'boros',
        name: 'Boros',
        type: HeartStyleType.gradient2,
        colors: [_magicRed, _magicWhite],
      );

  factory HeartStyle.selesnya() => const HeartStyle(
        id: 'selesnya',
        name: 'Selesnya',
        type: HeartStyleType.gradient2,
        colors: [_magicGreen, _magicWhite],
      );

  factory HeartStyle.simic() => const HeartStyle(
        id: 'simic',
        name: 'Simic',
        type: HeartStyleType.gradient2,
        colors: [_magicGreen, _magicBlue],
      );

  factory HeartStyle.esper() => const HeartStyle(
        id: 'esper',
        name: 'Esper',
        type: HeartStyleType.gradient3,
        colors: [_magicWhite, _magicBlue, _magicBlack],
      );

  factory HeartStyle.grixis() => const HeartStyle(
        id: 'grixis',
        name: 'Grixis',
        type: HeartStyleType.gradient3,
        colors: [_magicBlue, _magicBlack, _magicRed],
      );

  factory HeartStyle.jund() => const HeartStyle(
        id: 'jund',
        name: 'Jund',
        type: HeartStyleType.gradient3,
        colors: [_magicBlack, _magicRed, _magicGreen],
      );

  factory HeartStyle.naya() => const HeartStyle(
        id: 'naya',
        name: 'Naya',
        type: HeartStyleType.gradient3,
        colors: [_magicRed, _magicGreen, _magicWhite],
      );

  factory HeartStyle.bant() => const HeartStyle(
        id: 'bant',
        name: 'Bant',
        type: HeartStyleType.gradient3,
        colors: [_magicGreen, _magicWhite, _magicBlue],
      );

  factory HeartStyle.abzan() => const HeartStyle(
        id: 'abzan',
        name: 'Abzan',
        type: HeartStyleType.gradient3,
        colors: [_magicWhite, _magicBlack, _magicGreen],
      );

  factory HeartStyle.jeskai() => const HeartStyle(
        id: 'jeskai',
        name: 'Jeskai',
        type: HeartStyleType.gradient3,
        colors: [_magicBlue, _magicRed, _magicWhite],
      );

  factory HeartStyle.sultai() => const HeartStyle(
        id: 'sultai',
        name: 'Sultai',
        type: HeartStyleType.gradient3,
        colors: [_magicBlack, _magicGreen, _magicBlue],
      );

  factory HeartStyle.mardu() => const HeartStyle(
        id: 'mardu',
        name: 'Mardu',
        type: HeartStyleType.gradient3,
        colors: [_magicRed, _magicWhite, _magicBlack],
      );

  factory HeartStyle.temur() => const HeartStyle(
        id: 'temur',
        name: 'Temur',
        type: HeartStyleType.gradient3,
        colors: [_magicGreen, _magicBlue, _magicRed],
      );

  factory HeartStyle.rainbow() => const HeartStyle(
        id: 'rainbow',
        name: 'Rainbow',
        type: HeartStyleType.gradient3,
        colors: [
          _magicRed,
          Color(0xFFFFD700),
          _magicBlue,
        ],
      );

  static List<HeartStyle> getAllStyles() {
    return [
      HeartStyle.white(),
      HeartStyle.blue(),
      HeartStyle.black(),
      HeartStyle.red(),
      HeartStyle.green(),
      HeartStyle.azorius(),
      HeartStyle.orzhov(),
      HeartStyle.izzet(),
      HeartStyle.dimir(),
      HeartStyle.rakdos(),
      HeartStyle.golgari(),
      HeartStyle.gruul(),
      HeartStyle.boros(),
      HeartStyle.selesnya(),
      HeartStyle.simic(),
      HeartStyle.esper(),
      HeartStyle.grixis(),
      HeartStyle.jund(),
      HeartStyle.naya(),
      HeartStyle.bant(),
      HeartStyle.abzan(),
      HeartStyle.jeskai(),
      HeartStyle.sultai(),
      HeartStyle.mardu(),
      HeartStyle.temur(),
      HeartStyle.rainbow(),
    ];
  }
}
