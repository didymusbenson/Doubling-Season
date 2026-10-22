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
  const CatalogUpdate({
    this.version = 0,
    this.sha256Hash = '',
    this.size,
    this.minimumVersion,
    this.error,
  });
}

/// Shared read-only definitions; every mutable board selection stays on its seat.
class TabletCatalog extends ChangeNotifier {
  final TableController controller;
  TabletCatalog(this.controller);
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

  static const _cacheBox = 'tripling_season_tablet_catalog_v1';
  Future<Box<String>> _cache() => Hive.openBox<String>(_cacheBox);
  Future<void> load() async {
    String? cacheFailure;
    try {
      final box = await _cache();
      final stored = box.get('override');
      if (stored != null) {
        try {
          final record = jsonDecode(stored) as Map;
          final raw = record['payload'] as String;
          if (sha256.convert(utf8.encode(raw)).toString() != record['sha256']) {
            throw const FormatException('Stored catalog checksum mismatch');
          }
          _bundled = _parse(raw);
          version = record['version'] as int;
          loaded = true;
          error = null;
          notifyListeners();
          return;
        } catch (e) {
          cacheFailure =
              'Downloaded catalog could not be read; using bundled tokens. $e';
        }
      }
    } catch (e) {
      cacheFailure = 'Catalog cache unavailable; using bundled tokens. $e';
    }
    try {
      final raw = await rootBundle.loadString(
        'packages/doubling_season/assets/token_database.json',
      );
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  'packages/doubling_season/assets/token_manifest.json',
                ),
              )
              as Map;
      _bundled = _parse(raw);
      version = (manifest['version'] as num?)?.toInt() ?? 0;
      loaded = true;
      error = cacheFailure;
    } catch (e) {
      error = 'The token catalog could not be loaded: $e';
    }
    notifyListeners();
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
  }) {
    final recent = _ids('recent');
    final result = tokens
        .where(
          (t) =>
              t.matches(searchQuery: query) &&
              (category == null || t.category == category) &&
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
  Future<void> recordRecent(String id) => _library((lib) {
    final ids = _ids('recent')
      ..remove(id)
      ..insert(0, id);
    lib['recent'] = ids.take(40).toList();
  });
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
      final response = await http
          .get(Uri.parse(RemoteUrls.tokenManifestUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Server returned ${response.statusCode}');
      }
      final m = jsonDecode(response.body) as Map;
      final v = (m['version'] as num).toInt();
      final hash = m['sha256'] as String;
      if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) {
        throw const FormatException('Invalid catalog checksum');
      }
      return CatalogUpdate(
        version: v,
        sha256Hash: hash,
        size: (m['size'] as num?)?.toInt(),
        minimumVersion: m['min_app_version'] as String?,
      );
    } catch (e) {
      return CatalogUpdate(error: 'Update check failed: $e');
    }
  }

  Future<void> applyUpdate(CatalogUpdate update) async {
    if (update.error != null) throw StateError(update.error!);
    if (update.version <= version) return;
    // Catalog format compatibility follows the shared phone app, whose schema we reuse.
    if (update.minimumVersion != null &&
        _compareVersion(update.minimumVersion!, '1.11.0') > 0) {
      throw StateError(
        'This catalog requires a newer Tripling Season edition (${update.minimumVersion}).',
      );
    }
    final response = await http
        .get(Uri.parse(RemoteUrls.tokenDatabaseUrl))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError('Download failed (${response.statusCode})');
    }
    final bytes = response.bodyBytes;
    if (update.size != null && bytes.length != update.size) {
      throw const FormatException('Catalog size verification failed');
    }
    if (sha256.convert(bytes).toString() != update.sha256Hash.toLowerCase()) {
      throw const FormatException('Catalog integrity verification failed');
    }
    final raw = utf8.decode(bytes);
    final parsed = _parse(raw);
    final box = await _cache();
    // A catalog generation is one independently persisted key; game saves never
    // copy, journal or archive these shared definition bytes.
    await box.put(
      'override',
      jsonEncode({
        'version': update.version,
        'sha256': update.sha256Hash.toLowerCase(),
        'payload': raw,
      }),
    );
    await box.flush();
    _bundled = parsed;
    version = update.version;
    notifyListeners();
  }

  Future<void> revertToBundled() async {
    final box = await _cache();
    await box.delete('override');
    await box.flush();
    await load();
  }

  static int _compareVersion(String a, String b) {
    final x = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final y = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }
}
