import 'package:hive/hive.dart';
import 'item.dart';
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

  TokenTemplate({
    required this.name,
    required this.pt,
    required this.abilities,
    required this.colors,
    String type = '',
    this.order = 0.0,
  }) : _type = type;

  factory TokenTemplate.fromItem(Item item) {
    return TokenTemplate(
      name: item.name,
      pt: item.pt,
      abilities: item.abilities,
      colors: item.colors,
      type: item.type,
      order: item.order,
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
    );
  }
}
