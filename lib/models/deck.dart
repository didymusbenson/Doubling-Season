import 'package:hive/hive.dart';
import 'token_template.dart';
import 'tracker_widget_template.dart';
import 'toggle_widget_template.dart';
import '../utils/constants.dart';

part 'deck.g.dart';

@HiveType(typeId: HiveTypeIds.deck)
class Deck extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<TokenTemplate> templates;

  @HiveField(2, defaultValue: null)
  List<TrackerWidgetTemplate>? trackerWidgets;

  @HiveField(3, defaultValue: null)
  List<ToggleWidgetTemplate>? toggleWidgets;

  Deck({
    required this.name,
    List<TokenTemplate>? templates,
    this.trackerWidgets,
    this.toggleWidgets,
  }) : templates = templates ?? [];
}
