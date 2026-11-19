import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/legacy_media_roots.dart';

void main() {
  const old = '/private/var/mobile/Containers/Data/Application/OLD';
  final roots = LegacyMediaRoots({
    '$old/Documents/custom_artwork': 'Documents/custom_artwork',
    '$old/Library/Application Support/artwork_cache':
        'Library/Application Support/artwork_cache',
  });
  final retained = {
    'Documents/custom_artwork/token.png',
    'Library/Application Support/artwork_cache/deck_box_2.png',
  };

  test('explicit token and support roots survive a container move', () {
    expect(
      roots.resolve('file://$old/Documents/custom_artwork/token.png', retained),
      'Documents/custom_artwork/token.png',
    );
    expect(
      roots.resolve('$old/Documents/custom_artwork/token.png', retained),
      'Documents/custom_artwork/token.png',
    );
    expect(
      roots.resolve(
        'file://$old/Library/Application%20Support/artwork_cache/deck_box_2.png',
        retained,
      ),
      'Library/Application Support/artwork_cache/deck_box_2.png',
    );
  });

  for (final reference in [
    'file://$old/Documents/custom_artwork/../custom_artwork/token.png',
    'file://$old/Documents/custom_artwork/%2e%2e/custom_artwork/token.png',
    'file://$old/Documents/custom_artwork/%252e%252e/token.png',
    'file://$old/Documents/custom_artwork/a%2f..%2ftoken.png',
    'file://$old/Documents/custom_artwork%2ftoken.png',
    'file://$old/Documents/custom_artwork/a%5c..%5ctoken.png',
    'file://$old/Documents/custom_artwork/token.png?query',
    'file://$old/Documents/custom_artwork/token.png#fragment',
    'file://host$old/Documents/custom_artwork/token.png',
    '$old/Documents/custom_artwork//token.png',
    '$old/Documents/custom_artwork/./token.png',
    '$old/Documents/custom_artwork/missing.png',
    '$old/Documents/custom_artwork_other/token.png',
    '/untrusted/Documents/custom_artwork/token.png',
    'https://example.com/token.png',
    'token.png',
  ]) {
    test('unresolved unsafe or missing reference: $reference', () {
      expect(roots.resolve(reference, retained), isNull);
    });
  }

  test('root declarations are immutable and reject overlap', () {
    final map = <String, String>{'/old/custom_artwork': 'custom_artwork'};
    final declared = LegacyMediaRoots(map);
    map.clear();
    expect(declared.roots.length, 1);
    expect(() => declared.roots.clear(), throwsUnsupportedError);
    expect(
      () => LegacyMediaRoots({
        '/old/custom_artwork': 'custom_artwork',
        '/old/custom_artwork/artwork_cache': 'artwork_cache',
      }),
      throwsFormatException,
    );
  });

  test('rejects unsafe configuration rather than guessing a root', () {
    for (final source in [
      '/',
      '/old',
      '/old/../custom_artwork',
      '/old/custom_artwork/',
    ]) {
      expect(
        () => LegacyMediaRoots({source: 'Documents/custom_artwork'}),
        throwsFormatException,
      );
    }
    expect(
      () => LegacyMediaRoots({
        '$old/Documents/custom_artwork': '../custom_artwork',
      }),
      throwsFormatException,
    );
    expect(
      () => LegacyMediaRoots({
        '$old/Documents/custom_artwork': '/Documents/custom_artwork',
      }),
      throwsFormatException,
    );
  });
}
