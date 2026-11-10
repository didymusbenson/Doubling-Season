/// Catalog data compatibility is independent of Table's display/store version.
///
/// Existing manifests without these optional fields are the legacy v1 list
/// format. The legacy app floor remains a conservative bridge for the shared
/// endpoint; it is never replaced by Table's unrelated 0.x product version.
abstract final class CatalogCompatibility {
  static const readerVersion = 1;
  static const schemaVersion = 1;
  static const legacyAppCompatibility = '1.11.0';
  static const maximumPayloadBytes = 16 * 1024 * 1024;

  static int positiveInteger(Object? value, String field) {
    if (value is! int || value <= 0) {
      throw FormatException('$field must be a positive integer');
    }
    return value;
  }

  static void validate({
    required int schema,
    required int minimumReader,
    String? legacyMinimum,
  }) {
    if (schema != schemaVersion ||
        minimumReader < 1 ||
        minimumReader > readerVersion) {
      throw const FormatException(
        'Catalog requires an unsupported data reader',
      );
    }
    if (legacyMinimum != null) {
      final required = _version(legacyMinimum);
      final supported = _version(legacyAppCompatibility);
      for (var i = 0; i < 3; i++) {
        if (required[i] < supported[i]) break;
        if (required[i] > supported[i]) {
          throw FormatException(
            'Catalog requires unverified legacy compatibility $legacyMinimum',
          );
        }
      }
    }
  }

  static List<int> _version(String value) {
    if (!RegExp(
      r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
    ).hasMatch(value)) {
      throw const FormatException('Malformed catalog minimum app version');
    }
    return value.split('.').map(int.parse).toList();
  }
}
