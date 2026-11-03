// Native preferences arrive through MediaQuery.disableAnimations and the
// engine's separate AccessibilityFeatures.reduceMotion flag for iOS.
bool platformPrefersReducedDiceMotion() => false;

void Function() listenToPlatformReducedDiceMotion(
  void Function(bool) onChanged,
) => () {};
