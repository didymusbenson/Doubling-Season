import 'package:hive/hive.dart';
import '../utils/constants.dart';

part 'rule_outcome.g.dart';

@HiveType(typeId: HiveTypeIds.ruleOutcome)
class RuleOutcome {
  /// 'multiply' or 'also_create'
  @HiveField(0, defaultValue: 'multiply')
  String outcomeType;

  /// Multiplier value for 'multiply' outcome
  @HiveField(1, defaultValue: 2)
  int multiplier;

  /// Composite ID of the token to create for 'also_create' outcome
  @HiveField(2, defaultValue: null)
  String? targetTokenId;

  /// Quantity for 'also_create' outcome
  @HiveField(3, defaultValue: 1)
  int quantity;

  RuleOutcome({
    this.outcomeType = 'multiply',
    this.multiplier = 2,
    this.targetTokenId,
    this.quantity = 1,
  });
}
