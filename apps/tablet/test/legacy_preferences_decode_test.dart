import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';

const listPrefix = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu';
const doublePrefix = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu';
const bigIntegerPrefix = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBCaWdJbnRlZ2Vy';
Map<String, dynamic> android(String xml) => decodeLegacyPreferences(
  utf8.encode(xml),
  LegacyPreferencesFormat.androidXml,
);
Map<String, dynamic> apple(String xml) => decodeLegacyPreferences(
  utf8.encode(xml),
  LegacyPreferencesFormat.applePlist,
);
String plist(String contents) =>
    '<plist version="1.0"><dict>$contents</dict></plist>';

// OpenJDK ObjectOutputStream.writeObject(ArrayList<String>), the plugin's
// serializer. Contains modified UTF-8 NUL, a surrogate pair and TC_REFERENCE.
const javaList =
    'rO0ABXNyABNqYXZhLnV0aWwuQXJyYXlMaXN0eIHSHZnHYZ0DAAFJAARzaXpleHAAAAADdwQAAAADdAADZWxmdAAL6Zuq7aC87byxwIBxAH4AAng=';
// Python 3 plistlib.dumps(..., FMT_BINARY, sort_keys=False). Exercises 2-byte
// offsets, signed 64-bit integers, UTF-16BE, reused strings and nested values.
const binaryPlist =
    'YnBsaXN0MDDaAQIDBAUGBwgJCgsMDQ4PEBEUGRpdZmx1dHRlci50aXRsZV8QD2ZsdXR0ZXIuZW5hYmxlZF8QEGZsdXR0ZXIuZGlzYWJsZWRdZmx1dHRlci5jb3VudF8QEGZsdXR0ZXIubmVnYXRpdmVdZmx1dHRlci5zY2FsZV8QEWZsdXR0ZXIuZmF2b3JpdGVzV3Vua25vd25fEBRmbHV0dGVyLmZsdXR0ZXIua2VlcF1mbHV0dGVyLmxhcmdlZwBBACAAJgAglurYPN8xCQgQKhP/////////8iM/9AAAAAAAAKMSExJTRWxmY5bq2DzfMdEVFlZmdXR1cmWjDRcYEAlUa2VwdFRvbmNlE3//////////AAgAHQArAD0AUABeAHEAfwCTAJsAsgDAAM8A0ADRANMA3ADlAOkA7QD0APcA/gECAQQBCQEOAAAAAAAAAgEAAAAAAAAAGwAAAAAAAAAAAAAAAAAAARc=';

void main() {
  group('Android copied SharedPreferences XML', () {
    test('preserves scalar types, entities, Unicode and unknown keys', () {
      expect(
        android('''<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
<string name="flutter.title">A &amp; &lt;B&gt; &quot;C&quot; &apos;D&apos; &#x96EA;&#127793;</string>
<boolean name="flutter.enabled" value="true"/><boolean name="flutter.disabled" value="false"/>
<int name="flutter.count" value="42"/><long name="flutter.negative" value="-9223372036854775808"/>
<float name="flutter.scale" value="1.5"/><string name="native">${doublePrefix}1.25</string>
<string name="flutter.flutter.once"><![CDATA[ x & y ]]></string><string name="flutter.empty"/>
</map>'''),
        {
          'title': 'A & <B> "C" \'D\' 雪🌱',
          'enabled': true,
          'disabled': false,
          'count': 42,
          'negative': -9223372036854775808,
          'scale': 1.5,
          'native': '${doublePrefix}1.25',
          'flutter.once': ' x & y ',
          'empty': '',
        },
      );
    });
    test(
      'reads actual JSON-list, double, BigInteger and old set encodings',
      () {
        expect(
          android('''<map>
<string name="flutter.favorites">$listPrefix!["Elf","雪🌱","Elf"]</string>
<string name="flutter.ratio">$doublePrefix-1.25e2</string>
<string name="flutter.big">${bigIntegerPrefix}1z</string>
<set name="flutter.oldFavorites"><string>Elf</string><string>雪🌱</string></set>
</map>'''),
          {
            'favorites': ['Elf', '雪🌱', 'Elf'],
            'ratio': -125.0,
            'big': 71,
            'oldFavorites': ['Elf', '雪🌱'],
          },
        );
      },
    );
    test('reads real Java serialization and base64 line wrapping', () {
      final wrapped =
          '${javaList.substring(0, 32)}\n${javaList.substring(32)}\n';
      expect(
        android(
          '<map><string name="flutter.list">$listPrefix$wrapped</string></map>',
        ),
        {
          'list': ['elf', '雪🌱\u0000', 'elf'],
        },
      );
    });
    test('does not reinterpret iOS or non-prefixed Android strings', () {
      expect(
        android('<map><string name="native">$listPrefix!</string></map>'),
        {'native': '$listPrefix!'},
      );
      expect(
        apple(plist('<key>flutter.string</key><string>$listPrefix!</string>')),
        {'string': '$listPrefix!'},
      );
    });
    final badBodies = [
      '<string name="same">a</string><string name="same">b</string>',
      '<string name="x">a</string><string name="flutter.x">b</string>',
      '<string name="flutter.x">a</string><string name="x">b</string>',
      '<boolean name="x" value="TRUE"/>',
      '<boolean name="x"/>',
      '<long name="x" value="9223372036854775808"/>',
      '<int name="x" value="2147483648"/>',
      '<float name="x" value="NaN"/>',
      '<float name="x" value="1e999"/>',
      '<float name="x" value="3.5e38"/>',
      '<string name="x">&unknown;</string>',
      '<string name="x">&#0;</string>',
      '<string name="x">&amp</string>',
      '<string name="x"><child/></string>',
      '<string name="x" name="y">a</string>',
      '<string>missing name</string>',
      '<set name="x"><string>a</string><string>a</string></set>',
      '<set name="x"><int value="1"/></set>',
      '<byte-array name="x"/>',
      '<string name="flutter.x">$listPrefix![1]</string>',
      '<string name="flutter.x">$listPrefix!null</string>',
      '<string name="flutter.x">$listPrefix!broken</string>',
      '<string name="flutter.x">$listPrefix%%%%</string>',
      '<string name="flutter.x">${doublePrefix}NaN</string>',
      '<string name="flutter.x">${bigIntegerPrefix}999999999999999999999999</string>',
      'unexpected text',
    ];
    for (var i = 0; i < badBodies.length; i++) {
      test('rejects malformed or unsupported Android value $i', () {
        expect(
          () => android('<map>${badBodies[i]}</map>'),
          throwsFormatException,
        );
      });
    }
    test(
      'rejects every truncated Java prefix, corruption and trailing bytes',
      () {
        final original = base64.decode(javaList);
        final corruptions = [
          for (var i = 0; i < original.length; i++) original.sublist(0, i),
          [...original, 0],
          [...original]..[4] = 0x75,
          [...original]..[12] = 0,
          [...original]..[original.length - 2] = 4,
        ];
        for (final bytes in corruptions) {
          final encoded = base64.encode(bytes);
          expect(
            () => android(
              '<map><string name="flutter.x">$listPrefix$encoded</string></map>',
            ),
            throwsFormatException,
          );
        }
      },
    );
  });
  group('Apple XML plist', () {
    test('reads standard plist metadata, scalars and nested values', () {
      expect(
        apple('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>flutter.title</key><string> A &amp; 雪🌱 </string>
<key>flutter.enabled</key><true/><key>flutter.disabled</key><false/>
<key>flutter.count</key><integer>-42</integer><key>flutter.scale</key><real>1.25</real>
<key>flutter.favorites</key><array><string>Elf</string><string>雪🌱</string></array>
<key>unknown</key><dict><key>flutter.nested</key><array><false/><integer>9</integer><string>kept</string></array></dict>
</dict></plist>'''),
        {
          'title': ' A & 雪🌱 ',
          'enabled': true,
          'disabled': false,
          'count': -42,
          'scale': 1.25,
          'favorites': ['Elf', '雪🌱'],
          'unknown': {
            'flutter.nested': [false, 9, 'kept'],
          },
        },
      );
    });
    test('reads UTF-16 XML with either byte order', () {
      final source =
          '<?xml version="1.0" encoding="UTF-16"?>${plist('<key>flutter.name</key><string>雪🌱</string>')}';
      for (final endian in [Endian.little, Endian.big]) {
        final bytes = Uint8List(2 + source.codeUnits.length * 2);
        final view = ByteData.sublistView(bytes)..setUint16(0, 0xfeff, endian);
        for (var i = 0; i < source.codeUnits.length; i++) {
          view.setUint16(2 + i * 2, source.codeUnits[i], endian);
        }
        expect(
          decodeLegacyPreferences(bytes, LegacyPreferencesFormat.applePlist),
          {'name': '雪🌱'},
        );
      }
    });
    final badBodies = [
      '<key>x</key><string>a</string><key>x</key><string>b</string>',
      '<key>x</key><string>a</string><key>flutter.x</key><string>b</string>',
      '<key>x</key>',
      '<string>x</string><true/>',
      '<key>x</key><date>2026-01-01T00:00:00Z</date>',
      '<key>x</key><data>AA==</data>',
      '<key>x</key><null/>',
      '<key>x</key><uid>1</uid>',
      '<key>x</key><real>inf</real>',
      '<key>x</key><true>yes</true>',
      '<key>x</key><integer>1.5</integer>',
      '<key>x</key><string other="y">a</string>',
      '<key>x</key><array>text</array>',
      '<key>x</key><dict><key>a</key><true/><key>a</key><false/></dict>',
    ];
    for (var i = 0; i < badBodies.length; i++) {
      test('rejects malformed or unsupported plist value $i', () {
        expect(() => apple(plist(badBodies[i])), throwsFormatException);
      });
    }
    test('rejects DTDs, external entities, invalid roots and truncation', () {
      for (final xml in [
        '<!DOCTYPE plist SYSTEM "file:///etc/passwd">${plist('')}',
        '<!DOCTYPE plist [<!ENTITY secret SYSTEM "file:///etc/passwd">]>${plist('<key>x</key><string>&secret;</string>')}',
        '<plist version="1.0"><dict>',
        '<plist version="1.0"><array/></plist>',
        '<plist version="1.0"><dict/><dict/></plist>',
        '<plist version="2.0"><dict/></plist>',
      ]) {
        expect(() => apple(xml), throwsFormatException);
      }
    });
  });
  group('Apple binary plist', () {
    test('reads empty dictionaries and extended collection/string lengths', () {
      expect(
        decodeLegacyPreferences(
          base64.decode(
            'YnBsaXN0MDDQCAAAAAAAAAEBAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAJ',
          ),
          LegacyPreferencesFormat.applePlist,
        ),
        isEmpty,
      );
      final bytes = base64.decode(
        'YnBsaXN0MDDSAQIDFVxmbHV0dGVyLmxpc3RcZmx1dHRlci50ZXh0rxARBAUGBwgJCgsMDQ4PEBESExQQABABEAIQAxAEEAUQBhAHEAgQCRAKEAsQDBANEA4QDxAQbxAg2DzfMdg83zHYPN8x2DzfMdg83zHYPN8x2DzfMdg83zHYPN8x2DzfMdg83zHYPN8x2DzfMdg83zHYPN8x2DzfMQgNGic7PT9BQ0VHSUtNT1FTVVdZW10AAAAAAAABAQAAAAAAAAAWAAAAAAAAAAAAAAAAAAAAoA==',
      );
      expect(
        decodeLegacyPreferences(bytes, LegacyPreferencesFormat.applePlist),
        {'list': List<int>.generate(17, (i) => i), 'text': '🌱' * 16},
      );
    });
    test('explicitly rejects real binary date, data, UID, null and key collision', () {
      // Each fixture is independently generated with Python plistlib.
      for (final encoded in [
        'YnBsaXN0MDDRAQJZZmx1dHRlci54M0HHgvhAAAAACAsVAAAAAAAAAQEAAAAAAAAAAwAAAAAAAAAAAAAAAAAAAB4=',
        'YnBsaXN0MDDRAQJZZmx1dHRlci54Q3JhdwgLFQAAAAAAAAEBAAAAAAAAAAMAAAAAAAAAAAAAAAAAAAAZ',
        'YnBsaXN0MDDRAQJZZmx1dHRlci54gAEICxUAAAAAAAABAQAAAAAAAAADAAAAAAAAAAAAAAAAAAAAFw==',
        'YnBsaXN0MDDRAQJZZmx1dHRlci54AAgLFQAAAAAAAAEBAAAAAAAAAAMAAAAAAAAAAAAAAAAAAAAW',
        'YnBsaXN0MDDSAQIDBFlmbHV0dGVyLnhReBACEAEIDRcZGwAAAAAAAAEBAAAAAAAAAAUAAAAAAAAAAAAAAAAAAAAd',
      ]) {
        expect(
          () => decodeLegacyPreferences(
            base64.decode(encoded),
            LegacyPreferencesFormat.applePlist,
          ),
          throwsFormatException,
        );
      }
    });
    test('bounds expanded data from repeated binary container references', () {
      // Just 26 objects encode more than 8 million leaves. The decoded DAG
      // must be rejected before a snapshot serializer can expand it.
      final objects = <List<int>>[
        [0xd1, 1, 2],
        [0x51, 0x78],
        for (var i = 2; i < 25; i++) [0xa2, i + 1, i + 1],
        [9],
      ];
      expect(
        () => decodeLegacyPreferences(
          binaryObjects(objects),
          LegacyPreferencesFormat.applePlist,
        ),
        throwsFormatException,
      );
    });
    test(
      'rejects non-finite real, invalid UTF-16 and non-string dictionary key',
      () {
        for (final objects in <List<List<int>>>[
          [
            [0xd1, 1, 2],
            [0x51, 0x78],
            [0x23, 0x7f, 0xf0, 0, 0, 0, 0, 0, 0],
          ],
          [
            [0xd1, 1, 2],
            [0x51, 0x78],
            [0x61, 0xd8, 0],
          ],
          [
            [0xd1, 1, 2],
            [0x10, 1],
            [9],
          ],
        ]) {
          expect(
            () => decodeLegacyPreferences(
              binaryObjects(objects),
              LegacyPreferencesFormat.applePlist,
            ),
            throwsFormatException,
          );
        }
      },
    );

    test('reads real binary plist without mutating caller bytes', () {
      final bytes = base64.decode(binaryPlist);
      final before = List<int>.of(bytes);
      expect(
        decodeLegacyPreferences(bytes, LegacyPreferencesFormat.applePlist),
        {
          'title': 'A & 雪🌱',
          'enabled': true,
          'disabled': false,
          'count': 42,
          'negative': -14,
          'scale': 1.25,
          'favorites': ['Elf', '雪🌱', 'Elf'],
          'unknown': {
            'future': [false, 9, 'kept'],
          },
          'flutter.keep': 'once',
          'large': 9223372036854775807,
        },
      );
      expect(bytes, before);
    });
    test('rejects every truncated binary prefix', () {
      final bytes = base64.decode(binaryPlist);
      for (var i = 0; i < bytes.length; i++) {
        expect(
          () => decodeLegacyPreferences(
            bytes.sublist(0, i),
            LegacyPreferencesFormat.applePlist,
          ),
          throwsFormatException,
          reason: 'prefix of $i bytes',
        );
      }
    });
    test('rejects versions, widths, offsets, references, cycles and null', () {
      final original = base64.decode(binaryPlist);
      for (final bytes in [
        [...original]..[7] = 0x31,
        [...original]..[original.length - 26] = 3,
        [...original]..[original.length - 25] = 0,
        [...original]..[original.length - 1] = 0,
        [...original]..[9] = 0xff,
        [...original]..[19] = 0,
        [...original]..[8] = 0xc0,
        [...original]..[207] = 0,
      ]) {
        expect(
          () => decodeLegacyPreferences(
            bytes,
            LegacyPreferencesFormat.applePlist,
          ),
          throwsFormatException,
        );
      }
    });
    test('rejects duplicate binary dictionary keys', () {
      final bytes = base64.decode(binaryPlist)..[10] = 1;
      expect(
        () =>
            decodeLegacyPreferences(bytes, LegacyPreferencesFormat.applePlist),
        throwsFormatException,
      );
    });
  });
  test('rejects XML encoding mismatch, controls and excessive nesting', () {
    expect(
      () => apple('<?xml version="1.0" encoding="UTF-16"?>${plist('')}'),
      throwsFormatException,
    );
    expect(
      () => apple(plist('<key>x</key><string><![CDATA[\u0000]]></string>')),
      throwsFormatException,
    );
    expect(
      () => apple(
        plist('<key>x</key>${'<array>' * 130}<true/>${'</array>' * 130}'),
      ),
      throwsFormatException,
    );
  });
  test('bounds integer parsing before allocating arbitrarily large BigInts', () {
    expect(
      () => android('<map><long name="x" value="${'9' * 4096}"/></map>'),
      throwsFormatException,
    );
    expect(
      () => android(
        '<map><string name="flutter.x">$bigIntegerPrefix${'z' * 4096}</string></map>',
      ),
      throwsFormatException,
    );
    expect(android('<map><long name="x" value="-${'0' * 4096}7"/></map>'), {
      'x': -7,
    });
  });
  test('decodes Android floats with native float32 precision', () {
    expect(android('<map><float name="native" value="0.1"/></map>'), {
      'native': 0.10000000149011612,
    });
  });
  test('rejects empty, out-of-byte-range and invalid UTF-8 input', () {
    for (final bytes in <List<int>>[
      [],
      [-1],
      [256],
      [0xc3, 0x28],
    ]) {
      expect(
        () =>
            decodeLegacyPreferences(bytes, LegacyPreferencesFormat.androidXml),
        throwsFormatException,
      );
    }
  });
}

// A small, deliberately transparent binary plist builder for adversarial graph
// tests. The production decoder never calls an encoder or native plist API.
Uint8List binaryObjects(List<List<int>> objects) {
  final bytes = <int>[...ascii.encode('bplist00')];
  final offsets = <int>[];
  for (final object in objects) {
    offsets.add(bytes.length);
    bytes.addAll(object);
  }
  final table = bytes.length;
  final offsetSize = table < 256 ? 1 : 2;
  for (final offset in offsets) {
    if (offsetSize == 2) {
      bytes.add(offset >> 8);
    }
    bytes.add(offset & 255);
  }
  final trailer = ByteData(32)
    ..setUint8(6, offsetSize)
    ..setUint8(7, 1)
    ..setUint64(8, objects.length)
    ..setUint64(16, 0)
    ..setUint64(24, table);
  return Uint8List.fromList([...bytes, ...trailer.buffer.asUint8List()]);
}
