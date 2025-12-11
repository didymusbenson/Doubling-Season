import 'package:hive/hive.dart';
import '../utils/constants.dart';

part 'krenko_utility.g.dart';

@HiveType(typeId: HiveTypeIds.krenkoUtility)
class KrenkoUtility extends HiveObject {
  @HiveField(0)
  String utilityId;

  @HiveField(1)
  String name;

  @HiveField(2)
  String colorIdentity;

  @HiveField(3)
  String? artworkUrl;

  @HiveField(4)
  double order;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  int krenkoPower;

  @HiveField(7)
  int nontokenGoblins;

  @HiveField(8)
  bool isCustom;

  KrenkoUtility({
    required this.utilityId,
    required this.name,
    required this.colorIdentity,
    this.artworkUrl,
    required this.order,
    required this.createdAt,
    this.krenkoPower = 3, // Krenko's base power
    this.nontokenGoblins = 1, // Krenko himself
    this.isCustom = false,
  });

  /// Calculate goblins to create based on Krenko's power
  int calculateByPower(int multiplier) {
    return krenkoPower * multiplier;
  }

  /// Calculate goblins to create based on all goblins controlled
  int calculateByGoblinsControlled(int tokenGoblinCount, int multiplier) {
    final totalGoblins = tokenGoblinCount + nontokenGoblins;
    return totalGoblins * multiplier;
  }
}
