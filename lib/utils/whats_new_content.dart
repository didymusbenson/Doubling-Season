import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

const Map<String, String> whatsNewContent = {
  '1.10.0': '• New Rules Calculator (the button next to +) for all '
      'token-multiplying effects — stack Doubling Season, Ojer Taq, '
      'Academy Manufactor, Chatterfang, and more\n'
      '• Hare Apparent utility\n'
      '• Tip jar with three support tiers (Collector tier includes a '
      'customizable heart badge)\n'
      '• Token database can update between app releases — About → Token '
      'Database → "Check for Updates" pulls new tokens on your tap\n'
      '• Confirm dialogs now show the full token breakdown\n'
      '• Companion artwork loads immediately\n'
      '• Red warning when token math is about to hit the 999,999 ceiling',
};

bool hasWhatsNewContent(String version) =>
    whatsNewContent.containsKey(version);

Future<void> showWhatsNewDialog(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final version = packageInfo.version;
  if (!context.mounted) return;

  final body = whatsNewContent[version];
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New in this version'),
      content: SingleChildScrollView(
        child: Text(
          body == null
              ? 'No release notes for version $version.'
              : 'Version $version highlights:\n\n$body',
          style: const TextStyle(height: 1.4),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
