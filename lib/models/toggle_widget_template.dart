import 'package:hive/hive.dart';
import 'toggle_widget.dart';
import 'token_definition.dart';
import '../utils/constants.dart';
import 'package:uuid/uuid.dart';

part 'toggle_widget_template.g.dart';

@HiveType(typeId: HiveTypeIds.toggleWidgetTemplate)
class ToggleWidgetTemplate extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String colorIdentity;

  @HiveField(2, defaultValue: null)
  String? artworkUrl;

  @HiveField(3, defaultValue: null)
  String? artworkSet;

  @HiveField(4, defaultValue: null)
  List<ArtworkVariant>? artworkOptions;

  @HiveField(5)
  String onDescription;

  @HiveField(6)
  String offDescription;

  @HiveField(7, defaultValue: null)
  String? onArtworkUrl;

  @HiveField(8, defaultValue: null)
  String? offArtworkUrl;

  @HiveField(9, defaultValue: false)
  bool isCustom;

  @HiveField(10, defaultValue: 0.0)
  double order;

  ToggleWidgetTemplate({
    required this.name,
    required this.colorIdentity,
    this.artworkUrl,
    this.artworkSet,
    this.artworkOptions,
    required this.onDescription,
    required this.offDescription,
    this.onArtworkUrl,
    this.offArtworkUrl,
    this.isCustom = false,
    this.order = 0.0,
  });

  factory ToggleWidgetTemplate.fromWidget(ToggleWidget widget) {
    return ToggleWidgetTemplate(
      name: widget.name,
      colorIdentity: widget.colorIdentity,
      artworkUrl: widget.artworkUrl,
      artworkSet: widget.artworkSet,
      artworkOptions: widget.artworkOptions != null ? List.from(widget.artworkOptions!) : null,
      onDescription: widget.onDescription,
      offDescription: widget.offDescription,
      onArtworkUrl: widget.onArtworkUrl,
      offArtworkUrl: widget.offArtworkUrl,
      isCustom: widget.isCustom,
      order: widget.order,
    );
  }

  ToggleWidget toWidget({double? customOrder}) {
    return ToggleWidget(
      widgetId: const Uuid().v4(),
      name: name,
      colorIdentity: colorIdentity,
      artworkUrl: artworkUrl,
      artworkSet: artworkSet,
      artworkOptions: artworkOptions != null ? List.from(artworkOptions!) : null,
      order: customOrder ?? order,
      createdAt: DateTime.now(),
      isActive: false, // Reset to OFF when loading
      onDescription: onDescription,
      offDescription: offDescription,
      onArtworkUrl: onArtworkUrl,
      offArtworkUrl: offArtworkUrl,
      isCustom: isCustom,
    );
  }
}
