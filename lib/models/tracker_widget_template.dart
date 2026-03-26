import 'package:hive/hive.dart';
import 'tracker_widget.dart';
import 'token_definition.dart';
import '../utils/constants.dart';
import 'package:uuid/uuid.dart';

part 'tracker_widget_template.g.dart';

@HiveType(typeId: HiveTypeIds.trackerWidgetTemplate)
class TrackerWidgetTemplate extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String description;

  @HiveField(2)
  String colorIdentity;

  @HiveField(3, defaultValue: null)
  String? artworkUrl;

  @HiveField(4, defaultValue: null)
  String? artworkSet;

  @HiveField(5, defaultValue: null)
  List<ArtworkVariant>? artworkOptions;

  @HiveField(6, defaultValue: 0)
  int defaultValue;

  @HiveField(7, defaultValue: 1)
  int tapIncrement;

  @HiveField(8, defaultValue: 5)
  int longPressIncrement;

  @HiveField(9, defaultValue: false)
  bool hasAction;

  @HiveField(10, defaultValue: null)
  String? actionButtonText;

  @HiveField(11, defaultValue: null)
  String? actionType;

  @HiveField(12, defaultValue: false)
  bool isCustom;

  @HiveField(13, defaultValue: 0.0)
  double order;

  TrackerWidgetTemplate({
    required this.name,
    required this.description,
    required this.colorIdentity,
    this.artworkUrl,
    this.artworkSet,
    this.artworkOptions,
    this.defaultValue = 0,
    this.tapIncrement = 1,
    this.longPressIncrement = 5,
    this.hasAction = false,
    this.actionButtonText,
    this.actionType,
    this.isCustom = false,
    this.order = 0.0,
  });

  factory TrackerWidgetTemplate.fromWidget(TrackerWidget widget) {
    return TrackerWidgetTemplate(
      name: widget.name,
      description: widget.description,
      colorIdentity: widget.colorIdentity,
      artworkUrl: widget.artworkUrl,
      artworkSet: widget.artworkSet,
      artworkOptions: widget.artworkOptions != null ? List.from(widget.artworkOptions!) : null,
      defaultValue: widget.defaultValue,
      tapIncrement: widget.tapIncrement,
      longPressIncrement: widget.longPressIncrement,
      hasAction: widget.hasAction,
      actionButtonText: widget.actionButtonText,
      actionType: widget.actionType,
      isCustom: widget.isCustom,
      order: widget.order,
    );
  }

  TrackerWidget toWidget({double? customOrder}) {
    return TrackerWidget(
      widgetId: const Uuid().v4(),
      name: name,
      description: description,
      colorIdentity: colorIdentity,
      artworkUrl: artworkUrl,
      artworkSet: artworkSet,
      artworkOptions: artworkOptions != null ? List.from(artworkOptions!) : null,
      order: customOrder ?? order,
      createdAt: DateTime.now(),
      currentValue: defaultValue, // Reset to default when loading
      defaultValue: defaultValue,
      tapIncrement: tapIncrement,
      longPressIncrement: longPressIncrement,
      hasAction: hasAction,
      actionButtonText: actionButtonText,
      actionType: actionType,
      isCustom: isCustom,
    );
  }
}
