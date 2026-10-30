/// Parse user-entered whole numbers without coercing malformed or overflowing
/// input. Bounds also keep accepted numbers exact in native and web builds.
int? tryWholeNumber(
  String text, {
  int min = -1000000000,
  int max = 1000000000,
}) {
  final trimmed = text.trim();
  if (!RegExp(r'^-?[0-9]+$').hasMatch(trimmed)) return null;
  final value = int.tryParse(trimmed);
  return value == null || value < min || value > max ? null : value;
}

/// Internal control flow: the UI restores the clean value before displaying
/// this message. No invalid number reaches a command or a persistence boundary.
class NumericInputException implements Exception {
  const NumericInputException(this.message);
  final String message;
}

/// Show intentional validation/save guidance, never an exception type, stack,
/// filesystem path, malformed source payload, or implementation diagnostic.
String inputErrorMessage(
  Object error, {
  String fallback = 'Your change could not be saved. Please try again.',
}) {
  if (error is NumericInputException) return error.message;
  if (error is FormatException) return error.message;
  if (error is StateError) return error.message;
  if (error is ArgumentError && error.message is String) {
    return error.message as String;
  }
  return fallback;
}
