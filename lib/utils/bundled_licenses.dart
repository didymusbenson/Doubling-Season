import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers notices for assets that are bundled directly instead of arriving
/// through a Dart package.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/Mana-OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Mana icon font'], license);
  });
}
