import 'package:hive/hive.dart';
import 'token_template.dart';
import '../utils/constants.dart';

part 'deck.g.dart';

@HiveType(typeId: HiveTypeIds.deck)
class Deck extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<TokenTemplate> templates;

  Deck({
    required this.name,
    List<TokenTemplate>? templates,
  }) : templates = templates ?? [];
}
