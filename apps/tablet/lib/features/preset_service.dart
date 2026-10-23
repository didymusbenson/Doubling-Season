import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:doubling_season/database/widget_database.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/utils/decklist_parser.dart';
import '../domain/table_state.dart';
import '../domain/table_controller.dart';
import '../services/tablet_catalog.dart';
import '../services/tablet_media_store.dart';
import 'board_service.dart';

/// Reusable zero-state setup library, separate from active games and archives.
class PresetService {
  final TableController controller;
  final TabletCatalog catalog;
  PresetService(this.controller, this.catalog);
  List<Map<String, dynamic>> get presets => controller.state.decks;
  Map<String, dynamic> _preset(String id) => presets.firstWhere(
    (d) => d['id'] == id,
    orElse: () => throw StateError('This setup no longer exists'),
  );
  Future<void> _library(void Function(TabletState) edit) async {
    if (!await controller.modifyLibrary(edit)) {
      throw StateError(
        controller.error ?? 'The setup library could not be saved',
      );
    }
  }

  Map<String, dynamic> _tokenTemplate(TokenState t) => {
    'name': t.name,
    'pt': t.pt,
    'abilities': t.abilities,
    'colors': t.colors,
    'type': t.type,
    'artworkUrl': t.artworkUrl,
    'artworkSet': t.artworkSet,
    'artworkOptions': t.artworkOptions,
  };
  Map<String, dynamic> _utilityTemplate(UtilityState u) => {
    'kind': u.kind,
    'name': u.name,
    'description': u.description,
    'colors': u.colors,
    'defaultValue': u.defaultValue,
    'visible': u.visible,
    'artworkUrl': u.artworkUrl,
    'configuration': u.configuration,
  };
  Future<Map<String, dynamic>> save(
    String playerId,
    String name, {
    String? imageUrl,
  }) async {
    if (name.trim().isEmpty) {
      throw const FormatException('Give the setup a name');
    }
    final p = controller.player(playerId);
    final identities = <String>{};
    final tokens = <Map<String, dynamic>>[];
    for (final t in p.tokens) {
      if (identities.add('${t.definitionId}|${t.artworkUrl}')) {
        tokens.add(_tokenTemplate(t));
      }
    }
    final preset = {
      'id': newEntityId(),
      'name': name.trim(),
      'revision': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'imageUrl': imageUrl,
      'tokens': tokens,
      'utilities': p.utilities.map(_utilityTemplate).toList(),
    };
    final immutable = cloneJson(preset);
    await _library((s) => s.decks.add(immutable));
    return immutable;
  }

  Future<void> rename(String id, String name) async {
    if (name.trim().isEmpty) {
      throw const FormatException('Give the setup a name');
    }
    await _library((s) {
      final d = s.decks.firstWhere((d) => d['id'] == id);
      d['name'] = name.trim();
      d['revision'] = (d['revision'] as int? ?? 0) + 1;
    });
  }

  Future<void> delete(String id) =>
      _library((s) => s.decks.removeWhere((d) => d['id'] == id));
  Future<void> load(
    String playerId,
    String presetId, {
    bool append = false,
    bool applyImage = false,
    BoardScope? captured,
  }) async {
    final selected = cloneJson(_preset(presetId));
    final scope = captured ?? BoardService(controller, catalog).scope(playerId);
    final ok = await controller.updateState(
      '${append ? 'Append' : 'Load'} setup: ${selected['name']}',
      (state) {
        if (applyImage && selected['imageUrl'] != null) {
          final p = state.session.player(playerId);
          state.profiles
                  .firstWhere((profile) => profile.id == p.seatId)
                  .artworkUrl =
              selected['imageUrl'] as String;
        }
        final s = state.session;
        final p = s.player(playerId);
        if (!append) {
          p.tokens.clear();
          p.utilities.clear();
          p.artPreferences.clear();
          p.generation++;
        }
        for (final raw in selected['tokens'] as List? ?? []) {
          final m = Map<String, dynamic>.from(raw as Map);
          final d = TokenDefinition.fromJson({
            ...m,
            'artwork': m['artworkOptions'] ?? [],
          });
          final t = TokenState(
            id: newEntityId(),
            definitionId: d.id,
            name: d.name,
            pt: d.pt,
            colors: d.colors,
            type: d.type,
            abilities: d.abilities,
            artworkUrl: m['artworkUrl'] as String?,
            artworkSet: m['artworkSet'] as String?,
            artworkOptions: d.artwork.map((a) => a.toJson()).toList(),
          );
          p.tokens.add(t);
          if (t.artworkUrl != null) {
            p.artPreferences.putIfAbsent(t.definitionId, () => t.artworkUrl!);
          }
        }
        for (final raw in selected['utilities'] as List? ?? []) {
          final m = Map<String, dynamic>.from(raw as Map);
          final kind = m['kind'] as String? ?? 'custom_tracker';
          // Bound utility projections must never introduce a second authoritative pool.
          if ({
                'mana_pool',
                'storm_count',
                'life_total',
                'poison_counters',
                'energy_counters',
                'experience_counters',
                'radiation_counters',
                'citys_blessing',
              }.contains(kind) &&
              p.utilities.any((u) => u.kind == kind)) {
            continue;
          }
          p.utilities.add(
            UtilityState(
              id: newEntityId(),
              kind: kind,
              name: m['name'] as String? ?? 'Utility',
              description: m['description'] as String? ?? '',
              colors: m['colors'] as String? ?? '',
              value: m['defaultValue'] as int? ?? 0,
              defaultValue: m['defaultValue'] as int? ?? 0,
              visible: m['visible'] as bool? ?? true,
              artworkUrl: m['artworkUrl'] as String?,
              configuration: Map<String, dynamic>.from(
                m['configuration'] as Map? ?? {},
              ),
            ),
          );
        }
      },
      recordHistory: true,
      playerId: playerId,
      expectedSessionId: scope.sessionId,
      expectedGeneration: scope.generation,
      expectedPlayerGeneration: scope.playerGeneration,
    );
    if (!ok) {
      throw StateError(controller.error ?? 'Setup load could not be saved');
    }
  }

  Future<Map<String, dynamic>> importJson(String text) async {
    final data = jsonDecode(text);
    if (data is! Map) {
      throw const FormatException('Expected a setup JSON object');
    }
    final version = data['schemaVersion'];
    Map<String, dynamic> preset;
    if (version == 4 && data['product'] == 'tripling-table') {
      preset = cloneJson(Map<String, dynamic>.from(data['preset'] as Map));
      _validatePreset(preset);
      await _importMedia(preset, data['assets']);
    } else {
      if (version is! int || version < 1 || version > 3) {
        throw const FormatException(
          'Supported setup schemas are phone 1–3 and tablet 4',
        );
      }
      final deck = data['deck'];
      if (deck is! Map) throw const FormatException('Missing deck data');
      final tokenMaps =
          (deck['templates'] as List? ?? [])
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList()
            ..sort(_compareOrder);
      final utilities = <Map<String, dynamic>>[];
      for (final raw in deck['trackerWidgets'] as List? ?? []) {
        final m = Map<String, dynamic>.from(raw as Map);
        utilities.add(_phoneUtility(m, false));
      }
      for (final raw in deck['toggleWidgets'] as List? ?? []) {
        final m = Map<String, dynamic>.from(raw as Map);
        utilities.add(_phoneUtility(m, true));
      }
      utilities.sort(_compareOrder);
      preset = {
        'name': deck['name'] as String? ?? 'Imported setup',
        'tokens': tokenMaps,
        'utilities': utilities,
        'imageUrl': deck['customArtworkUrl'],
      };
      _validatePreset(preset);
    }
    preset['warnings'] = [
      if (jsonEncode(preset).contains('file://'))
        'Local artwork files were referenced by this setup but are not included. Upload those images on this device.',
    ];
    preset['id'] = newEntityId();
    preset['revision'] = 1;
    preset['createdAt'] = DateTime.now().toUtc().toIso8601String();
    await _library((s) => s.decks.add(preset));
    return preset;
  }

  static int _compareOrder(Map<String, dynamic> a, Map<String, dynamic> b) =>
      ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0);
  Map<String, dynamic> _phoneUtility(Map<String, dynamic> m, bool toggle) {
    String? kind = m['actionType'] as String?;
    // Custom identity wins over an editable name when legacy exports omit it.
    if (kind == null && m['isCustom'] == true) {
      kind = toggle ? 'custom_toggle' : 'custom_tracker';
    }
    if (kind == null) {
      final db = WidgetDatabase();
      for (final d in db.filteredWidgets) {
        if (d.name == m['name']) {
          kind = d.id;
          break;
        }
      }
      db.dispose();
    }
    kind ??= toggle ? 'custom_toggle' : 'custom_tracker';
    return {
      'kind': kind,
      'name': m['name'] ?? 'Utility',
      'description': m[toggle ? 'onDescription' : 'description'] ?? '',
      'colors': m['colorIdentity'] ?? '',
      'defaultValue': m['defaultValue'] ?? 0,
      'visible': true,
      'artworkUrl': m['artworkUrl'],
      'order': m['order'] ?? 0,
      'configuration': {...m, 'type': toggle ? 'toggle' : 'tracker'},
    };
  }

  void _validatePreset(Map<String, dynamic> p) {
    if ((p['name'] as String? ?? '').trim().isEmpty) {
      throw const FormatException('Setup name is missing');
    }
    if (p['tokens'] is! List || p['utilities'] is! List) {
      throw const FormatException('Setup token/utility lists are missing');
    }
    for (final raw in p['tokens'] as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      if ((m['name'] as String? ?? '').trim().isEmpty) {
        throw const FormatException('A token name is missing');
      }
    }
    for (final raw in p['utilities'] as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      if ((m['name'] as String? ?? '').trim().isEmpty) {
        throw const FormatException('A utility name is missing');
      }
      if ((m['defaultValue'] as int? ?? 0) < 0) {
        throw const FormatException('Invalid utility default');
      }
    }
  }

  List<String> exportWarnings(String id, {bool phoneCompatible = false}) {
    final p = _preset(id);
    final warnings = <String>[];
    if (phoneCompatible) {
      if (_mediaReferences(p).isNotEmpty ||
          jsonEncode(p).contains('data:image/')) {
        warnings.add(
          'Uploaded tablet artwork is omitted from phone v3; tablet v4 includes portable image bytes.',
        );
      }
      if (p['imageUrl'] != null) {
        warnings.add('Phone v3 does not include the setup cover image.');
      }
      if ((p['utilities'] as List).any((u) => u['kind'] == 'mana_pool')) {
        warnings.add(
          'The tablet mana pool and utility visibility preferences are omitted from phone v3.',
        );
      }
    }
    if (jsonEncode(p).contains('file://')) {
      warnings.add(
        'Local file artwork references cannot transfer to another device. Re-upload them as portable images.',
      );
    }
    return warnings;
  }

  Future<String> exportJson(String id, {bool phoneCompatible = false}) async {
    final p = cloneJson(_preset(id));
    if (!phoneCompatible) {
      return const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 4,
        'product': 'tripling-table',
        'exportDate': DateTime.now().toUtc().toIso8601String(),
        'preset': p,
        'assets': await _exportMedia(p),
      });
    }
    _stripPhoneArtwork(p);
    final trackers = <Map<String, dynamic>>[],
        toggles = <Map<String, dynamic>>[];
    var order = 0;
    for (final raw in p['utilities'] as List) {
      final u = Map<String, dynamic>.from(raw as Map);
      if (u['kind'] == 'mana_pool') continue;
      final config = Map<String, dynamic>.from(
        u['configuration'] as Map? ?? {},
      );
      final toggle = config['type'] == 'toggle';
      final m = {
        ...config,
        'name': u['name'],
        'colorIdentity': u['colors'],
        'defaultValue': u['defaultValue'],
        'order': order++,
        'artworkUrl': u['artworkUrl'],
        if (toggle) 'onDescription': u['description'],
        if (!toggle) 'description': u['description'],
        'offDescription': config['offDescription'] ?? '',
        'isCustom': config['isCustom'] ?? false,
      };
      (toggle ? toggles : trackers).add(m);
    }
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 3,
      'appVersion': '1.11.0',
      'exportDate': DateTime.now().toUtc().toIso8601String(),
      'deck': {
        'name': p['name'],
        'colorIdentity': '',
        'templates': [
          for (var i = 0; i < (p['tokens'] as List).length; i++)
            {...(p['tokens'] as List)[i] as Map, 'order': i},
        ],
        'trackerWidgets': trackers,
        'toggleWidgets': toggles,
      },
      'omissions': exportWarnings(id, phoneCompatible: true),
    });
  }

  Set<String> _mediaReferences(dynamic value) {
    final result = <String>{};
    void visit(dynamic v) {
      if (v is String && v.startsWith('tablet-art:')) result.add(v);
      if (v is Map) {
        for (final child in v.values) {
          visit(child);
        }
      }
      if (v is List) {
        for (final child in v) {
          visit(child);
        }
      }
    }

    visit(value);
    return result;
  }

  Future<Map<String, String>> _exportMedia(Map<String, dynamic> preset) async {
    final result = <String, String>{};
    for (final reference in _mediaReferences(preset)) {
      final bytes = await TabletMediaStore.read(reference);
      if (bytes == null) {
        throw StateError('Artwork is unavailable for export: $reference');
      }
      result[reference] = base64Encode(bytes);
    }
    return result;
  }

  Future<void> _importMedia(
    Map<String, dynamic> preset,
    dynamic rawAssets,
  ) async {
    final assets = Map<String, dynamic>.from(rawAssets as Map? ?? {});
    final decoded = <String, Uint8List>{};
    var total = 0;
    for (final reference in _mediaReferences(preset)) {
      final encoded = assets[reference];
      if (encoded is! String) {
        throw const FormatException(
          'Setup is missing an uploaded artwork asset',
        );
      }
      final bytes = base64Decode(encoded);
      total += bytes.length;
      if (total > 64 * 1024 * 1024) {
        throw const FormatException(
          'Setup artwork exceeds the 64 MB import limit',
        );
      }
      if ('tablet-art:${sha256.convert(bytes)}' != reference) {
        throw const FormatException(
          'Setup artwork failed integrity verification',
        );
      }
      decoded[reference] = bytes;
    }
    // Validate all assets before any media writes. Immutable orphan bytes are
    // harmless if a later library write fails; the board remains unchanged.
    for (final entry in decoded.entries) {
      await TabletMediaStore.save(entry.value);
    }
  }

  void _stripPhoneArtwork(dynamic value) {
    if (value is Map) {
      for (final key in value.keys.toList()) {
        final child = value[key];
        if (child is String &&
            (child.startsWith('tablet-art:') ||
                child.startsWith('data:image/'))) {
          value[key] = key == 'url' ? '' : null;
        } else {
          _stripPhoneArtwork(child);
        }
      }
      final options = value['artworkOptions'];
      if (options is List) {
        options.removeWhere(
          (v) => v is Map && (v['url'] == null || v['url'] == ''),
        );
      }
    } else if (value is List) {
      for (final child in value) {
        _stripPhoneArtwork(child);
      }
    }
  }

  Future<Map<String, dynamic>> importDecklist(
    String text, {
    String? name,
  }) async {
    final parsed = DecklistParser.parse(text),
        matches = catalog.matchDecklist(text);
    if (matches.isEmpty) {
      throw const FormatException(
        'No token-producing cards matched this decklist. Check card names or update the catalog.',
      );
    }
    final p = {
      'id': newEntityId(),
      'name': name ?? parsed.deckTitle ?? 'Imported decklist',
      'revision': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tokens': matches
          .map(
            (d) => {
              'name': d.name,
              'pt': d.pt,
              'colors': d.colors,
              'type': d.type,
              'abilities': d.abilities,
              'artworkUrl': d.artwork.isEmpty ? null : d.artwork.first.url,
              'artworkSet': d.artwork.isEmpty ? null : d.artwork.first.set,
              'artworkOptions': d.artwork.map((a) => a.toJson()).toList(),
            },
          )
          .toList(),
      'utilities': <Map<String, dynamic>>[],
    };
    await _library((s) => s.decks.add(p));
    return p;
  }
}
