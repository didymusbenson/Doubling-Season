import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../migration/legacy_migration_recovery.dart';

/// Explicitly embedded rehearsal-only recovery UI. No startup route, storage
/// selection, source mutation, restore, or destructive escape hatch is wired.
class LegacyMigrationRecoveryView extends StatefulWidget {
  final LegacyRecoveryController controller;
  final Future<bool> Function(LegacyRecoveryBackup backup) onSaveBackup;

  const LegacyMigrationRecoveryView({
    super.key,
    required this.controller,
    required this.onSaveBackup,
  });

  @override
  State<LegacyMigrationRecoveryView> createState() =>
      _LegacyMigrationRecoveryViewState();
}

class _LegacyMigrationRecoveryViewState
    extends State<LegacyMigrationRecoveryView> {
  String? _copyMessage;
  bool _copying = false;

  Future<void> _copyDiagnostics(String diagnostics) async {
    if (_copying) return;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: diagnostics));
      if (mounted) setState(() => _copyMessage = 'Diagnostics copied.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _copyMessage = 'Could not copy. Select the details below.',
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final report = controller.report;
      final busy = controller.busy;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    report?.title ?? 'Check migration recovery',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Keep the original app and data. Do not uninstall, clear '
                    'storage, or reset the board to get past this screen.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report?.description ??
                        'Check the copied migration records to see which '
                            'recovery steps are safe.',
                  ),
                  if (report != null) ...[
                    for (final issue in report.issues) ...[
                      const SizedBox(height: 16),
                      Text(
                        issue.message,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(issue.nextStep),
                    ],
                    if (report.warnings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Warnings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final warning in report.warnings) Text(warning),
                    ],
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : controller.inspect,
                        icon: const Icon(Icons.search),
                        label: const Text('Check again'),
                      ),
                      if (report?.canRetry == true)
                        FilledButton.icon(
                          onPressed: busy ? null : controller.retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry safely'),
                        ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => controller.saveBackup(widget.onSaveBackup),
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save recovery copy'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The copy includes private migration records and any '
                    'artwork stored with them. Save it in a private location. '
                    'No copy is sent automatically.',
                  ),
                  if (busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Checking or saving recovery records…'),
                  ],
                  if (controller.actionMessage != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(controller.actionMessage!),
                    ),
                  ],
                  if (report != null) ...[
                    const SizedBox(height: 20),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Technical details'),
                      children: [
                        SelectableText(report.diagnostics),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: busy || _copying
                              ? null
                              : () => _copyDiagnostics(report.diagnostics),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy diagnostics'),
                        ),
                        if (_copyMessage != null) Text(_copyMessage!),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
