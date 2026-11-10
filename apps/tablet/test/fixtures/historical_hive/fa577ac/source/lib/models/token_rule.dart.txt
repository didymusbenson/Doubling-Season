import 'package:hive/hive.dart';
import '../utils/constants.dart';
import 'rule_trigger.dart';
import 'rule_outcome.dart';

part 'token_rule.g.dart';

@HiveType(typeId: HiveTypeIds.tokenRule)
class TokenRule extends HiveObject {
  @HiveField(0, defaultValue: '')
  String name;

  @HiveField(1, defaultValue: true)
  bool enabled;

  @HiveField(2, defaultValue: 0.0)
  double order;

  @HiveField(3)
  RuleTrigger trigger;

  @HiveField(4, defaultValue: [])
  List<RuleOutcome> outcomes;

  TokenRule({
    required this.name,
    this.enabled = true,
    this.order = 0.0,
    required this.trigger,
    List<RuleOutcome>? outcomes,
  }) : outcomes = outcomes ?? [];
}
