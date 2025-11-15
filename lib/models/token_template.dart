import 'package:hive/hive.dart';
import 'item.dart';
import 'token_definition.dart';
import '../utils/constants.dart';

part 'token_template.g.dart';

@HiveType(typeId: HiveTypeIds.tokenTemplate)
class TokenTemplate extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String pt;

  @HiveField(2)
  String abilities;

  @HiveField(3)
  String colors;

  @HiveField(4)
  double order;

  @HiveField(5, defaultValue: '')
  String? _type;

  String get type => _type ?? '';
  set type(String value) {
    _type = value;
    save();
  }

  @HiveField(6)
  String? artworkUrl;

  @HiveField(7)
  String? artworkSet;

  @HiveField(8)
  List<ArtworkVariant>? artworkOptions;

  TokenTemplate({
    required this.name,
    required this.pt,
    required this.abilities,
    required this.colors,
    String type = '',
    this.order = 0.0,
    this.artworkUrl,
    this.artworkSet,
    this.artworkOptions,
  }) : _type = type;

  factory TokenTemplate.fromItem(Item item) {
    return TokenTemplate(
      name: item.name,
      pt: item.pt,
      abilities: item.abilities,
      colors: item.colors,
      type: item.type,
      order: item.order,
      artworkUrl: item.artworkUrl,
      artworkSet: item.artworkSet,
      artworkOptions: item.artworkOptions != null ? List.from(item.artworkOptions!) : null,
    );
  }

  Item toItem({int amount = 1, bool createTapped = false}) {
    return Item(
      name: name,
      pt: pt,
      abilities: abilities,
      colors: colors,
      type: type,
      amount: amount,
      tapped: createTapped ? amount : 0,
      summoningSick: 0,
      order: order, // Preserve order when loading
      artworkUrl: artworkUrl,
      artworkSet: artworkSet,
      artworkOptions: artworkOptions != null ? List.from(artworkOptions!) : null,
    );
  }
}
