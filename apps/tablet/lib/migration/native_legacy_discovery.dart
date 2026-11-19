import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Observations, never permission to initialize a blank table or repair Hive.
/// Even [noEvidence] needs the future startup owner's quiescence and shipped
/// preference-domain verification before it can mean a genuinely fresh install.
enum NativeLegacyPresence { noEvidence, candidate, blocked }

enum LegacyNativePlatform { android, ios }

class NativeLegacyInventory {
  final NativeLegacyPresence presence;
  final Map<String, String> fileHashes;
  final Set<String> directories;
  final List<String> blockers;
  final Map<String, String> sourceRoots;

  NativeLegacyInventory._(
    this.presence,
    Map<String, String> files,
    Set<String> directories,
    List<String> blockers,
    Map<String, String> roots,
  ) : fileHashes = Map.unmodifiable(files),
      directories = Set.unmodifiable(directories),
      blockers = List.unmodifiable(blockers),
      sourceRoots = Map.unmodifiable(roots);
}

/// Read-only discovery of this application's native legacy storage. Does not
/// initialize Hive, SharedPreferences, adapters, TableRepository or any archive.
/// It never creates directories; static discovered symlinks are rejected. Unknown files,
/// backups, empty directories and unreferenced artwork remain evidence.
///
/// The caller must keep roots stable: path-based Dart I/O cannot prevent a
/// hostile concurrent link replacement between stat and open. Matching
/// inventories detect some races, NOT a quiescent transaction. This
/// entry point is deliberately not wired into either application's startup.
/// iOS preferences may still be owned by cfprefsd; this is not a flush API.
class NativeLegacyDiscovery {
  static const primaryBoxes = {
    'items',
    'decks',
    'artworkpreferences',
    'trackerwidgets',
    'togglewidgets',
    'tokenrules',
    'customtokens',
  };
  static const maxFiles = 4096;
  static const maxFileBytes = 64 * 1024 * 1024;
  static const maxTotalBytes = 256 * 1024 * 1024;

  // No path_provider wrapper: its native directory getters may create source
  // directories. A future startup owner must supply noncreating OS-verified
  // roots before claiming an inert source acquisition.

  /// Explicit OS-resolved roots also allow native-layout fixtures. Inputs must
  /// be real, absolute, canonical directories in the same application sandbox.
  /// Filesystem errors and unreadable/unstable input throw; never return empty.
  static Future<NativeLegacyInventory> inspectResolvedRoots({
    required LegacyNativePlatform platform,
    required Directory documents,
    required Directory support,
  }) async {
    for (final directory in [documents, support]) {
      if (!directory.isAbsolute ||
          await FileSystemEntity.type(directory.path, followLinks: false) !=
              FileSystemEntityType.directory ||
          await directory.resolveSymbolicLinks() != directory.path) {
        throw const FormatException('Real canonical native roots required.');
      }
    }
    final root = documents.parent.path;
    final isAndroid = platform == LegacyNativePlatform.android;
    if (documents.path != '$root/${isAndroid ? 'app_flutter' : 'Documents'}' ||
        support.path !=
            '$root/${isAndroid ? 'files' : 'Library/Application Support'}') {
      throw const FormatException('Unexpected native application layout.');
    }
    final preferencesDirectory = isAndroid
        ? '$root/shared_prefs'
        : '$root/Library/Preferences';
    final preferencesName = isAndroid
        ? 'FlutterSharedPreferences.xml'
        : 'LooseTie.Doubling-Season.plist';
    final roots = {
      'documents': documents.path,
      'artwork_cache': '${support.path}/artwork_cache',
      'preferences': '$preferencesDirectory/$preferencesName',
    };
    Future<_Inventory> scan() async {
      final inventory = _Inventory();
      await inventory.walk(documents.path, 'documents', required: true);
      // Listing the readable parent distinguishes absence from a failed stat.
      await for (final entry in support.list(followLinks: false)) {
        if (entry.path == roots['artwork_cache']) {
          if (await FileSystemEntity.type(entry.path, followLinks: false) !=
              FileSystemEntityType.directory) {
            throw const FormatException('Artwork cache must be a directory.');
          }
          await inventory.walk(entry.path, 'artwork_cache', required: true);
        }
      }
      // Enumerate the directory so unreadable/missing parents cannot be confused
      // with an absent file by File.exists(). Only this app's exact domain and
      // sidecars are read; no other preference domains are ingested.
      var foundPreferencesDirectory = false;
      await for (final entry in Directory(
        preferencesDirectory,
      ).parent.list(followLinks: false)) {
        if (entry.path == preferencesDirectory) {
          foundPreferencesDirectory = true;
        }
      }
      final type = await FileSystemEntity.type(
        preferencesDirectory,
        followLinks: false,
      );
      if (foundPreferencesDirectory && type == FileSystemEntityType.notFound) {
        throw const FormatException(
          'Unreadable or changed preference directory.',
        );
      }
      if (type == FileSystemEntityType.directory) {
        if (await Directory(preferencesDirectory).resolveSymbolicLinks() !=
            preferencesDirectory) {
          throw const FormatException('Aliased preference directory.');
        }
        await for (final entry in Directory(
          preferencesDirectory,
        ).list(followLinks: false)) {
          final name = entry.path.substring(preferencesDirectory.length + 1);
          if (name == preferencesName || name.startsWith('$preferencesName.')) {
            if (await FileSystemEntity.type(entry.path, followLinks: false) !=
                FileSystemEntityType.file) {
              throw const FormatException(
                'Preference domain and sidecars must be files.',
              );
            }
            await inventory.walk(
              entry.path,
              'preferences/$name',
              required: true,
            );
          }
        }
      } else if (type != FileSystemEntityType.notFound) {
        throw const FormatException('Unsafe preference directory.');
      }
      return inventory;
    }

    final first = await scan();
    final second = await scan();
    if (!mapEquals(first.files, second.files) ||
        !setEquals(first.directories, second.directories)) {
      throw const FormatException('Legacy storage changed during discovery.');
    }
    final files = first.files;
    final blockers = <String>[];
    final evidence = files.isNotEmpty || first.directories.length > 1;
    if (evidence) {
      for (final name in primaryBoxes) {
        if (!files.containsKey('documents/$name.hive')) {
          blockers.add('Missing primary box: $name');
        }
      }
      if (!files.containsKey('preferences/$preferencesName')) {
        blockers.add('Missing raw preference domain');
      }
      for (final path in files.keys) {
        if (path.startsWith('preferences/') &&
            path != 'preferences/$preferencesName') {
          blockers.add('Preference recovery sidecar: $path');
        }
        if (path.endsWith('.hivec')) {
          blockers.add('Hive compaction evidence: $path');
        }
        if (path.endsWith('.hive') &&
            !path.startsWith('documents/hive_backups/') &&
            !{
              ...primaryBoxes,
              'boardorderoperations',
            }.any((name) => path == 'documents/$name.hive')) {
          blockers.add('Unknown Hive store: $path');
        }
      }
    }
    return NativeLegacyInventory._(
      !evidence
          ? NativeLegacyPresence.noEvidence
          : blockers.isEmpty
          ? NativeLegacyPresence.candidate
          : NativeLegacyPresence.blocked,
      files,
      first.directories,
      blockers,
      roots,
    );
  }
}

class _Inventory {
  final files = <String, String>{};
  final directories = <String>{};
  int total = 0;

  Future<void> walk(String source, String key, {bool required = false}) async {
    final type = await FileSystemEntity.type(source, followLinks: false);
    if (type == FileSystemEntityType.notFound && !required) return;
    if (type == FileSystemEntityType.directory) {
      if (directories.length >= NativeLegacyDiscovery.maxFiles) {
        throw const FormatException('Too many legacy directories.');
      }
      directories.add(key);
      await for (final entry in Directory(source).list(followLinks: false)) {
        final name = entry.path.substring(source.length + 1);
        if (name.contains('\\') ||
            name.contains(':') ||
            name.contains('\u0000')) {
          throw const FormatException('Unsafe legacy path.');
        }
        await walk(entry.path, '$key/$name', required: true);
      }
    } else if (type == FileSystemEntityType.file) {
      final file = File(source);
      final size = await file.length();
      if (files.length >= NativeLegacyDiscovery.maxFiles ||
          size > NativeLegacyDiscovery.maxFileBytes ||
          total + size > NativeLegacyDiscovery.maxTotalBytes) {
        throw const FormatException('Legacy inventory exceeds safety limits.');
      }
      // Bounded reads also reject files that grow after stat. No Hive handles.
      var readBytes = 0;
      final digest = await sha256
          .bind(
            file.openRead().map((chunk) {
              readBytes += chunk.length;
              if (readBytes > size) {
                throw const FormatException(
                  'Legacy file grew during discovery.',
                );
              }
              return chunk;
            }),
          )
          .single;
      if (readBytes != size) {
        throw const FormatException('Legacy file changed size.');
      }
      total += size;
      files[key] = digest.toString();
    } else {
      throw FormatException('Unsafe or missing legacy entry: $key');
    }
  }
}
