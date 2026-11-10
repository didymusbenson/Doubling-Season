import '../storage/storage_namespace.dart';
import 'catalog_compatibility.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/utils/constants.dart';
import 'package:doubling_season/utils/decklist_parser.dart';
import '../domain/table_controller.dart';

class CatalogUpdate {
  final int version;
  final String sha256Hash;
  final int? size;
  final String? minimumVersion;
  final String? error;
  final int schemaVersion;
  final int minimumReaderVersion;
  const CatalogUpdate({
    this.version = 0,
    this.sha256Hash = '',
    this.size,
    this.minimumVersion,
    this.error,
    this.schemaVersion = CatalogCompatibility.schemaVersion,
    this.minimumReaderVersion = CatalogCompatibility.readerVersion,
  });

  factory CatalogUpdate.fromManifest(Map<String, dynamic> manifest) {
    final update = CatalogUpdate(
      version: CatalogCompatibility.positiveInteger(
        manifest['version'],
        'version',
      ),
      sha256Hash: manifest['sha256'] as String,
      size: manifest['size'] == null
          ? null
          : CatalogCompatibility.positiveInteger(manifest['size'], 'size'),
      minimumVersion: manifest['min_app_version'] as String?,
      schemaVersion: manifest.containsKey('schema_version')
          ? CatalogCompatibility.positiveInteger(
              manifest['schema_version'],
              'schema_version',
            )
          : 1,
      minimumReaderVersion: manifest.containsKey('min_catalog_reader_version')
          ? CatalogCompatibility.positiveInteger(
              manifest['min_catalog_reader_version'],
              'min_catalog_reader_version',
            )
          : 1,
    );
    update.validate();
    return update;
  }

  void validate() {
    if (error != null) throw StateError(error!);
    CatalogCompatibility.positiveInteger(version, 'version');
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256Hash)) {
      throw const FormatException('Invalid catalog checksum');
    }
    if (size != null &&
        (size! <= 0 || size! > CatalogCompatibility.maximumPayloadBytes)) {
      throw const FormatException('Invalid or oversized catalog size');
    }
    CatalogCompatibility.validate(
      schema: schemaVersion,
      minimumReader: minimumReaderVersion,
      legacyMinimum: minimumVersion,
    );
  }

  Map<String, dynamic> toManifest() => {
    'version': version,
    'sha256': sha256Hash.toLowerCase(),
    if (size != null) 'size': size,
    if (minimumVersion != null) 'min_app_version': minimumVersion,
    'schema_version': schemaVersion,
    'min_catalog_reader_version': minimumReaderVersion,
  };
}

/// Shared read-only definitions; every mutable board selection stays on its seat.
class TabletCatalog extends ChangeNotifier {
  final TableController controller;
  final Future<http.Response> Function(Uri) _get;
  final AssetBundle _assets;
  final Future<Box<String>> Function() _openCache;
  Future<void> _pending = Future<void>.value();

  TabletCatalog(this.controller)
    : _get = http.get,
      _assets = rootBundle,
      _openCache = (() => Hive.openBox<String>(TableStorageKeys.catalog));

  TabletCatalog.forTesting(
    this.controller, {
    required http.Client client,
    required AssetBundle assets,
    required Future<Box<String>> Function() openCache,
  }) : _get = client.get,
       _assets = assets,
       _openCache = openCache;

  // Re-check versions inside the queue: late downloads cannot replace a newer
  // generation, and load/revert cannot race an in-flight apply.
  Future<void> _serialize(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  List<TokenDefinition> _bundled = [];
  bool loaded = false;
  String? error;
  int version = 0;
  List<TokenDefinition> get tokens => [...customTokens, ..._bundled];
  List<TokenDefinition> get customTokens =>
      ((controller.state.library['customTokens'] as List?) ?? [])
          .map(
            (e) =>
                TokenDefinition.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
  List<String> _ids(String field) =>
      ((controller.state.library[field] as List?) ?? [])
          .map((e) => e.toString())
          .toList();
  bool isFavorite(String id) => _ids('favorites').contains(id);

  Future<void> load() => _serialize(_load);

  Future<void> _load() async {
    List<TokenDefinition>? selected;
    var selectedVersion = 0;
    final warnings = <String>[];
    try {
      final bundled = await _readBundled();
      selected = bundled.tokens;
      selectedVersion = bundled.update.version;
    } catch (failure) {
      warnings.add('Bundled catalog unavailable: $failure');
    }
    try {
      final box = await _openCache();
      for (final key in ['override', 'previous']) {
        final stored = box.get(key);
        if (stored == null) continue;
        try {
          final candidate = _decodeRecord(stored);
          if (selected == null || candidate.update.version > selectedVersion) {
            selected = candidate.tokens;
            selectedVersion = candidate.update.version;
          }
        } catch (failure) {
          // Keep unreadable/future records for recovery. Never clear storage
          // merely to fall back to bundled or a prior compatible generation.
          warnings.add(
            'Downloaded catalog ($key) was retained but not used: $failure',
          );
        }
      }
    } catch (failure) {
      warnings.add('Catalog cache unavailable: $failure');
    }
    if (loaded && version > selectedVersion) {
      selected = _bundled;
      selectedVersion = version;
    }
    if (selected != null) {
      _bundled = selected;
      version = selectedVersion;
      loaded = true;
    }
    error = warnings.isEmpty ? null : warnings.join(' ');
    notifyListeners();
  }

  Future<({CatalogUpdate update, List<TokenDefinition> tokens})>
  _readBundled() async {
    final raw = await _assets.loadString(
      'packages/doubling_season/assets/token_database.json',
    );
    final update = CatalogUpdate.fromManifest(
      Map<String, dynamic>.from(
        jsonDecode(
              await _assets.loadString(
                'packages/doubling_season/assets/token_manifest.json',
              ),
            )
            as Map,
      ),
    );
    return (update: update, tokens: _validatePayload(raw, update));
  }

  List<TokenDefinition> _validatePayload(String raw, CatalogUpdate update) {
    update.validate();
    final bytes = utf8.encode(raw);
    if (bytes.length > CatalogCompatibility.maximumPayloadBytes ||
        (update.size != null && bytes.length != update.size)) {
      throw const FormatException('Catalog size verification failed');
    }
    if (sha256.convert(bytes).toString() != update.sha256Hash.toLowerCase()) {
      throw const FormatException('Catalog integrity verification failed');
    }
    return _parse(raw);
  }

  ({CatalogUpdate update, List<TokenDefinition> tokens}) _decodeRecord(
    String stored,
  ) {
    final record = Map<String, dynamic>.from(jsonDecode(stored) as Map);
    // Records written before this contract have no record version or reader
    // metadata. They are exactly the historical v1 list/cache representation.
    if (record.containsKey('record_version') &&
        (record['record_version'] is! int || record['record_version'] != 1)) {
      throw const FormatException('Unsupported catalog cache record version');
    }
    final update = CatalogUpdate.fromManifest(record);
    return (
      update: update,
      tokens: _validatePayload(record['payload'] as String, update),
    );
  }

  List<TokenDefinition> _parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.isEmpty) {
      throw const FormatException('Empty or invalid token catalog');
    }
    return decoded.map((e) {
      final token = TokenDefinition.fromJson(
        Map<String, dynamic>.from(e as Map),
      );
      if (token.name.trim().isEmpty) {
        throw const FormatException('Token name is missing');
      }
      return token;
    }).toList();
  }

  List<TokenDefinition> search(
    String query, {
    String tab = 'all',
    Category? category,
    Set<String> colors = const {},
  }) {
    final recent = _ids('recent');
    final result = tokens
        .where(
          (t) =>
              t.matches(searchQuery: query) &&
              (category == null || t.category == category) &&
              _matchesColors(t, colors) &&
              (tab != 'favorites' || isFavorite(t.id)) &&
              (tab != 'recent' || recent.contains(t.id)) &&
              (tab != 'custom' || customTokens.any((c) => c.id == t.id)),
        )
        .toList();
    if (tab == 'recent') {
      result.sort(
        (a, b) => recent.indexOf(a.id).compareTo(recent.indexOf(b.id)),
      );
    } else {
      result.sort((a, b) => b.popularity.compareTo(a.popularity));
    }
    return result;
  }

  // Match the original catalog's exact color-identity filter, including C.
  bool _matchesColors(TokenDefinition token, Set<String> colors) {
    if (colors.isEmpty) return true;
    if (colors.contains('C')) return token.colors.isEmpty;
    final identity = token.colors.split('').toSet();
    return identity.length == colors.length && identity.containsAll(colors);
  }

  TokenDefinition? byId(String id) {
    for (final t in tokens) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _library(void Function(Map<String, dynamic>) edit) async {
    final ok = await controller.modifyLibrary((state) => edit(state.library));
    if (!ok) {
      throw StateError(
        controller.error ?? 'Catalog preference could not be saved',
      );
    }
    notifyListeners();
  }

  Future<void> favorite(String id) => _library((lib) {
    final ids = _ids('favorites');
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    lib['favorites'] = ids;
  });
  Future<void> recordRecent(String id) async {
    try {
      await _library((lib) {
        final ids = _ids('recent')
          ..remove(id)
          ..insert(0, id);
        lib['recent'] = ids.take(40).toList();
      });
    } catch (failure) {
      // Gameplay already committed. Do not report a failed creation or invite a
      // duplicate retry merely because its incidental recent-search preference failed.
      error = 'Tokens were saved, but Recent could not be updated: $failure';
      notifyListeners();
    }
  }

  Future<void> saveCustom(TokenDefinition definition) => _library((lib) {
    if (definition.name.trim().isEmpty) {
      throw const FormatException('A token needs a name');
    }
    final all = customTokens
        .where((t) => t.id != definition.id)
        .map((t) => t.toJson())
        .toList();
    all.add(definition.toJson());
    lib['customTokens'] = all;
  });
  Future<void> deleteCustom(String id) => _library((lib) {
    lib['customTokens'] = customTokens
        .where((t) => t.id != id)
        .map((t) => t.toJson())
        .toList();
  });
  List<TokenDefinition> matchDecklist(String text) {
    final names = DecklistParser.parse(
      text,
    ).cardNames.map((n) => n.toLowerCase()).toSet();
    return tokens
        .where(
          (t) => t.reverseRelated.any((n) => names.contains(n.toLowerCase())),
        )
        .toList();
  }

  Future<CatalogUpdate> checkForUpdate() async {
    try {
      final response = await _get(
        Uri.parse(RemoteUrls.tokenManifestUrl),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Server returned ${response.statusCode}');
      }
      return CatalogUpdate.fromManifest(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    } catch (e) {
      return CatalogUpdate(error: 'Update check failed: $e');
    }
  }

  Future<void> applyUpdate(CatalogUpdate update) => _serialize(() async {
    update.validate();
    if (update.version <= version) return;
    final box = await _openCache();
    final previous = box.get('override');
    if (previous != null) {
      // A downgraded client must not overwrite an unknown future cache. A
      // damaged record is retained too; explicit Revert remains available.
      final existing = _decodeRecord(previous);
      if (existing.update.version >= update.version) {
        // A prior flush may have failed after put changed Hive's read cache.
        // Retry must establish durability, then activate the verified record.
        await box.flush();
        if (box.get('override') != previous) {
          throw StateError('Catalog retry readback failed');
        }
        _bundled = existing.tokens;
        version = existing.update.version;
        loaded = true;
        error = null;
        notifyListeners();
        return;
      }
    }
    final retained = box.get('previous');
    if (retained != null) _decodeRecord(retained);
    final response = await _get(
      Uri.parse(RemoteUrls.tokenDatabaseUrl),
    ).timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError('Download failed (${response.statusCode})');
    }
    final raw = utf8.decode(response.bodyBytes);
    final parsed = _validatePayload(raw, update);
    final encoded = jsonEncode({
      ...update.toManifest(),
      'record_version': 1,
      'payload': raw,
    });
    // Retain the last acknowledged generation before replacing the current
    // one. Store metadata with the bytes so reopening checks compatibility too.
    if (previous != null) {
      await box.put('previous', previous);
      await box.flush();
      if (box.get('previous') != previous) {
        throw StateError('Previous catalog readback failed');
      }
    }
    await box.put('override', encoded);
    await box.flush();
    if (box.get('override') != encoded) {
      throw StateError('Catalog readback failed');
    }
    _decodeRecord(box.get('override')!);
    _bundled = parsed;
    version = update.version;
    loaded = true;
    error = null;
    notifyListeners();
  });

  Future<void> revertToBundled() => _serialize(() async {
    // Verify a usable replacement before discarding downloaded generations.
    final bundled = await _readBundled();
    final box = await _openCache();
    // This is the existing explicit user-selected revert, never automatic
    // cleanup during load/failure. Both downloaded generations must be removed
    // or the previous one would reactivate on the next offline launch.
    await box.deleteAll(['override', 'previous']);
    await box.flush();
    _bundled = bundled.tokens;
    version = bundled.update.version;
    loaded = true;
    error = null;
    notifyListeners();
  });
}
