import 'package:hive/hive.dart';
import '../utils/constants.dart';

part 'token_counter.g.dart';

@HiveType(typeId: HiveTypeIds.tokenCounter)
class TokenCounter extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int amount;

  TokenCounter({
    required this.name,
    this.amount = 1,
  });
}
