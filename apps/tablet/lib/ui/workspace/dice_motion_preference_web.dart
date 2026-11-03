import 'dart:js_interop';

// Flutter 3.41 web maps high contrast, but not prefers-reduced-motion, into
// MediaQuery. Keep this compatibility bridge local to dice presentation.
@JS('window.matchMedia')
external _MotionQuery _matchMedia(String query);

extension type _MotionQuery(JSObject _) implements JSObject {
  external bool get matches;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

const _query = '(prefers-reduced-motion: reduce)';

bool platformPrefersReducedDiceMotion() => _matchMedia(_query).matches;

void Function() listenToPlatformReducedDiceMotion(
  void Function(bool) onChanged,
) {
  final query = _matchMedia(_query);
  final listener = ((JSAny? _) => onChanged(query.matches)).toJS;
  query.addEventListener('change', listener);
  return () => query.removeEventListener('change', listener);
}
