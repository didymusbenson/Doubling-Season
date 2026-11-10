import 'package:hive/hive.dart';
import '../utils/constants.dart';

part 'rule_trigger.g.dart';

@HiveType(typeId: HiveTypeIds.ruleTrigger)
class RuleTrigger {
  /// 'specific_token', 'has_pt', 'token_type', 'color', 'any_token'
  @HiveField(0, defaultValue: 'any_token')
  String triggerType;

  /// Composite ID for specific_token trigger (name|pt|colors|type|abilities)
  @HiveField(1, defaultValue: null)
  String? targetTokenId;

  /// 'Creature', 'Artifact', 'Enchantment' for token_type trigger
  @HiveField(2, defaultValue: null)
  String? targetType;

  /// 'W', 'U', 'B', 'R', 'G' for color trigger
  @HiveField(3, defaultValue: null)
  String? targetColor;

  RuleTrigger({
    this.triggerType = 'any_token',
    this.targetTokenId,
    this.targetType,
    this.targetColor,
  });
}
