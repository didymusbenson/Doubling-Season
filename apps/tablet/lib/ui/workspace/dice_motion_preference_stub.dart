// Native preferences arrive through MediaQuery.disableAnimations instead.
bool platformPrefersReducedDiceMotion() => false;

void Function() listenToPlatformReducedDiceMotion(
  void Function(bool) onChanged,
) => () {};
