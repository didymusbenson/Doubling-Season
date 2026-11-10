import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

/// The on-disk format of a caller-owned copy, never a live preference store.
enum LegacyPreferencesFormat { androidXml, applePlist }

/// Decodes copied legacy preferences without plugins, files, or native calls.
///
/// Only the leading `flutter.` on top-level keys is removed. Other keys and
/// JSON-compatible values are retained, including unknown app settings. A
/// duplicate or normalized-key collision fails rather than overwriting data.
/// Android plugin list/double/BigInteger encodings are interpreted only on
/// `flutter.` keys. Java list support is deliberately restricted to the actual
/// ArrayList/string wire format; no Java objects are instantiated.
///
/// Apple XML and binary v00 plists support dictionaries, arrays, strings,
/// booleans, finite reals and representable signed 64-bit integers. Data, dates,
/// UIDs, sets, null and other unsupported types fail explicitly, including in
/// unknown settings. The caller must retain original bytes independently.
/// Malformed, unsupported or excessive input always fails with FormatException.
Map<String, dynamic> decodeLegacyPreferences(
  List<int> bytes,
  LegacyPreferencesFormat format,
) {
  if (bytes.isEmpty ||
      bytes.length > 64 * 1024 * 1024 ||
      bytes.any((byte) => byte < 0 || byte > 255)) {
    throw const FormatException('Invalid or oversized preference bytes.');
  }
  final copied = Uint8List.fromList(bytes);
  final Map<String, dynamic> raw;
  if (format == LegacyPreferencesFormat.applePlist &&
      copied.length >= 8 &&
      ascii.decode(copied.sublist(0, 6), allowInvalid: true) == 'bplist') {
    raw = _BinaryPlist(copied).decode();
  } else {
    final xml = _decodeXmlBytes(copied);
    _checkXmlCharacters(xml);
    final document = XmlDocument.parse(
      xml,
      entityMapping: const _StrictXmlEntities(),
    );
    for (final node in document.children) {
      if (node is XmlDoctype) {
        // This is metadata only. No DTD or external resource is ever loaded.
        if (format != LegacyPreferencesFormat.applePlist ||
            node.toXmlString() !=
                '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">') {
          throw const FormatException('Unsupported preference XML doctype.');
        }
      } else if (node is XmlDeclaration) {
        final encoding = node.getAttribute('encoding')?.toLowerCase();
        final actualEncoding =
            copied.length >= 2 &&
                ((copied[0] == 0xff && copied[1] == 0xfe) ||
                    (copied[0] == 0xfe && copied[1] == 0xff))
            ? 'utf-16'
            : 'utf-8';
        if (encoding != null && encoding != actualEncoding) {
          throw const FormatException('Unsupported preference XML encoding.');
        }
      } else if (node is! XmlElement &&
          node is! XmlComment &&
          !(node is XmlText && node.value.trim().isEmpty)) {
        throw const FormatException(
          'Unexpected content outside preference XML.',
        );
      }
    }
    final root = document.rootElement;
    if (format == LegacyPreferencesFormat.androidXml) {
      raw = _android(root);
    } else {
      _attributes(root, {'version'});
      if (root.name.qualified != 'plist' ||
          root.getAttribute('version') != '1.0') {
        throw const FormatException('Expected an Apple plist version 1.0.');
      }
      final children = _elements(root);
      if (children.length != 1 || children.single.name.qualified != 'dict') {
        throw const FormatException(
          'Preference plist must contain one dictionary.',
        );
      }
      raw = _plistXml(children.single, 0) as Map<String, dynamic>;
    }
  }
  final result = <String, dynamic>{};
  for (final entry in raw.entries) {
    final key = entry.key.startsWith('flutter.')
        ? entry.key.substring(8)
        : entry.key;
    _insert(result, key, entry.value);
  }
  _validateExpansion(result);
  return result;
}

// Plists can reuse object references. Bound the expanded JSON tree as well as
// the encoded bytes so a compact DAG cannot explode during snapshot capture.
void _validateExpansion(Map<String, dynamic> result) {
  var values = 0;
  var characters = 0;
  void visit(dynamic value, int depth) {
    if (depth > 128 || ++values > 1000000) {
      throw const FormatException('Excessive expanded preference data.');
    }
    if (value is String) {
      characters += value.length;
      if (characters > 64 * 1024 * 1024) {
        throw const FormatException('Excessive expanded preference strings.');
      }
    } else if (value is List) {
      for (final item in value) {
        visit(item, depth + 1);
      }
    } else if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        visit(entry.key, depth + 1);
        visit(entry.value, depth + 1);
      }
    }
  }

  visit(result, 0);
}

void _checkXmlCharacters(String text) {
  for (final rune in text.runes) {
    if (!(rune == 9 ||
        rune == 10 ||
        rune == 13 ||
        (rune >= 0x20 && rune <= 0xd7ff) ||
        (rune >= 0xe000 && rune <= 0xfffd) ||
        (rune >= 0x10000 && rune <= 0x10ffff))) {
      throw const FormatException('Invalid XML character.');
    }
  }
}

String _decodeXmlBytes(Uint8List bytes) {
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
          (bytes[0] == 0xfe && bytes[1] == 0xff))) {
    return _utf16(
      bytes.sublist(2),
      bytes[0] == 0xff ? Endian.little : Endian.big,
    );
  }
  return utf8.decode(bytes);
}

String _utf16(Uint8List bytes, Endian endian) {
  if (bytes.length.isOdd) throw const FormatException('Truncated UTF-16.');
  final view = ByteData.sublistView(bytes);
  final units = [
    for (var i = 0; i < bytes.length; i += 2) view.getUint16(i, endian),
  ];
  for (var i = 0; i < units.length; i++) {
    if (units[i] >= 0xd800 && units[i] <= 0xdbff) {
      if (++i == units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
        throw const FormatException('Invalid UTF-16 surrogate.');
      }
    } else if (units[i] >= 0xdc00 && units[i] <= 0xdfff) {
      throw const FormatException('Unpaired UTF-16 surrogate.');
    }
  }
  return String.fromCharCodes(units);
}

class _StrictXmlEntities extends XmlDefaultEntityMapping {
  const _StrictXmlEntities() : super.xml();

  @override
  String decode(String input) {
    final output = StringBuffer();
    var start = 0;
    while (true) {
      final amp = input.indexOf('&', start);
      if (amp == -1) {
        output.write(input.substring(start));
        break;
      }
      output.write(input.substring(start, amp));
      final end = input.indexOf(';', amp + 1);
      if (end == -1) throw const FormatException('Unterminated XML entity.');
      final entity = input.substring(amp + 1, end);
      if (entity.startsWith('#') &&
          !RegExp(r'^#(?:[0-9]+|x[0-9a-fA-F]+)$').hasMatch(entity)) {
        throw const FormatException('Invalid XML character reference.');
      }
      final decoded = super.decodeEntity(entity);
      if (decoded == null) throw const FormatException('Unknown XML entity.');
      output.write(decoded);
      start = end + 1;
    }
    final result = output.toString();
    _checkXmlCharacters(result);
    return result;
  }
}

void _attributes(XmlElement element, Set<String> allowed) {
  final seen = <String>{};
  for (final attribute in element.attributes) {
    final name = attribute.name.qualified;
    if (!allowed.contains(name) || !seen.add(name)) {
      throw const FormatException('Unexpected or duplicate XML attribute.');
    }
  }
}

List<XmlElement> _elements(XmlElement element) {
  final children = <XmlElement>[];
  for (final node in element.children) {
    if (node is XmlElement) {
      children.add(node);
      if (children.length > 100000) {
        throw const FormatException('Too many preference values.');
      }
    } else if (node is! XmlComment &&
        !(node is XmlText && node.value.trim().isEmpty)) {
      throw const FormatException('Unexpected text in preference container.');
    }
  }
  return children;
}

String _text(XmlElement element) {
  final value = StringBuffer();
  for (final node in element.children) {
    if (node is XmlText || node is XmlCDATA) {
      value.write(node.value);
    } else if (node is! XmlComment) {
      throw const FormatException('Unexpected nested preference value.');
    }
  }
  return value.toString();
}

void _insert(Map<String, dynamic> target, String key, dynamic value) {
  if (target.containsKey(key)) {
    throw const FormatException('Duplicate preference key.');
  }
  target[key] = value;
}

int _integer(String text, {int radix = 10, int bits = 64}) {
  final pattern = radix == 10 ? r'^[+-]?[0-9]+$' : r'^[+-]?[0-9a-zA-Z]+$';
  if (!RegExp(pattern).hasMatch(text)) {
    throw const FormatException('Invalid preference integer.');
  }
  var start = text.startsWith('-') || text.startsWith('+') ? 1 : 0;
  while (start < text.length && text.codeUnitAt(start) == 0x30) {
    start++;
  }
  if (text.length - start > (radix == 10 ? 19 : 13)) {
    throw const FormatException(
      'Preference integer is outside the supported range.',
    );
  }
  if (start == text.length) return 0;
  final significant =
      '${text.startsWith('-') ? '-' : ''}${text.substring(start)}';
  return _representableInteger(
    BigInt.parse(significant, radix: radix),
    bits: bits,
  );
}

int _representableInteger(BigInt value, {int bits = 64}) {
  final limit = BigInt.one << (bits - 1);
  if (value < -limit || value >= limit) {
    throw const FormatException(
      'Preference integer is outside the supported range.',
    );
  }
  final converted = value.toInt();
  if (BigInt.from(converted) != value) {
    throw const FormatException(
      'Preference integer cannot be represented exactly.',
    );
  }
  return converted;
}

double _real(String text) {
  if (!RegExp(
    r'^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$',
  ).hasMatch(text)) {
    throw const FormatException('Invalid preference real.');
  }
  final value = double.tryParse(text);
  if (value == null || !value.isFinite) {
    throw const FormatException('Non-finite preference real.');
  }
  return value;
}

Map<String, dynamic> _android(XmlElement root) {
  if (root.name.qualified != 'map') {
    throw const FormatException('Expected Android preference map.');
  }
  _attributes(root, {});
  final values = <String, dynamic>{};
  for (final child in _elements(root)) {
    final tag = child.name.qualified;
    _attributes(
      child,
      tag == 'string' || tag == 'set' ? {'name'} : {'name', 'value'},
    );
    final key = child.getAttribute('name');
    if (key == null) throw const FormatException('Missing preference name.');
    dynamic value;
    if (tag == 'string') {
      value = _text(child);
      if (key.startsWith('flutter.')) {
        value = _androidPluginString(value as String);
      }
    } else if (tag == 'set') {
      final strings = <String>[];
      final seen = <String>{};
      for (final item in _elements(child)) {
        _attributes(item, {});
        if (item.name.qualified != 'string') {
          throw const FormatException('Invalid Android string set.');
        }
        final string = _text(item);
        if (!seen.add(string)) {
          throw const FormatException('Duplicate Android set value.');
        }
        strings.add(string);
      }
      value = strings;
    } else {
      if (_text(child).trim().isNotEmpty) {
        throw const FormatException('Unexpected scalar text.');
      }
      final scalar = child.getAttribute('value');
      if (scalar == null) {
        throw const FormatException('Missing preference value.');
      }
      value = switch (tag) {
        'boolean' when scalar == 'true' => true,
        'boolean' when scalar == 'false' => false,
        'int' => _integer(scalar, bits: 32),
        'long' => _integer(scalar),
        'float' => _androidFloat(scalar),
        _ => throw const FormatException(
          'Unsupported Android preference type or value.',
        ),
      };
    }
    _insert(values, key, value);
  }
  return values;
}

double _androidFloat(String text) {
  final value = (ByteData(4)..setFloat32(0, _real(text))).getFloat32(0);
  if (!value.isFinite) {
    throw const FormatException(
      'Android preference float is outside its range.',
    );
  }
  return value;
}

const _listPrefix = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu';
const _doublePrefix = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu';
const _bigIntPrefix = 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBCaWdJbnRlZ2Vy';

dynamic _androidPluginString(String value) {
  if (value.startsWith('$_listPrefix!')) {
    final decoded = jsonDecode(value.substring(_listPrefix.length + 1));
    if (decoded is! List || decoded.any((item) => item is! String)) {
      throw const FormatException(
        'Android preference list must contain only strings.',
      );
    }
    return decoded.cast<String>().toList();
  }
  if (value.startsWith(_listPrefix)) {
    final encoded = value
        .substring(_listPrefix.length)
        .replaceAll(RegExp(r'[ \t\r\n]'), '');
    if (!RegExp(
      r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
    ).hasMatch(encoded)) {
      throw const FormatException('Invalid Android serialized-list base64.');
    }
    return _JavaStringList(base64.decode(encoded)).decode();
  }
  if (value.startsWith(_doublePrefix)) {
    return _real(value.substring(_doublePrefix.length));
  }
  if (value.startsWith(_bigIntPrefix)) {
    return _integer(value.substring(_bigIntPrefix.length), radix: 36);
  }
  return value;
}

dynamic _plistXml(XmlElement element, int depth) {
  if (depth > 128) {
    throw const FormatException('Preference plist is too deeply nested.');
  }
  _attributes(element, {});
  switch (element.name.qualified) {
    case 'dict':
      final children = _elements(element);
      if (children.length.isOdd) {
        throw const FormatException('Missing plist dictionary value.');
      }
      final values = <String, dynamic>{};
      for (var i = 0; i < children.length; i += 2) {
        if (children[i].name.qualified != 'key') {
          throw const FormatException('Expected plist dictionary key.');
        }
        _attributes(children[i], {});
        _insert(
          values,
          _text(children[i]),
          _plistXml(children[i + 1], depth + 1),
        );
      }
      return values;
    case 'array':
      return [
        for (final child in _elements(element)) _plistXml(child, depth + 1),
      ];
    case 'string':
      return _text(element);
    case 'integer':
      return _integer(_text(element).trim());
    case 'real':
      return _real(_text(element).trim());
    case 'true':
    case 'false':
      if (_text(element).trim().isNotEmpty) {
        throw const FormatException('Invalid plist boolean.');
      }
      return element.name.qualified == 'true';
    default:
      throw const FormatException('Unsupported plist preference type.');
  }
}

/// A bounded wire reader, not a general Java deserializer. Flutter's legacy
/// StandardMessageCodec supplies java.util.ArrayList to ObjectOutputStream.
class _JavaStringList {
  _JavaStringList(this.bytes);
  final Uint8List bytes;
  int position = 0;

  int _uint(int count) {
    if (count < 0 || position + count > bytes.length) {
      throw const FormatException('Truncated Java preference list.');
    }
    var value = 0;
    for (var i = 0; i < count; i++) {
      value = value * 256 + bytes[position++];
    }
    return value;
  }

  void _expect(List<int> expected) {
    for (final byte in expected) {
      if (_uint(1) != byte) {
        throw const FormatException(
          'Unsupported Java preference list encoding.',
        );
      }
    }
  }

  String _modifiedUtf8(int length) {
    if (length < 0 || position + length > bytes.length) {
      throw const FormatException('Truncated Java string.');
    }
    final end = position + length;
    final units = <int>[];
    while (position < end) {
      final first = _uint(1);
      if (first >= 1 && first <= 0x7f) {
        units.add(first);
      } else if (first >= 0xc0 && first <= 0xef) {
        final count = first < 0xe0 ? 2 : 3;
        if (position + count - 1 > end) {
          throw const FormatException('Truncated modified UTF-8.');
        }
        var unit = first & (count == 2 ? 0x1f : 0x0f);
        for (var i = 1; i < count; i++) {
          final continuation = _uint(1);
          if (continuation & 0xc0 != 0x80) {
            throw const FormatException('Invalid modified UTF-8.');
          }
          unit = (unit << 6) | (continuation & 0x3f);
        }
        if ((count == 2 && unit < 0x80 && unit != 0) ||
            (count == 3 && unit < 0x800)) {
          throw const FormatException('Overlong modified UTF-8.');
        }
        units.add(unit);
      } else {
        throw const FormatException('Invalid modified UTF-8.');
      }
    }
    // Modified UTF-8 encodes UTF-16 code units, including surrogate pairs.
    final encoded = Uint8List(units.length * 2);
    final view = ByteData.sublistView(encoded);
    for (var i = 0; i < units.length; i++) {
      view.setUint16(i * 2, units[i]);
    }
    return _utf16(encoded, Endian.big);
  }

  List<String> decode() {
    // STREAM_MAGIC, STREAM_VERSION, TC_OBJECT, TC_CLASSDESC, ArrayList name,
    // serialVersionUID, SC_SERIALIZABLE|SC_WRITE_METHOD, one int field "size",
    // TC_ENDBLOCKDATA, TC_NULL (no serializable superclass).
    _expect([
      0xac,
      0xed,
      0,
      5,
      0x73,
      0x72,
      0,
      19,
      ...ascii.encode('java.util.ArrayList'),
      0x78,
      0x81,
      0xd2,
      0x1d,
      0x99,
      0xc7,
      0x61,
      0x9d,
      3,
      0,
      1,
      0x49,
      0,
      4,
      ...ascii.encode('size'),
      0x78,
      0x70,
    ]);
    final size = _uint(4);
    if (size > 100000 || size > bytes.length) {
      throw const FormatException('Invalid Java list length.');
    }
    _expect([0x77, 4]); // TC_BLOCKDATA containing ArrayList's second size.
    if (_uint(4) != size) {
      throw const FormatException('Conflicting Java list sizes.');
    }
    final values = <String>[];
    final handles = <int, String>{};
    var nextHandle = 0x7e0002; // Class descriptor and list already own handles.
    for (var i = 0; i < size; i++) {
      final token = _uint(1);
      if (token == 0x71) {
        final string = handles[_uint(4)];
        if (string == null) {
          throw const FormatException('Invalid Java string reference.');
        }
        values.add(string);
      } else if (token == 0x74 || token == 0x7c) {
        // TC_LONGSTRING's unsigned 64-bit length must fit the copied buffer.
        if (token == 0x7c && _uint(4) != 0) {
          throw const FormatException('Oversized Java string.');
        }
        final string = _modifiedUtf8(_uint(token == 0x74 ? 2 : 4));
        handles[nextHandle++] = string;
        values.add(string);
      } else {
        throw const FormatException(
          'Unsupported Java preference-list element.',
        );
      }
    }
    _expect([0x78]);
    if (position != bytes.length) {
      throw const FormatException('Trailing Java preference-list bytes.');
    }
    return values;
  }
}

class _BinaryPlist {
  _BinaryPlist(this.bytes);
  final Uint8List bytes;
  late int referenceSize;
  late List<int> offsets;
  late List<int> limits;
  final Map<int, dynamic> cache = {};
  final Set<int> active = {};
  var expandedValues = 0;

  BigInt _bigUnsigned(int start, int length, int limit) {
    if (start < 0 || length < 0 || start + length > limit) {
      throw const FormatException('Truncated binary plist.');
    }
    var value = BigInt.zero;
    for (var i = start; i < start + length; i++) {
      value = (value << 8) | BigInt.from(bytes[i]);
    }
    return value;
  }

  int _boundedUnsigned(int start, int length, int limit, int maximum) {
    final value = _bigUnsigned(start, length, limit);
    if (value > BigInt.from(maximum)) {
      throw const FormatException('Invalid binary plist offset or count.');
    }
    return value.toInt();
  }

  Map<String, dynamic> decode() {
    if (bytes.length < 40 || ascii.decode(bytes.sublist(0, 8)) != 'bplist00') {
      throw const FormatException(
        'Unsupported or truncated binary plist header.',
      );
    }
    final trailer = bytes.length - 32;
    if (bytes.sublist(trailer, trailer + 6).any((byte) => byte != 0)) {
      throw const FormatException('Invalid binary plist trailer.');
    }
    final offsetSize = bytes[trailer + 6];
    referenceSize = bytes[trailer + 7];
    if (![1, 2, 4, 8].contains(offsetSize) ||
        ![1, 2, 4, 8].contains(referenceSize)) {
      throw const FormatException('Invalid binary plist integer widths.');
    }
    final count = _boundedUnsigned(trailer + 8, 8, bytes.length, 100000);
    if (count == 0) {
      throw const FormatException('Empty binary plist object table.');
    }
    final root = _boundedUnsigned(trailer + 16, 8, bytes.length, count - 1);
    final table = _boundedUnsigned(trailer + 24, 8, bytes.length, trailer);
    if (table < 8 || table + count * offsetSize != trailer) {
      throw const FormatException('Invalid binary plist offset table.');
    }
    offsets = [
      for (var i = 0; i < count; i++)
        _boundedUnsigned(
          table + i * offsetSize,
          offsetSize,
          trailer,
          table - 1,
        ),
    ];
    final ordered = offsets.toSet().toList()..sort();
    if (ordered.length != count || ordered.first != 8) {
      throw const FormatException('Duplicate or invalid binary plist offsets.');
    }
    final ends = {
      for (var i = 0; i < count; i++)
        ordered[i]: i + 1 < count ? ordered[i + 1] : table,
    };
    limits = [for (final offset in offsets) ends[offset]!];
    final value = _object(root, 0);
    if (value is! Map<String, dynamic>) {
      throw const FormatException(
        'Binary preference plist must be a dictionary.',
      );
    }
    // Validate even unreachable objects; unsupported/corrupt bytes are not lost.
    for (var i = 0; i < count; i++) {
      _object(i, 0);
    }
    return value;
  }

  dynamic _object(int index, int depth) {
    if (depth > 128 || ++expandedValues > 1000000) {
      throw const FormatException(
        'Excessive binary plist nesting or references.',
      );
    }
    if (active.contains(index)) {
      throw const FormatException('Cyclic binary plist.');
    }
    if (cache.containsKey(index)) return cache[index];
    active.add(index);
    var cursor = offsets[index];
    final end = limits[index];
    final marker = bytes[cursor++];
    final kind = marker >> 4;
    var length = marker & 15;
    if (kind == 5 || kind == 6 || kind == 0xa || kind == 0xd) {
      if (length == 15) {
        if (cursor == end) {
          throw const FormatException('Missing binary plist length.');
        }
        final lengthMarker = bytes[cursor++];
        if (lengthMarker >> 4 != 1 || (lengthMarker & 15) > 3) {
          throw const FormatException('Invalid binary plist length integer.');
        }
        final width = 1 << (lengthMarker & 15);
        length = _boundedUnsigned(cursor, width, end, bytes.length);
        cursor += width;
      }
    }
    dynamic value;
    switch (kind) {
      case 0:
        if (marker != 8 && marker != 9) {
          throw const FormatException('Unsupported binary plist simple value.');
        }
        value = marker == 9;
      case 1:
        if (length > 3) {
          throw const FormatException(
            'Unsupported binary plist integer width.',
          );
        }
        final width = 1 << length;
        var integer = _bigUnsigned(cursor, width, end);
        if (width == 8 && integer >= (BigInt.one << 63)) {
          integer -= BigInt.one << 64;
        }
        value = _representableInteger(integer);
        cursor += width;
      case 2:
        if (length != 2 && length != 3) {
          throw const FormatException('Unsupported binary plist real width.');
        }
        final width = 1 << length;
        if (cursor + width > end) {
          throw const FormatException('Truncated binary plist real.');
        }
        final view = ByteData.sublistView(bytes);
        final real = width == 4
            ? view.getFloat32(cursor)
            : view.getFloat64(cursor);
        if (!real.isFinite) {
          throw const FormatException('Non-finite binary plist real.');
        }
        value = real;
        cursor += width;
      case 5:
      case 6:
        final width = kind == 6 ? length * 2 : length;
        if (cursor + width > end) {
          throw const FormatException('Truncated binary plist string.');
        }
        final slice = Uint8List.sublistView(bytes, cursor, cursor + width);
        value = kind == 5 ? ascii.decode(slice) : _utf16(slice, Endian.big);
        cursor += width;
      case 0xa:
      case 0xd:
        final references = length * (kind == 0xd ? 2 : 1);
        if (length > 100000 || cursor + references * referenceSize > end) {
          throw const FormatException(
            'Truncated or excessive binary plist collection.',
          );
        }
        final ids = [
          for (var i = 0; i < references; i++)
            _boundedUnsigned(
              cursor + i * referenceSize,
              referenceSize,
              end,
              offsets.length - 1,
            ),
        ];
        cursor += references * referenceSize;
        if (kind == 0xa) {
          value = [for (final id in ids) _object(id, depth + 1)];
        } else {
          final values = <String, dynamic>{};
          for (var i = 0; i < length; i++) {
            final key = _object(ids[i], depth + 1);
            if (key is! String) {
              throw const FormatException(
                'Non-string binary plist dictionary key.',
              );
            }
            _insert(values, key, _object(ids[length + i], depth + 1));
          }
          value = values;
        }
      default:
        throw const FormatException(
          'Unsupported binary plist preference type.',
        );
    }
    // Apple's fill marker may pad objects. Other unaccounted-for bytes fail.
    if (cursor > end ||
        bytes.sublist(cursor, end).any((byte) => byte != 0x0f)) {
      throw const FormatException('Unexpected binary plist object bytes.');
    }
    active.remove(index);
    cache[index] = value;
    return value;
  }
}
