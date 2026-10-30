import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripling_table/services/table_support_service.dart';
import 'package:tripling_table/services/tablet_media_store.dart';
import 'package:tripling_table/storage/storage_namespace.dart';
import 'package:tripling_table/storage/table_repository.dart';

class _UnavailableStore extends Fake implements InAppPurchase {
  @override
  Future<bool> isAvailable() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('preview media writes never modify the production media box', () async {
    final directory = await Directory.systemTemp.createTemp('preview-media-');
    Hive.init(directory.path);
    try {
      final production = await Hive.openBox<dynamic>('tripling_table_media_v1');
      await production.put('sentinel', 'preserve');
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final reference = await TabletMediaStore.save(bytes);
      expect(await TabletMediaStore.read(reference), bytes);
      final preview = Hive.box<dynamic>(TableStorageKeys.media);
      expect(preview.containsKey(reference.substring(11)), isTrue);
      expect(production.toMap(), {'sentinel': 'preserve'});
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  }, skip: tableStorageNamespace.isEmpty);

  test('preview support reads and writes only its own preferences', () async {
    SharedPreferences.setMockInitialValues({
      'tablet_support_owned_v1': ['collector'],
      'tablet_support_heart_color': 12345,
    });
    final service = TableSupportService.forTesting(
      store: _UnavailableStore(),
      configuredProductIds: ['thanks', 'play', 'collector'],
    );
    try {
      await service.initialize();
      expect(service.owned, isEmpty);
      expect(service.heartColor, isNot(12345));
      service.owned.add('collector');
      await service.setHeartColor(67890);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(TableStorageKeys.supportColor), 67890);
      expect(prefs.getInt('tablet_support_heart_color'), 12345);
      expect(prefs.getStringList('tablet_support_owned_v1'), ['collector']);
    } finally {
      service.dispose();
    }
  }, skip: tableStorageNamespace.isEmpty);

  test('physical keys preserve production or isolate the explicit preview', () {
    const originals = [
      'tripling_season_tablet_aggregate_v1',
      'tripling_season_tablet_catalog_v1',
      'tripling_table_media_v1',
      'tablet_support_owned_v1',
      'tablet_support_heart_color',
    ];
    const actual = [
      TableStorageKeys.aggregate,
      TableStorageKeys.catalog,
      TableStorageKeys.media,
      TableStorageKeys.supportOwned,
      TableStorageKeys.supportColor,
    ];
    final prefix = tableStorageNamespace.isEmpty
        ? ''
        : '${tableStorageNamespace}__';
    expect(actual, originals.map((key) => '$prefix$key').toList());
    expect(TableRepository.boxName, actual.first);
    final generations = [
      TableRepository.boxName,
      '${TableRepository.boxName}_previous',
      '${TableRepository.boxName}_recovery',
    ];
    expect({...actual, ...generations}.length, 7);
    if (tableStorageNamespace.isNotEmpty) {
      for (final key in [...actual, ...generations]) {
        expect(key, startsWith(prefix));
        expect(originals, isNot(contains(key)));
      }
    }
  });
}
